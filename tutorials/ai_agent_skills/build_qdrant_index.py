"""
TimeMolecules AI Agent Demo / Index Builder
Part of tutorials/ai_agent_skills

- build_qdrant_index.py   → creates/updates the Qdrant collection from TimeSolution metadata + llm_prompts
- time_molecules_agent_demo.py → Tkinter GUI for semantic search + LLM-grounded answers

Run build_qdrant_index.py first, then the demo.
Uses .env + local Qdrant folder.


When reading from sql, it will save the dataframe into a csv file in the data folder. 
This is to have a stable snapshot of the metadata that can be easily reloaded without hitting the database, 
and also to have a human-readable version of the metadata for debugging and exploration. 
The csv file will be overwritten each time you run the script with source="sql", so it always reflects 
the latest data from the database at the time of running.
"""
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

import json
import sys

import hashlib
import os
import pyodbc
import pandas as pd
import re
import requests  # ← add this import at the top of your file if not already present

from shared_llm import load_env_upward, read_llm_config, SharedLLM, clean_for_embedding

from pathlib import Path

load_env_upward(__file__)

# ----------------------------
# Config
# ----------------------------

LLM_CONFIG = read_llm_config()
SHARED_LLM = SharedLLM(LLM_CONFIG)

collection_name = LLM_CONFIG.collection_name
EMBED_LLM = LLM_CONFIG.embed_llm
EMBED_MODEL = LLM_CONFIG.embed_model
QDRANT_PATH = LLM_CONFIG.qdrant_path

SERVER = os.getenv("TIMESOLUTION_SERVER_NAME")
DATABASE = os.getenv("TIMESOLUTION_DATABASE_NAME")
CONN_DRIVER = os.getenv("TIMESOLUTION_CONNECTION_DRIVER", "ODBC Driver 18 for SQL Server")

CSV_METADATA_URL = (
    "https://raw.githubusercontent.com/MapRock/TimeMolecules/main/"
    "data/timesolution_schema/TimeMolecules_Metadata.csv"
)




def build_connection_string() -> str:

    return (
        f"DRIVER={{{CONN_DRIVER}}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        "Trusted_Connection=yes;"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
    )


def get_semantic_web_llm_values_df(
    source: str = "auto",
    csv_url: str = CSV_METADATA_URL,
) -> pd.DataFrame:
    """
    Load TimeSolution metadata either from SQL Server or from the published CSV.

    Args:
        source:
            "sql"  -> force SQL Server
            "csv"  -> force GitHub CSV
            "auto" -> try SQL first, then fall back to CSV
        csv_url:
            Raw GitHub URL for the metadata CSV

    Returns:
        pandas DataFrame with the expected metadata columns
    """
    expected_cols = [
        "ObjectType",
        "ObjectName",
        "Description",
        "Utilization",
        "ParametersJson",
        "OutputNotes",
        "ReferencedObjectsJson",
        "SampleCode"
    ]
    sql_columns = ", ".join(f"[{col}]" for col in expected_cols)

    def _load_from_sql() -> pd.DataFrame:
        conn_str = build_connection_string()
        sql = f"""
        EXEC dbo.BuildTimeSolutionsMetadata;
        SELECT
            {sql_columns}
        FROM [vwTimeSolutionsMetadata]
        WHERE ObjectName NOT IN ('dbo.sysdiagrams')  -- filter out irrelevant system table
        """
        try:
            with pyodbc.connect(conn_str, timeout=30) as conn:
                return pd.read_sql(sql, conn)
        except Exception as e:
            print(f"⚠️ SQL query failed: {e}")
            return pd.DataFrame()

    def _load_from_csv() -> pd.DataFrame:
        df = pd.read_csv(
            csv_url,
            header=None,
            names=expected_cols,
            encoding="utf-8",
        )

        # Keep only expected columns that actually exist
        available = [c for c in expected_cols if c in df.columns]
        if not available:
            raise ValueError(
                f"CSV at {csv_url} does not contain any expected columns. "
                f"Found: {list(df.columns)}"
            )

        df = df[available].copy()

        # Add any missing expected columns as nulls so downstream code stays stable
        for col in expected_cols:
            if col not in df.columns:
                df[col] = pd.NA

        return df[expected_cols]
    


    source = source.lower().strip()

    if source == "sql":
        df = _load_from_sql()
        df.to_csv(
            r"c:/maprock/timemolecules/data/TimeMolecules_Metadata.csv",
            index=False,
            encoding="utf-8",
            na_rep=""
        )
    elif source == "csv":
        df = _load_from_csv()
    elif source == "auto":
        try:
            df = _load_from_sql()
            print(f"✅ Loaded {len(df)} rows from SQL Server.")
        except Exception as e:
            print(f"⚠️ SQL load failed, falling back to CSV: {e}")
            df = _load_from_csv()
            print(f"✅ Loaded {len(df)} rows from GitHub CSV.")
    else:
        raise ValueError("source must be one of: 'sql', 'csv', 'auto'")

    return df


def embed_text(text: str) -> list[float]:
    return SHARED_LLM.embed_text(text)




def make_stable_int_id(object_name: str, object_type: str) -> int:
    """
    Build a stable positive integer ID from ObjectName + Type.
    Uses first 8 bytes of SHA256 so the same object gets the same ID every run.
    """
    key = f"{object_type}|{object_name}"
    digest = hashlib.sha256(key.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], byteorder="big", signed=False)


def is_nullish(value) -> bool:
    """
    True for None, NaN, pandas NA, etc.
    """
    try:
        return pd.isna(value)
    except Exception:
        return value is None


def row_to_payload(row: pd.Series, cols: list[str]) -> dict:
    """
    Keep only non-null columns in the payload.
    """
    payload = {}
    for col, value in row.items():
        if col in cols and not is_nullish(value):
            if hasattr(value, "item"):
                try:
                    value = value.item()
                except Exception:
                    pass
            payload[col] = value
    return payload

def normalize_text(value) -> str:
    if is_nullish(value):
        return ""
    return str(value).strip()

def object_type_desc(object_type: str) -> str:
    """
    Map ObjectType to a more descriptive phrase for the LLM.
    """
    mapping = {
        "Column": "database column",
        "Table": "database table",
        "VIEW": "database view",
        "SQL_SCALAR_FUNCTION": "scalar function",
        "SQL_STORED_PROCEDURE": "stored procedure",
        "SQL_TABLE_VALUED_FUNCTION": "table-valued function",
        "SQL_INLINE_TABLE_VALUED_FUNCTION": "inline table-valued function",
        "Instance": "Row of a lookup table"
    }
    return mapping.get(object_type, f"{object_type}")

def build_weighted_text(
    object_name: str,
    description: str,
    utilization: str
) -> str:
    """
    Build embedding text with Utilization weighted more than Description.
    Fallback to Description when Utilization is missing.
    """

    def _clean_for_embedding(text: str) -> str:
        """
        Clean text before sending to an embedding model.
        Removes brackets and noisy punctuation while preserving meaning.
        Expands SQL/CamelCase identifiers for better embeddings.
        """
        if not text:
            return ""

        text = str(text)

        # 1. Replace common problematic characters with space
        text = text.replace("[", "").replace("]", "")
        text = text.replace("{", "").replace("}", "")
        text = text.replace("(", "").replace(")", "")

        # 2. Replace SQL/schema separators and identifier separators
        text = text.replace("dbo.", "")
        text = re.sub(r"[_\-]+", " ", text)

        # 3. Split camelCase / PascalCase:
        # EventPropertiesParsed -> Event Properties Parsed
        text = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", text)

        # 4. Split acronym followed by word:
        # JSONPropertyValue -> JSON Property Value
        text = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", text)

        # 5. Normalize whitespace
        text = re.sub(r"\s+", " ", text).strip()

        return text
    
    object_name = clean_for_embedding(normalize_text(object_name))
    description = clean_for_embedding(normalize_text(description))
    utilization = clean_for_embedding(normalize_text(utilization))
        # Primary semantic text
    primary_text = utilization if utilization else description

    # IMPORTANT note on weighting: If both exist, weight utilization more heavily by placing it first
    # and repeating it once. Keep description for broader context.
    parts = [
        f"Primary Purpose: {primary_text}",
        f"Object Name: {object_name}",
    ]

    if utilization:
        parts.append(f"Usage: {utilization}")
    if description and utilization and description != utilization:
        parts.append(f"Description: {description}")

    return "\n".join(part for part in parts if part)

def build_qdrant_points(df: pd.DataFrame) -> list[PointStruct]:
    """
    Convert dataframe rows into Qdrant PointStruct objects.

    For each object row, create:
      1. the main object point
      2. an additional point for ParametersJson, if present
      3. an additional point for OutputNotes, if present
    """

    df_cols = [
        "ObjectType",
        "ObjectName",
        "Description",
        "Utilization",
        "ParametersJson",
        "OutputNotes",
        "ReferencedObjectsJson",
        "SampleCode",
    ]


    
    required = {"ObjectName", "ObjectType", "Utilization"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Missing required columns: {sorted(missing)}")

    points = []

    for _, row in df.iterrows():

        object_name = row["ObjectName"]
        object_type = row["ObjectType"]
        description = row["Description"]
        utilization = row["Utilization"]

      
        if is_nullish(object_name) or is_nullish(object_type):
            continue

        # ----------------------------
        # 1. Main object point
        # ----------------------------
        vector_text = build_weighted_text(
            object_name=object_name,
            description=description,
            utilization=utilization
        )




        vector = embed_text(vector_text)

        # Be sure there aren't duplicate keys. ObjectName, ObjectType.
        point_id = make_stable_int_id(str(object_name), str(object_type))
        payload = row_to_payload(
            row,
            cols=df_cols
        )

        points.append(
            PointStruct(
                id=point_id,
                vector=vector,
                payload=payload,
            )
        )

        print(f"{len(points)} Embedding text for '{object_name}':\n{vector_text}\n")

     


    return points


def ingest_llm_prompts_from_github(client, collection_name: str, github_tree_url: str = "https://github.com/MapRock/TimeMolecules/tree/main/docs/llm_prompts"):
    """
    Fetches EVERY file (except README.md) directly from the GitHub directory using the public GitHub API,
    downloads the raw content of each file, and adds it to your existing Qdrant collection.
    
    The ENTIRE document content is used as:
      - the embeddable text (for vector search)
      - the Description field in the payload
    
    Uses the exact same embedding path (ollama/openai), stable ID logic, and PointStruct format as the rest of your script.
    No local files or git clone required.
    """
 
    # Parse the GitHub tree URL (works with any public repo + branch + folder)
    parts = github_tree_url.rstrip('/').split('/')
    owner = parts[3]
    repo = parts[4]
    branch = parts[6]
    dir_path = '/'.join(parts[7:]) if len(parts) > 7 else ''

    # GitHub Contents API → list all files in the folder
    api_url = f"https://api.github.com/repos/{owner}/{repo}/contents/{dir_path}?ref={branch}"
    
    try:
        response = requests.get(api_url, timeout=15)
        response.raise_for_status()
        items = response.json()
    except Exception as e:
        print(f"❌ Failed to fetch GitHub directory {github_tree_url}: {e}")
        return

    if not isinstance(items, list):
        print("❌ Unexpected response from GitHub API (maybe rate-limited or private repo)")
        return

    points: list[PointStruct] = []

    for item in items:
        if item.get('type') != 'file' or item['name'].lower() == 'readme.md':
            continue

        raw_url = item.get('download_url')
        if not raw_url:
            continue

        # Download the full raw file content
        try:
            content_resp = requests.get(raw_url, timeout=15)
            content_resp.raise_for_status()
            content = content_resp.text.strip()
        except Exception as e:
            print(f"❌ Failed to download {item['name']}: {e}")
            continue

        if len(content) < 30:  # skip empty/tiny files
            print(f"⚠️ Skipping {item['name']} (too short)")
            continue

        # Use the ENTIRE document as the embedding text (exactly as you asked)
        embed_text_value = f"LLM Prompt / Template File: {item['name']}\n\n{content}"

        # Generate embedding using whichever backend you selected (ollama or openai)
        vector = embed_text(embed_text_value)

        # Stable integer ID (same file always gets the same point ID)
        base_name = Path(item['name']).stem
        point_id = make_stable_int_id(base_name, "LLM_PROMPT")

        payload = {
            "ObjectType": "LLM_PROMPT",
            "ObjectName": item['name'],
            "Description": content,                    # full original document (as requested)
            "Utilization": f"LLM system prompt / template from {item['name']}",
            "SourceFile": item['name'],
            "SourceURL": raw_url,
            "GitHubPath": f"{dir_path}/{item['name']}",
        }

        points.append(
            PointStruct(
                id=point_id,
                vector=vector,
                payload=payload,
            )
        )
        print(f"✅ Prepared embedding for GitHub file: {item['name']} ({len(content):,} chars)")

    if points:
        client.upsert(collection_name=collection_name, points=points)
        print(f"✅ Successfully added {len(points)} LLM prompt documents from GitHub to Qdrant.")
    else:
        print("⚠️ No prompt files were found/ingested from the GitHub directory.")

def export_qdrant_to_static_json(client, collection_name: str, embed_model: str):
    """
    Export the full Qdrant collection to a static JSON file for the public demo.

    Output file name:
        ai_agent_skills_<embed_model>.json

    The embedding vector is written into payload["embedding"].
    """
    print("\n=== Qdrant → Static JSON Export ===\n")

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir
    while repo_root.parent != repo_root and not (repo_root / ".git").exists():
        repo_root = repo_root.parent

    output_dir = repo_root / "public_demo"

    safe_embed_model = embed_model.replace("/", "_").replace(":", "_").replace("-", "_")
    output_file = output_dir / f"ai_agent_skills_{safe_embed_model}.json"

    print(f"Qdrant collection : {collection_name}")
    print(f"Qdrant path       : {QDRANT_PATH}")
    print(f"Output directory  : {output_dir}")
    print(f"Output file       : {output_file}\n")

    output_dir.mkdir(parents=True, exist_ok=True)
    print("✅ Output directory ready\n")

    all_points = []
    next_offset = None
    batch_num = 1

    while True:
        points, next_offset = client.scroll(
            collection_name=collection_name,
            limit=200,
            offset=next_offset,
            with_payload=True,
            with_vectors=True,
        )

        print(f"✅ Batch {batch_num}: retrieved {len(points)} documents")
        all_points.extend(points)
        batch_num += 1

        if next_offset is None:
            break

    print(f"✅ Retrieved {len(all_points)} total documents")

    data = []
    for p in all_points:
        payload = dict(p.payload) if p.payload else {}

        if hasattr(p, "vector") and p.vector is not None:
            payload["embedding"] = (
                p.vector.tolist() if hasattr(p.vector, "tolist") else p.vector
            )

        data.append({
            "id": str(p.id),
            "payload": payload,
        })

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n🎉 SUCCESS! Exported {len(data)} documents")
    print(f"   → {output_file}")

if __name__ == "__main__":
    # Set parameters.
    force_refresh = True  # Will reset the qdrant-client database.

    metadata_source = "sql" # "sql" or "csv" or "auto"

    print(f"✅ Metadata source: {metadata_source}\n")
    print(f"✅ QDRANT_PATH: {QDRANT_PATH}")
    print(f"✅ Embed backend: {EMBED_LLM}")
    print(f"✅ Embed model: {EMBED_MODEL}")

    client = QdrantClient(path=QDRANT_PATH)
 

    try:
        if force_refresh and client.collection_exists(collection_name=collection_name):
            client.delete_collection(collection_name=collection_name)
            print(f"✅ Deleted existing collection: {collection_name}")

        if not client.collection_exists(collection_name=collection_name):
            print(f"✅ Creating collection: {collection_name}")
            df = get_semantic_web_llm_values_df(source=metadata_source)
            print(f"✅ Retrieved {len(df)} rows from metadata source: {metadata_source}")


            # Get items from the vwTimeSolutionsMetadata view, convert to Qdrant PointStructs, and insert into the collection.
            points = build_qdrant_points(df)
            if points:
                print(f"✅ Built {len(points)} points from dataframe.")
            else:
                raise ValueError("No points were built from the dataframe.")

            vector_size = len(points[0].vector)

            # Create the collection with the correct vector size and distance metric.
            client.create_collection(
                collection_name=collection_name,
                vectors_config=VectorParams(
                    size=vector_size,
                    distance=Distance.COSINE,
                ),
            )

            client.upsert(
                collection_name=collection_name,
                points=points,
            )

            print("✅ Inserted points from the Time Solution database.")

            # === INGEST LLM PROMPTS DIRECTLY FROM GITHUB ===
            github_url = "https://github.com/MapRock/TimeMolecules/tree/main/docs/llm_prompts"
            ingest_llm_prompts_from_github(client, collection_name, github_url)
            export_qdrant_to_static_json(client, collection_name, EMBED_MODEL)



    finally:
        client.close()