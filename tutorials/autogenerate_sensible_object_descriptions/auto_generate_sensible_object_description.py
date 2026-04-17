"""
time_solution_generate_descriptions_with_llm.py

Executes dbo.Generate_LLM_Description_Prompts, sends each eligible prompt to an LLM
(OpenAI or Ollama), parses JSON containing Description and optional IRI, then updates
the corresponding TimeSolution row.

Eligibility rules
-----------------
Only process rows where:
- CurrDesc is null or blank
- and either HashKey or Caption is present

Write-back rules
----------------
- If HashKey is present, use it as the unique key
- Otherwise use Caption against the table's CodeColumn discovered from vwTimeMoleculesMetadata
- Only update rows still missing Description at write time
- Update LastUpdate when the row is updated
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

import pandas as pd
import pyodbc
from dotenv import load_dotenv
import requests

import ollama
import openai


# ---------------------------------------------------------
# Load .env by searching upward
# ---------------------------------------------------------
current = Path(__file__).resolve()
env_path = None

for parent in [current.parent, *current.parents]:
    candidate = parent / ".env"
    if candidate.exists():
        env_path = candidate
        break

if env_path:
    load_dotenv(env_path)
    print(f"Loaded .env from: {env_path}")
else:
    print("WARNING: .env not found. Falling back to environment variables.")


# ---------------------------------------------------------
# Config
# ---------------------------------------------------------
LLM = os.getenv("LLM", "ollama").lower()

# Ollama
OLLAMA_HOST = os.getenv("OLLAMA_HOST", None)
OLLAMA_CHAT_MODEL = os.getenv("OLLAMA_CHAT_MODEL", "llama3.2")
OLLAMA_CTX = int(os.getenv("OLLAMA_CTX", "8192"))

# OpenAI
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
CHATGPT_MODEL = os.getenv("CHATGPT_MODEL", "gpt-4o-mini")
CHATGPT_MAX_RESPONSE_TOKENS = int(os.getenv("CHATGPT_MAX_RESPONSE_TOKENS", "400"))

# SQL Server
SERVER = os.getenv("TIMESOLUTION_SERVER_NAME")
DATABASE = os.getenv("TIMESOLUTION_DATABASE_NAME")
CONN_DRIVER = os.getenv("TIMESOLUTION_CONNECTION_DRIVER", "ODBC Driver 18 for SQL Server")

# Behavior
TARGET_TABLE = os.getenv("TARGET_TABLE", "").strip() or None
DRY_RUN = os.getenv("DRY_RUN", "1").strip() == "1"
MAX_ROWS = int(os.getenv("MAX_ROWS", "0"))   # 0 means all
SLEEP_SECONDS = float(os.getenv("SLEEP_SECONDS", "0.0"))
WRITE_IRI = os.getenv("WRITE_IRI", "1").strip() == "1"
OVERWRITE_EXISTING_IRI = os.getenv("OVERWRITE_EXISTING_IRI", "0").strip() == "1"


if LLM == "openai":
    if not OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY must be set when LLM=openai.")
    openai.api_key = OPENAI_API_KEY


# ---------------------------------------------------------
# Ollama client
# ---------------------------------------------------------
def get_ollama_client():
    if OLLAMA_HOST:
        return ollama.Client(host=OLLAMA_HOST)
    return ollama.Client()


OLLAMA_CLIENT = get_ollama_client()


# ---------------------------------------------------------
# SQL helpers
# ---------------------------------------------------------
def get_connection() -> pyodbc.Connection:
    if not SERVER or not DATABASE:
        raise RuntimeError("TIMESOLUTION_SERVER_NAME and TIMESOLUTION_DATABASE_NAME must be set.")

    conn_str = (
        f"DRIVER={{{CONN_DRIVER}}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        "Trusted_Connection=yes;"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str, timeout=30)


def table_has_column(conn: pyodbc.Connection, fully_qualified_table: str, column_name: str) -> bool:
    schema_name, table_name = fully_qualified_table.split(".")
    sql = """
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?
    """
    row = conn.cursor().execute(sql, schema_name, table_name, column_name).fetchone()
    return row is not None


# ---------------------------------------------------------
# Metadata resolution
# ---------------------------------------------------------
@dataclass(frozen=True)
class TableMetadata:
    table_name_sql: str       # ex dbo.EventSets
    code_column: Optional[str]


def parse_metadata_object_name(object_name: str) -> Optional[str]:
    """
    Converts [dbo].[EventSets] -> EventSets
    """
    if not object_name:
        return None

    m = re.match(r"^\[dbo\]\.\[(.+)\]$", object_name.strip(), flags=re.IGNORECASE)
    if m:
        return m.group(1)

    # fallback if already plain
    return object_name.strip().replace("[", "").replace("]", "").split(".")[-1]


def load_table_metadata(conn: pyodbc.Connection) -> dict[str, TableMetadata]:
    """
    Reads table metadata from vwTimeMoleculesMetadata for ObjectType='Table'
    and returns a lookup keyed by simple table name, ex 'EventSets'.
    """
    sql = """
    SELECT
        ObjectName,
        CodeColumn
    FROM dbo.vwTimeMoleculesMetadata
    WHERE ObjectType = 'Table'
    """

    df = pd.read_sql(sql, conn)
    lookup: dict[str, TableMetadata] = {}

    for _, row in df.iterrows():
        raw_name = str(row["ObjectName"])
        simple_name = parse_metadata_object_name(raw_name)
        if not simple_name:
            continue

        lookup[simple_name] = TableMetadata(
            table_name_sql=f"dbo.{simple_name}",
            code_column=None if pd.isna(row["CodeColumn"]) else str(row["CodeColumn"]).strip() or None
        )

    return lookup


# ---------------------------------------------------------
# LLM helpers
# ---------------------------------------------------------
def load_prompt(url: str, timeout: int = 15) -> str:
    try:
        resp = requests.get(url, timeout=timeout)
        resp.raise_for_status()
        text = resp.text.strip()
        if not text:
            raise RuntimeError(f"Prompt at {url} is empty.")
        return text
    except Exception as e:
        raise RuntimeError(f"Could not load prompt from {url}: {e}") from e



SYSTEM_PROMPT_URL = (
    "https://raw.githubusercontent.com/MapRock/TimeMolecules/main/"
    "tutorials/autogenerate_sensible_object_descriptions/system_prompt.txt"
)
system_prompt = load_prompt(SYSTEM_PROMPT_URL)



def extract_json(text: str) -> dict[str, Any]:
    if not text:
        raise ValueError("Empty LLM response.")

    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*```$", "", cleaned)

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        pass

    match = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if not match:
        raise ValueError(f"Could not locate JSON object in response: {text[:500]}")
    return json.loads(match.group(0))


def ask_llm_json(user_prompt: str) -> dict[str, Any]:
    if LLM == "openai":
        response = openai.ChatCompletion.create(
            model=CHATGPT_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            max_tokens=CHATGPT_MAX_RESPONSE_TOKENS,
        )
        text = response["choices"][0]["message"]["content"].strip()
        return extract_json(text)

    if LLM == "ollama":
        response = OLLAMA_CLIENT.chat(
            model=OLLAMA_CHAT_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            options={"num_ctx": OLLAMA_CTX}
        )
        text = (response.get("message") or {}).get("content", "").strip()
        return extract_json(text)

    raise ValueError(f"Unsupported LLM: {LLM}")


def build_user_prompt(row: pd.Series) -> str:
    table_name = str(row["Table"])
    caption = None if pd.isna(row["Caption"]) else str(row["Caption"])
    base_prompt = str(row["Prompt"])

    instruction = """
Create a sensible metadata description for this TimeSolution object.

Use the provided prompt and context as the basis.
Return JSON only with:
- Description
- IRI
""".strip()

    extras = [
        f"Metadata Table: {table_name}",
        f"Caption: {caption or ''}",
        "The row currently has no description."
    ]

    return f"{instruction}\n\n" + "\n".join(extras) + f"\n\nPrompt to interpret:\n{base_prompt}"


# ---------------------------------------------------------
# Data fetch / filtering
# ---------------------------------------------------------
def fetch_prompt_rows(conn: pyodbc.Connection, table_filter: Optional[str]) -> pd.DataFrame:
    sql = "EXEC dbo.Generate_LLM_Description_Prompts"
    params: list[Any] = []

    if table_filter:
        sql += " @Table=?"
        params.append(table_filter)

    return pd.read_sql(sql, conn, params=params)


def filter_candidate_rows(df: pd.DataFrame) -> pd.DataFrame:
    """
    Keep only rows where:
    - CurrDesc is null or blank
    - and either HashKey or Caption is present
    """
    currdesc_missing = df["CurrDesc"].isna() | (df["CurrDesc"].astype(str).str.strip() == "")
    has_hashkey = df["HashKey"].notna()
    has_caption = df["Caption"].notna() & (df["Caption"].astype(str).str.strip() != "")

    return df[currdesc_missing & (has_hashkey | has_caption)].copy()


# ---------------------------------------------------------
# Write-back helpers
# ---------------------------------------------------------
def get_existing_iri(
    conn: pyodbc.Connection,
    table_name_sql: str,
    where_sql: str,
    where_params: list[Any],
) -> Optional[str]:
    if not table_has_column(conn, table_name_sql, "IRI"):
        return None

    sql = f"SELECT IRI FROM {table_name_sql} WHERE {where_sql}"
    row = conn.cursor().execute(sql, where_params).fetchone()
    if not row:
        return None
    return row[0]


def resolve_hash_column_name(conn: pyodbc.Connection, table_name_sql: str) -> Optional[str]:
    """
    Try to find the actual varbinary hash key column for the table.
    Common examples in TimeSolution are EventSetKey, TransformsKey.
    """
    schema_name, table_name = table_name_sql.split(".")

    sql = """
    SELECT COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = ?
      AND TABLE_NAME = ?
      AND DATA_TYPE IN ('varbinary', 'binary')
    ORDER BY
      CASE
        WHEN COLUMN_NAME = 'HashKey' THEN 0
        WHEN COLUMN_NAME LIKE '%HashKey%' THEN 1
        WHEN COLUMN_NAME LIKE '%Key' THEN 2
        ELSE 3
      END,
      COLUMN_NAME
    """

    rows = conn.cursor().execute(sql, schema_name, table_name).fetchall()
    if not rows:
        return None

    preferred = [r[0] for r in rows]
    return preferred[0]


def build_where_clause(
    conn: pyodbc.Connection,
    row: pd.Series,
    table_meta: TableMetadata,
) -> tuple[str, list[Any]]:
    """
    Prefer HashKey when present.
    Otherwise use Caption against the discovered CodeColumn.
    Also guard against writing over rows that now have Description populated.
    """
    description_guard = "([Description] IS NULL OR LTRIM(RTRIM([Description])) = '')"

    if pd.notna(row["HashKey"]):
        hash_column = resolve_hash_column_name(conn, table_meta.table_name_sql)
        if not hash_column:
            raise ValueError(f"HashKey present, but no varbinary key column could be resolved for {table_meta.table_name_sql}.")

        hash_value = row["HashKey"]
        if isinstance(hash_value, memoryview):
            hash_value = bytes(hash_value)
        elif isinstance(hash_value, bytearray):
            hash_value = bytes(hash_value)

        return f"[{hash_column}] = ? AND {description_guard}", [hash_value]

    caption = None if pd.isna(row["Caption"]) else str(row["Caption"]).strip()
    if caption and table_meta.code_column:
        return f"[{table_meta.code_column}] = ? AND {description_guard}", [caption]

    raise ValueError(
        f"Cannot build WHERE clause for table {table_meta.table_name_sql}. "
        f"Caption requires CodeColumn metadata, and HashKey was not present."
    )


def update_row(
    conn: pyodbc.Connection,
    row: pd.Series,
    table_meta: TableMetadata,
    new_description: str,
    new_iri: Optional[str],
) -> int:
    table_name_sql = table_meta.table_name_sql
    has_iri = table_has_column(conn, table_name_sql, "IRI")
    has_lastupdate = table_has_column(conn, table_name_sql, "LastUpdate")

    where_sql, where_params = build_where_clause(conn, row, table_meta)

    set_clauses = ["[Description] = ?"]
    params: list[Any] = [new_description]

    if WRITE_IRI and has_iri:
        current_iri = get_existing_iri(conn, table_name_sql, where_sql, where_params)
        should_write_iri = bool(new_iri) and (OVERWRITE_EXISTING_IRI or not current_iri)
        if should_write_iri:
            set_clauses.append("[IRI] = ?")
            params.append(new_iri)

    if has_lastupdate:
        set_clauses.append("[LastUpdate] = SYSUTCDATETIME()")

    sql = f"""
    UPDATE {table_name_sql}
    SET {", ".join(set_clauses)}
    WHERE {where_sql}
    """

    params.extend(where_params)
    cur = conn.cursor()
    cur.execute(sql, params)
    return cur.rowcount


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------
def main() -> int:
    print(f"LLM backend: {LLM}")
    print(f"Target table filter: {TARGET_TABLE or 'ALL'}")
    print(f"Dry run: {DRY_RUN}")
    print(f"Max rows: {MAX_ROWS if MAX_ROWS else 'ALL'}")
    print()

    with get_connection() as conn:
        table_lookup = load_table_metadata(conn)
        prompts_df = fetch_prompt_rows(conn, TARGET_TABLE)
        prompts_df = filter_candidate_rows(prompts_df)

        if prompts_df.empty:
            print("No eligible rows found.")
            return 0

        if MAX_ROWS > 0:
            prompts_df = prompts_df.head(MAX_ROWS)

        print(f"Rows to process: {len(prompts_df)}")
        print()

        updated = 0
        skipped = 0
        failed = 0

        for _, row in prompts_df.iterrows():
            table_name = str(row["Table"])
            caption = None if pd.isna(row["Caption"]) else str(row["Caption"]).strip()
            has_hash = pd.notna(row["HashKey"])

            print(f"--- Row {updated + skipped + failed + 1} ---")
            print(f"Table        : {table_name}")
            print(f"Caption      : {caption or ''}")
            print(f"Has HashKey  : {has_hash}")

            table_meta = table_lookup.get(table_name)
            if not table_meta:
                print(f"SKIP: Could not resolve table metadata for {table_name} from vwTimeMoleculesMetadata.")
                skipped += 1
                print()
                continue

            if not has_hash and not table_meta.code_column:
                print(f"SKIP: No HashKey and no CodeColumn found for {table_name}.")
                skipped += 1
                print()
                continue

            try:
                llm_prompt = build_user_prompt(row)
                result = ask_llm_json(llm_prompt)

                description = (result.get("Description") or "").strip()
                iri = result.get("IRI")

                if isinstance(iri, str):
                    iri = iri.strip() or None
                else:
                    iri = None

                if not description:
                    raise ValueError("LLM returned empty Description.")

                print(f"Description  : {description}")
                print(f"IRI          : {iri}")
                print(f"CodeColumn   : {table_meta.code_column}")

                if DRY_RUN:
                    print("DRY RUN: no database update executed.")
                    updated += 1
                else:
                    rowcount = update_row(conn, row, table_meta, description, iri)
                    conn.commit()

                    if rowcount == 0:
                        print("SKIP: No row updated. It may already have been filled by another process.")
                        skipped += 1
                    else:
                        print("Updated.")
                        updated += rowcount

            except Exception as e:
                failed += 1
                print(f"FAILED: {e}")

            print()
            if SLEEP_SECONDS > 0:
                time.sleep(SLEEP_SECONDS)

        print("Done.")
        print(f"Updated: {updated}")
        print(f"Skipped: {skipped}")
        print(f"Failed : {failed}")

    return 0


if __name__ == "__main__":
    sys.exit(main())