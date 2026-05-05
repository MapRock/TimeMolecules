"""
auto_generate_sensible_object_description.py

Purpose:
    Executes dbo.Generate_LLM_Description_Prompts, sends each eligible prompt to an LLM
    (via SharedLLM), parses the returned JSON (Description + optional IRI), and
    optionally updates the corresponding row in TimeSolution.

    Always outputs a CSV with all results to demo_output/ folder.

Usage:
    python auto_generate_sensible_object_description.py --max-rows 50 --dry-run
"""

import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import pandas as pd

# ================================================
# PATH FIX + FORCE TUTORIALS .env
# ================================================
# This script lives in tutorials/autogenerate_sensible_object_descriptions/
# so we need parents[2] to reach the repo root where shared/ lives
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from dotenv import load_dotenv

tutorials_env = Path(r"C:\MapRock\TimeMolecules\tutorials\.env")
if tutorials_env.exists():
    load_dotenv(tutorials_env, override=True)
    print(f"✅ FORCED .env FROM TUTORIALS: {tutorials_env}")
else:
    print(f"❌ Could not find tutorials/.env at {tutorials_env}")

# Import from shared/
from shared.shared_llm import read_llm_config, SharedLLM
from shared.time_solution import TimeSolutionDAL

# -------------------------------------------------
# Config
# -------------------------------------------------
LLM_CONFIG = read_llm_config()
SHARED_LLM = SharedLLM(LLM_CONFIG)

TARGET_TABLE = os.getenv("TARGET_TABLE", "").strip() or None
DRY_RUN = os.getenv("DRY_RUN", "1").strip() == "1"
SLEEP_SECONDS = float(os.getenv("SLEEP_SECONDS", "0.0"))


# -------------------------------------------------
# Helpers
# -------------------------------------------------
def load_prompt(url: str, timeout: int = 15) -> str:
    import requests
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
    response = SHARED_LLM.chat_once([
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ])
    return extract_json(response)


def build_user_prompt(row: pd.Series) -> str:
    table_name = str(row["Table"])
    caption = None if pd.isna(row.get("Caption")) else str(row.get("Caption"))
    base_prompt = str(row.get("Prompt", ""))

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


# -------------------------------------------------
# Main
# -------------------------------------------------
def main() -> int:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--max-rows", type=int, default=0,
                        help="Maximum number of rows to process (0 = all)")
    parser.add_argument("--dry-run", action="store_true", default=DRY_RUN,
                        help="Do not write to database")
    args = parser.parse_args()

    print(f"LLM backend: {LLM_CONFIG.embed_llm}")
    print(f"Target table filter: {TARGET_TABLE or 'ALL'}")
    print(f"Dry run: {args.dry_run}")
    print(f"Max rows: {args.max_rows if args.max_rows else 'ALL'}")
    print()

    dal = TimeSolutionDAL()

    # Fetch prompts
    sql = "EXEC dbo.Generate_LLM_Description_Prompts"
    params = (TARGET_TABLE,) if TARGET_TABLE else None
    rows = dal.execute_query(sql, params)                    # ← this returns list[dict]
    df = pd.DataFrame(rows)                                  # ← convert to DataFrame here

    print(f"✅ Retrieved {len(df)} rows from dbo.Generate_LLM_Description_Prompts")

    # Filter candidates
    currdesc_missing = df["CurrDesc"].isna() | (df["CurrDesc"].astype(str).str.strip() == "") # Important: Only rows where CurrDesc is missing or empty
    has_hashkey = df["HashKey"].notna()
    has_caption = df["Caption"].notna() & (df["Caption"].astype(str).str.strip() != "") # Important: Only rows where Caption is present and not empty



    df = df[currdesc_missing & (has_hashkey | has_caption)].copy()
    
    if args.max_rows > 0:
        df = df.head(args.max_rows)

    print(f"✅ Rows eligible for processing: {len(df)}")
    print()

    results = []
    updated = 0
    failed = 0

    for _, row in df.iterrows():
        print(f"--- Row {updated + failed + 1} ---")
        print(f"Table   : {row.get('Table')}")
        print(f"Caption : {row.get('Caption', '')}")
        print(f"Has Hash: {pd.notna(row.get('HashKey'))}")

        try:
            llm_prompt = build_user_prompt(row)
            result = ask_llm_json(llm_prompt)

            description = (result.get("Description") or "").strip()
            iri = result.get("IRI")
            if isinstance(iri, str):
                iri = iri.strip() or None

            if not description:
                raise ValueError("LLM returned empty Description.")

            print(f"Description : {description}")
            print(f"IRI         : {iri}")

            results.append({
                "Table": row.get("Table"),
                "Caption": row.get("Caption"),
                "HashKey": row.get("HashKey"),
                "Prompt": row.get("Prompt"),
                "CurrDesc": row.get("CurrDesc"),
                "Generated_Description": description,
                "Generated_IRI": iri,
                "Status": "DRY_RUN" if args.dry_run else "WOULD_UPDATE",
                "Timestamp": datetime.now().isoformat()
            })

            if args.dry_run:
                print("DRY RUN: No database update performed.")
                updated += 1
            else:
                print("Update code is commented out (dry-run mode).")
                updated += 1

        except Exception as e:
            failed += 1
            print(f"FAILED: {e}")
            results.append({
                "Table": row.get("Table"),
                "Caption": row.get("Caption"),
                "HashKey": row.get("HashKey"),
                "Prompt": row.get("Prompt"),
                "CurrDesc": row.get("CurrDesc"),
                "Generated_Description": None,
                "Generated_IRI": None,
                "Status": f"FAILED: {e}",
                "Timestamp": datetime.now().isoformat()
            })

        print()
        if SLEEP_SECONDS > 0:
            time.sleep(SLEEP_SECONDS)

    # ==================== CSV OUTPUT ====================
    output_dir = Path(os.getenv("DEFAULT_OUTPUT_DIR", "output")) 
    output_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_path = output_dir / f"generated_descriptions_{timestamp}.csv"

    if results:
        pd.DataFrame(results).to_csv(csv_path, index=False, encoding="utf-8")
        print(f"✅ CSV results saved → {csv_path}")
    else:
        print("No results to save.")

    print("\nDone.")
    print(f"Processed : {len(results)} rows")
    print(f"Updated   : {updated}")
    print(f"Failed    : {failed}")

    return 0


if __name__ == "__main__":
    sys.exit(main())