from dotenv import load_dotenv
import os
import pyodbc
import pandas as pd
import openai
import requests

load_dotenv()

# ----------------------------
# Config (exactly as in qdrant_demo.py)
# ----------------------------
MAX_TOKENS = int(os.getenv("CHATGPT_MAX_RESPONSE_TOKENS", "4000"))  # increased for CSV output
openai.api_key = os.getenv("OPENAI_API_KEY")
CHATGPT_MODEL = os.getenv("CHATGPT_MODEL")
SERVER = os.getenv("TIMESOLUTION_SERVER_NAME")
DATABASE = os.getenv("TIMESOLUTION_DATABASE_NAME")

template_url = "https://raw.githubusercontent.com/MapRock/TimeMolecules/main/tutorials/link_cases/llm_prompt_similarity_score_event_properties.txt"



def get_best_sql_server_driver() -> str:
    """
    Pick the newest installed Microsoft SQL Server ODBC driver if available.
    Falls back in a sensible order. (exact copy from qdrant_demo.py)
    """
    installed = [d for d in pyodbc.drivers() if "SQL Server" in d]

    preferred_order = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "SQL Server Native Client 11.0",
        "SQL Server",
    ]

    for driver in preferred_order:
        if driver in installed:
            return driver

    raise RuntimeError(
        "No suitable SQL Server ODBC driver found. "
        f"Installed drivers: {installed}"
    )


def build_connection_string() -> str:
    """
    Build connection string exactly as in qdrant_demo.py
    """
    driver = get_best_sql_server_driver()

    return (
        f"DRIVER={{{driver}}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        "Trusted_Connection=yes;"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
    )


def get_source_columns_df() -> pd.DataFrame:
    """
    Get source column metadata. "Sources" the databases where cases, events and properties of cases and events come from.
    """
    conn_str = build_connection_string()
    sql = "SELECT * FROM vwSourceColumnsFull"

    with pyodbc.connect(conn_str, timeout=30) as conn:
        df = pd.read_sql(sql, conn)

    return df


def build_column_text(row: pd.Series) -> str:
    """
    Create a concise, LLM-friendly description of each column.
    This keeps the prompt well under context limits while preserving all semantic signal.
    """
    parts = [
        f"ID: {row['SourceColumnID']}",
        f"ColumnName: {row.get('ColumnName', 'N/A')}",
    ]
    if pd.notna(row.get('TableName')) and str(row['TableName']).strip():
        parts.append(f"Table: {row['TableName']}")
    if pd.notna(row.get('ColumnDescription')) and str(row['ColumnDescription']).strip():
        parts.append(f"Description: {row['ColumnDescription']}")
    if pd.notna(row.get('DataType')) and str(row['DataType']).strip():
        parts.append(f"DataType: {row['DataType']}")
    if pd.notna(row.get('DatabaseName')) and str(row['DatabaseName']).strip():
        parts.append(f"Database: {row['DatabaseName']}")
    if pd.notna(row.get('SourceDescription')) and len(str(row['SourceDescription'])) > 10:
        # truncate long source descriptions but keep the first 300 chars
        parts.append(f"SourceContext: {str(row['SourceDescription'])[:300]}...")

    return " | ".join(parts)


if __name__ == "__main__":
    df = get_source_columns_df()
    print(f"✅ Loaded {len(df)} columns from vwSourceColumnsFull")

    # Build clean per-column summaries for the LLM
    column_texts = [build_column_text(row) for _, row in df.iterrows()]
    all_columns_str = "\n\n".join(column_texts)
    print(f"✅ Built LLM-friendly descriptions for all columns. Sample:\n{all_columns_str[:1000]}...\n")
    # Single, carefully crafted prompt that forces the LLM to do the cross-join analysis

  
    response = requests.get(template_url)
    response.raise_for_status()  # Will raise if download fails
    
    prompt_template = response.text
    
    # Insert the column descriptions into the placeholder
    prompt = prompt_template.replace("{all_columns_str}", all_columns_str)

    print("🚀 Sending prompt to LLM for full cross-join semantic analysis...")

    response = openai.ChatCompletion.create(
        model=CHATGPT_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.0,          # deterministic scoring
        max_tokens=MAX_TOKENS,
    )

    content = response.choices[0].message.content.strip()

    # Save the CSV
    output_file = r"C:\MapRock\TimeMolecules\similar_column_pairs.csv"

    if content.startswith("SourceColumnID1"):
        # Normalize line endings to pure Windows style (\r\n) — most reliable for SQL Server on Windows
        normalized_content = content.replace('\r\n', '\n').replace('\r', '\n').replace('\n', '\r\n')
        
        with open(output_file, "w", encoding="utf-8", newline='') as f:
            f.write(normalized_content)
        
        print(f"✅ Successfully wrote normalized CSV to:\n   {output_file}")
        print(f"   Total lines: {len(normalized_content.splitlines())}")
        
        print("\nPreview of first 10 lines:")
        print("\n".join(normalized_content.splitlines()[:11]))
        
    else:
        print("⚠️ LLM did not return clean CSV. Raw response preview:")
        print(content[:1500])
