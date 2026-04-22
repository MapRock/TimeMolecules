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
from matplotlib import text
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

from openai import OpenAI

import hashlib
import os
import pyodbc
import pandas as pd
import re
import requests  # ← add this import at the top of your file if not already present

import ollama

from dotenv import load_dotenv
from pathlib import Path

# ----------------------------
# Load .env (search upward)
# ----------------------------
current = Path(__file__).resolve()
env_path = None

for parent in [current.parent, *current.parents]:
    candidate = parent / ".env"
    if candidate.exists():
        env_path = candidate
        break

if env_path:
    load_dotenv(env_path)
    print(f"✅ Loaded .env from: {env_path}")
else:
    print("⚠️ .env not found. Falling back to system environment variables.")


# ----------------------------
# Config
# ----------------------------

OPENAI_CLIENT = None

collection_name = "time_molecules_directory"


SERVER = os.getenv("TIMESOLUTION_SERVER_NAME")
DATABASE = os.getenv("TIMESOLUTION_DATABASE_NAME")
CONN_DRIVER = os.getenv("TIMESOLUTION_CONNECTION_DRIVER", "ODBC Driver 18 for SQL Server")

CSV_METADATA_URL = (
    "https://raw.githubusercontent.com/MapRock/TimeMolecules/main/"
    "data/timesolution_schema/TimeMolecules_Metadata.csv"
)
QDRANT_PATH = os.getenv("QDRANT_PATH", "./qdrant_data")   # relative path, works on any OS


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


def get_ollama_client():
    """Simple client - no model passed here"""
    return ollama.Client()   # host defaults to http://localhost:11434


def embed_text_ollama(text: str) -> list[float]:
    """
    Generate embedding using a proper embedding model.
    Works with current Ollama Python library (2026).
    """
    client = get_ollama_client()
    
    response = client.embed(
        model=EMBED_MODEL,      # ← must be an embedding model (nomic-embed-text, mxbai-embed-large, etc.)
        input=text              # ← current API uses 'input', not 'prompt'
    )
    
    # Newer library returns {'embeddings': [[...]] } for single text
    embeddings = response.get("embeddings")
    if not embeddings or not embeddings[0]:
        raise ValueError(f"Ollama returned no embedding for model {EMBED_MODEL}")
    
    return embeddings[0]

def embed_text_openai(text: str) -> list[float]:
    if OPENAI_CLIENT is None:
        raise RuntimeError("OPENAI client is not initialized.")

    response = OPENAI_CLIENT.embeddings.create(
        model=EMBED_MODEL,
        input=text,
    )

    return response.data[0].embedding


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
    
    object_name = _clean_for_embedding(normalize_text(object_name))
    description = _clean_for_embedding(normalize_text(description))
    utilization = _clean_for_embedding(normalize_text(utilization))

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

    def _vectorize_text(text: str) -> list[float]:
        if llm == "ollama":
            return embed_text_ollama(text)
        elif llm == "openai":
            return embed_text_openai(text)
        else:
            raise ValueError(f"Unsupported LLM for embedding: {llm}")
    
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



        print(f"Embedding text for '{object_name}':\n{vector_text}\n")

        vector = _vectorize_text(vector_text)

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
        embed_text = f"LLM Prompt / Template File: {item['name']}\n\n{content}"

        # Generate embedding using whichever backend you selected (ollama or openai)
        if llm == "ollama":
            vector = embed_text_ollama(embed_text)
        elif llm == "openai":
            vector = embed_text_openai(embed_text)
        else:
            continue

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


if __name__ == "__main__":
    # Set parameters.
    force_refresh = True  # Will reset the qdrant-client database.
    llm = os.getenv("EMBED_LLM", "ollama").lower()
    metadata_source = "sql" # "sql" or "csv" or "auto"

 

    if llm == "openai":
        MAX_TOKENS = int(os.getenv("CHATGPT_MAX_RESPONSE_TOKENS", "220"))
        OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
        if not OPENAI_API_KEY:
            raise RuntimeError("OPENAI_API_KEY must be set in .env or environment variables.")

        OPENAI_CLIENT = OpenAI(api_key=OPENAI_API_KEY)

        EMBED_MODEL = os.getenv("CHATGPT_EMBEDDING_MODEL", "text-embedding-3-large")
        CHATGPT_MODEL = os.getenv("CHATGPT_MODEL", "gpt-4.1")
        client = QdrantClient(path=os.getenv("QDRANT_PATH", "./qdrant_data_openai"))
        print("✅ Using OpenAI for embeddings.")
    elif llm == "ollama":
        EMBED_MODEL = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
        OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", None)
        client = QdrantClient(path=os.getenv("QDRANT_PATH", "./qdrant_data_ollama"))
        print(f"✅ Using Ollama for embeddings. Model: {OLLAMA_MODEL}, Embed Model: {EMBED_MODEL}")    


    test_text = "parse case properties from json blobs and store as structured data"
    #test_text = "find matrix adjacency of a markov model"
    #test_text = "Given a sequence, what is the probability"
    #test_text = "Create a markov model from time series data across cases"
    results_limit = 5

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

    
        if llm == "ollama":
            query_vector = embed_text_ollama(test_text)
        elif llm == "openai":
            query_vector = embed_text_openai(test_text)

        results = client.query_points(
            collection_name=collection_name,
            query=query_vector,
            limit=results_limit,
            with_payload=True,
        ).points

        print("\nSearch results:")
        for hit in results:
            print(f"ID: {hit.id}")
            print(f"Score: {hit.score}")
            print(f"Payload: {hit.payload}")
            print("-" * 40)

    finally:
        client.close()