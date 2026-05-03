# time_solution.py
import pyodbc
import os
from contextlib import contextmanager
from pathlib import Path
from typing import List, Dict, Any

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



class TimeSolutionDAL:
    """Generic DAL for TimeSolution / TimeMolecules – just pass any SQL."""
    
    def __init__(self):
        self.server = os.getenv("TIMESOLUTION_SERVER_NAME")
        self.database = os.getenv("TIMESOLUTION_DATABASE_NAME")
        self.driver = os.getenv("TIMESOLUTION_CONNECTION_DRIVER", "ODBC Driver 18 for SQL Server")

        if not self.server or not self.database:
            raise RuntimeError("TIMESOLUTION_SERVER_NAME and TIMESOLUTION_DATABASE_NAME must be set in .env")

    @contextmanager
    def connection(self):
        conn_str = (
            f"DRIVER={{{self.driver}}};"
            f"SERVER={self.server};"
            f"DATABASE={self.database};"
            "Trusted_Connection=yes;"
            "Encrypt=yes;"
            "TrustServerCertificate=yes;"
        )
        conn = pyodbc.connect(conn_str, timeout=30)
        try:
            yield conn
        finally:
            conn.close()

    def execute_query(self, sql: str, params: tuple | None = None) -> List[Dict[str, Any]]:
        """Execute any SQL (including EXEC stored procs) and return list of dicts."""
        with self.connection() as conn:
            cursor = conn.cursor()
            if params:
                cursor.execute(sql, params)
            else:
                cursor.execute(sql)
            
            if cursor.description:  # SELECT or EXEC that returns rows
                columns = [col[0] for col in cursor.description]
                rows = cursor.fetchall()
                return [dict(zip(columns, row)) for row in rows]
            else:
                return []  # non-result statements (e.g. INSERT)