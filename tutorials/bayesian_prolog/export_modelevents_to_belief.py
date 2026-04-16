"""
Command: C:\Python310\python.exe export_modelevents_to_belief.py 1 -o model_123_beliefs.pl
"""
import os
import sys
import pyodbc
import argparse

from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file in current or parent directories.
current = Path(__file__).resolve()
env_path = None

for parent in [current.parent, *current.parents]:
    candidate = parent / ".env"
    if candidate.exists():
        env_path = candidate
        break

if env_path is None:
    raise FileNotFoundError(".env not found in this directory or any parent directory")

load_dotenv(env_path)
print(f"✅ Loaded .env from: {env_path}")


def get_best_sql_server_driver() -> str:
    """
    Pick the newest installed Microsoft SQL Server ODBC driver if available.
    Falls back in a sensible order.
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
    Build connection string using the same method as your attached script.
    """
    driver = get_best_sql_server_driver()
    server = os.getenv("TIMESOLUTION_SERVER_NAME")
    database = os.getenv("TIMESOLUTION_DATABASE_NAME")

    if not server:
        raise RuntimeError("TIMESOLUTION_SERVER_NAME is not set.")
    if not database:
        raise RuntimeError("TIMESOLUTION_DATABASE_NAME is not set.")

    return (
        f"DRIVER={{{driver}}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        "Trusted_Connection=yes;"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
    )


def prolog_atom(value) -> str:
    """
    Convert a SQL value into a safe Prolog atom.

    Rules:
    - NULL -> null
    - numbers stay unquoted
    - simple lowercase/underscore atoms stay bare
    - everything else gets single-quoted with escaping
    """
    if value is None:
        return "null"

    if isinstance(value, (int, float)):
        return str(value)

    text = str(value).strip()

    if text == "":
        return "''"

    # bare atom if already simple and Prolog-friendly
    if text.replace("_", "").replace("-", "").isalnum() and text[0].islower():
        return text

    # otherwise quote and escape single quotes
    escaped = text.replace("\\", "\\\\").replace("'", "\\'")
    return f"'{escaped}'"


def fetch_model_events(model_id: int):
    """
    Fetch ModelEvents for a given ModelID.
    """
    conn_str = build_connection_string()

    sql = """
    SELECT
        ModelID,
        EventA,
        EventB,
        Prob
    FROM dbo.ModelEvents
    WHERE ModelID = ?
    ORDER BY EventA, EventB
    """

    with pyodbc.connect(conn_str, timeout=30) as conn:
        cursor = conn.cursor()
        cursor.execute(sql, model_id)
        rows = cursor.fetchall()

    return rows


def format_as_belief(rows) -> list[str]:
    """
    Format each row as:
        belief(hypothesis(EventB), evidence([EventA]), Prob).
    """
    lines = []

    for row in rows:
        event_a = prolog_atom(row.EventA)
        event_b = prolog_atom(row.EventB)
        prob = "null" if row.Prob is None else f"{float(row.Prob):.6f}".rstrip("0").rstrip(".")

        lines.append(
            f"belief(hypothesis({event_b}), evidence([{event_a}]), {prob})."
        )

    return lines


def main():
    parser = argparse.ArgumentParser(
        description="Dump dbo.ModelEvents rows for a given ModelID as Prolog belief facts."
    )
    parser.add_argument("modelid", type=int, help="ModelID to export")
    parser.add_argument(
        "-o",
        "--output",
        help="Optional output file path. If omitted, prints to stdout."
    )
    args = parser.parse_args()

    try:
        rows = fetch_model_events(args.modelid)

        if not rows:
            print(f"% No rows found for ModelID = {args.modelid}")
            sys.exit(0)

        lines = [
            f"% Export from dbo.ModelEvents for ModelID = {args.modelid}",
            "% Format: belief(hypothesis(EventB), evidence([EventA]), Prob).",
            ""
        ]
        lines.extend(format_as_belief(rows))
        output_text = "\n".join(lines)

        if args.output:
            with open(args.output, "w", encoding="utf-8", newline="\n") as f:
                f.write(output_text)
            print(f"✅ Wrote {len(rows)} beliefs to {args.output}")
        else:
            print(output_text)

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()