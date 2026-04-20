"""
Pre-create stored Markov models from a model aggregation design.

Purpose
-------
This script reads a JSON "model aggregation design", expands the intended
parameter combinations, and calls dbo.CreateUpdateMarkovProcess once for
each combination.

Why this exists
---------------
This is the Time Molecules counterpart to OLAP pre-aggregations.

Instead of waiting for ad hoc requests to trigger expensive scans of
EventsFact, this script can pre-create persisted Markov models for
combinations that are expected to be used repeatedly or that would be
expensive to build at query time.

What it does
------------
1. Connects to the TimeSolution database with pyodbc.
2. Loads a JSON design file.
3. Expands all requested combinations.
4. Calls dbo.CreateUpdateMarkovProcess for each combination.
5. Writes a CSV run log with status, timing, and parameter values.

Notes
-----
- This script is intentionally orchestration-focused. SQL Server still
  performs the actual model creation.
- The script assumes the stored procedure signature matches the common
  10-parameter Time Molecules pattern.
- It also assumes the stored procedure return code is useful to log,
  possibly even the ModelID itself. If your procedure instead SELECTs the
  ModelID, adjust call_create_update_markov_process() accordingly.
- This script uses configuration variables in the file instead of
  command-line arguments, by design.

Typical use
-----------
1. Edit the connection settings below.
2. Edit DESIGN_FILE to point to your model aggregation design JSON.
3. Run the script.
4. Review the CSV log to see what was created.

Author intent
-------------
This script is meant to operationalize the idea that pre-created Markov
models preserve compute in the same spirit that OLAP cube aggregations did:
process once, read many times.
"""

import csv
import itertools
import json
import time
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import pyodbc


# ============================================================
# CONFIGURATION
# ============================================================

from dotenv import load_dotenv
from pathlib import Path
import os
import pyodbc

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
# Config from .env
# ----------------------------
SERVER = os.getenv("TIMESOLUTION_SERVER_NAME")
DATABASE = os.getenv("TIMESOLUTION_DATABASE_NAME")
CONN_DRIVER = os.getenv("TIMESOLUTION_CONNECTION_DRIVER", "ODBC Driver 18 for SQL Server")

# Script-specific settings
DESIGN_FILE = Path("model_aggregation_design.json")
RUN_LOG_CSV = Path("precreated_markov_models_runlog.csv")

DRY_RUN = False
STOP_ON_ERROR = False
PRINT_EACH_COMBINATION = True
RETURN_CODE_IS_MODEL_ID = True


def build_connection_string() -> str:
    return (
        f"DRIVER={{{CONN_DRIVER}}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        "Trusted_Connection=yes;"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
    )


def get_connection() -> pyodbc.Connection:
    if not SERVER:
        raise ValueError("TIMESOLUTION_SERVER_NAME is not set in .env or environment variables.")
    if not DATABASE:
        raise ValueError("TIMESOLUTION_DATABASE_NAME is not set in .env or environment variables.")
    return pyodbc.connect(build_connection_string())


# ============================================================
# SAMPLE DESIGN WRITER
# Creates a starter design if the JSON file does not yet exist.
# ============================================================

SAMPLE_DESIGN = {
    "DesignName": "Cardiology monthly by location",
    "Description": "Pre-create monthly cardiology models for two locations plus all locations.",
    "FixedParameters": {
        "EventSet": "cardiology",
        "enumerate_multiple_events": 0,
        "transforms": None,
        "ByCase": 1,
        "metric": None
    },
    "VariableParameters": {
        "DateWindows": [
            {"StartDateTime": "2025-01-01", "EndDateTime": "2025-02-01"},
            {"StartDateTime": "2025-02-01", "EndDateTime": "2025-03-01"},
            {"StartDateTime": "2025-03-01", "EndDateTime": "2025-04-01"}
        ],
        "CaseFilterProperties": [
            None,
            "{\"LocationID\":1}",
            "{\"LocationID\":2}"
        ],
        "EventFilterProperties": [
            None
        ],
        "transforms": [
            None
        ]
    }
}


# ============================================================
# HELPERS
# ============================================================

def write_sample_design_if_missing(design_file: Path) -> None:
    if not design_file.exists():
        design_file.write_text(json.dumps(SAMPLE_DESIGN, indent=2), encoding="utf-8")
        print(f"Sample design file created at: {design_file.resolve()}")
        print("Edit it, then rerun the script.")
        raise SystemExit(0)


def load_design(design_file: Path) -> Dict[str, Any]:
    return json.loads(design_file.read_text(encoding="utf-8"))


def now_iso() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def json_text(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def normalize_list(value: Any) -> List[Any]:
    """
    Normalize a value into a list.
    - None becomes [None]
    - scalar becomes [scalar]
    - list stays list
    """
    if isinstance(value, list):
        return value
    return [value]




def parse_datetime_or_none(value: Optional[str]) -> Optional[datetime]:
    if value in (None, "", "null"):
        return None

    # Support common simple formats.
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            pass

    # Fall back to fromisoformat for friendlier parsing.
    try:
        return datetime.fromisoformat(value)
    except ValueError as e:
        raise ValueError(f"Could not parse datetime value: {value}") from e


def expand_design(design: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Expand the model aggregation design into concrete parameter combinations.

    The design structure is expected to look like:

    {
      "DesignName": "...",
      "Description": "...",
      "FixedParameters": {...},
      "VariableParameters": {
         "DateWindows": [...],
         "CaseFilterProperties": [...],
         "EventFilterProperties": [...],
         "transforms": [...],
         ...
      }
    }
    """

    fixed = deepcopy(design.get("FixedParameters", {}))
    variable = deepcopy(design.get("VariableParameters", {}))

    # Pull out date windows specially because each one contributes
    # StartDateTime and EndDateTime together.
    date_windows = normalize_list(variable.pop("DateWindows", [{"StartDateTime": None, "EndDateTime": None}]))

    # Normalize every remaining variable parameter to a list.
    normalized_variable = {
        key: normalize_list(value)
        for key, value in variable.items()
    }

    variable_keys = list(normalized_variable.keys())
    variable_value_lists = [normalized_variable[k] for k in variable_keys]

    combinations: List[Dict[str, Any]] = []

    for date_window in date_windows:
        for values in itertools.product(*variable_value_lists) if variable_value_lists else [()]:
            combo = deepcopy(fixed)

            # Apply date window
            combo["StartDateTime"] = date_window.get("StartDateTime")
            combo["EndDateTime"] = date_window.get("EndDateTime")

            # Apply variable parameters
            for key, value in zip(variable_keys, values):
                combo[key] = value

            combinations.append(combo)

    return combinations


def parameter_summary(combo: Dict[str, Any]) -> str:
    # A compact human-readable summary for logs/console.
    fields = [
        "EventSet",
        "StartDateTime",
        "EndDateTime",
        "transforms",
        "ByCase",
        "metric",
        "CaseFilterProperties",
        "EventFilterProperties",
        "enumerate_multiple_events",
    ]
    return " | ".join(f"{k}={combo.get(k)!r}" for k in fields)


def call_create_update_markov_process(
    cnxn: pyodbc.Connection,
    combo: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Call dbo.CreateUpdateMarkovProcess for one concrete combination.

    Assumed signature:
      @ModelID = NULL,
      @EventSet,
      @enumerate_multiple_events,
      @StartDateTime,
      @EndDateTime,
      @transforms,
      @ByCase,
      @metric,
      @CaseFilterProperties,
      @EventFilterProperties

    Returns a dict with:
      - return_code
      - model_id (if inferred)
    """

    sql = """
    SET NOCOUNT ON;

    DECLARE @RC INT;

    EXEC @RC = dbo.CreateUpdateMarkovProcess
         @ModelID = NULL,
         @EventSet = ?,
         @enumerate_multiple_events = ?,
         @StartDateTime = ?,
         @EndDateTime = ?,
         @transforms = ?,
         @ByCase = ?,
         @metric = ?,
         @CaseFilterProperties = ?,
         @EventFilterProperties = ?;

    SELECT @RC AS ReturnCode;
    """

    params = [
        combo.get("EventSet"),
        combo.get("enumerate_multiple_events"),
        parse_datetime_or_none(combo.get("StartDateTime")),
        parse_datetime_or_none(combo.get("EndDateTime")),
        combo.get("transforms"),
        combo.get("ByCase"),
        combo.get("metric"),
        combo.get("CaseFilterProperties"),
        combo.get("EventFilterProperties"),
    ]

    cur = cnxn.cursor()
    cur.execute(sql, params)

    row = cur.fetchone()
    return_code = row[0] if row else None

    model_id = return_code if RETURN_CODE_IS_MODEL_ID else None

    return {
        "return_code": return_code,
        "model_id": model_id,
    }


def write_run_log(run_log_path: Path, rows: List[Dict[str, Any]]) -> None:
    run_log_path.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = [
        "RunTimestamp",
        "DesignName",
        "DesignDescription",
        "CombinationNumber",
        "Status",
        "ElapsedSeconds",
        "ModelID",
        "ReturnCode",
        "ErrorMessage",
        "EventSet",
        "enumerate_multiple_events",
        "StartDateTime",
        "EndDateTime",
        "transforms",
        "ByCase",
        "metric",
        "CaseFilterProperties",
        "EventFilterProperties",
        "FullCombinationJson",
    ]

    with run_log_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


# ============================================================
# MAIN
# ============================================================

def main() -> None:
    write_sample_design_if_missing(DESIGN_FILE)
    design = load_design(DESIGN_FILE)

    design_name = design.get("DesignName", "Unnamed Design")
    design_description = design.get("Description", "")

    combinations = expand_design(design)

    print(f"Design: {design_name}")
    print(f"Description: {design_description}")
    print(f"Expanded combinations: {len(combinations)}")

    log_rows: List[Dict[str, Any]] = []

    cnxn = None if DRY_RUN else get_connection()

    try:
        for i, combo in enumerate(combinations, start=1):
            if PRINT_EACH_COMBINATION:
                print(f"[{i}/{len(combinations)}] {parameter_summary(combo)}")

            start = time.perf_counter()
            status = "success"
            error_message = None
            return_code = None
            model_id = None

            try:
                if not DRY_RUN:
                    result = call_create_update_markov_process(cnxn, combo)
                    return_code = result.get("return_code")
                    model_id = result.get("model_id")
                    cnxn.commit()
                else:
                    status = "dry_run"

            except Exception as e:
                status = "error"
                error_message = str(e)
                if cnxn is not None:
                    cnxn.rollback()

                if STOP_ON_ERROR:
                    elapsed = round(time.perf_counter() - start, 4)
                    log_rows.append({
                        "RunTimestamp": now_iso(),
                        "DesignName": design_name,
                        "DesignDescription": design_description,
                        "CombinationNumber": i,
                        "Status": status,
                        "ElapsedSeconds": elapsed,
                        "ModelID": model_id,
                        "ReturnCode": return_code,
                        "ErrorMessage": error_message,
                        "EventSet": combo.get("EventSet"),
                        "enumerate_multiple_events": combo.get("enumerate_multiple_events"),
                        "StartDateTime": combo.get("StartDateTime"),
                        "EndDateTime": combo.get("EndDateTime"),
                        "transforms": combo.get("transforms"),
                        "ByCase": combo.get("ByCase"),
                        "metric": combo.get("metric"),
                        "CaseFilterProperties": combo.get("CaseFilterProperties"),
                        "EventFilterProperties": combo.get("EventFilterProperties"),
                        "FullCombinationJson": json_text(combo),
                    })
                    raise

            elapsed = round(time.perf_counter() - start, 4)

            log_rows.append({
                "RunTimestamp": now_iso(),
                "DesignName": design_name,
                "DesignDescription": design_description,
                "CombinationNumber": i,
                "Status": status,
                "ElapsedSeconds": elapsed,
                "ModelID": model_id,
                "ReturnCode": return_code,
                "ErrorMessage": error_message,
                "EventSet": combo.get("EventSet"),
                "enumerate_multiple_events": combo.get("enumerate_multiple_events"),
                "StartDateTime": combo.get("StartDateTime"),
                "EndDateTime": combo.get("EndDateTime"),
                "transforms": combo.get("transforms"),
                "ByCase": combo.get("ByCase"),
                "metric": combo.get("metric"),
                "CaseFilterProperties": combo.get("CaseFilterProperties"),
                "EventFilterProperties": combo.get("EventFilterProperties"),
                "FullCombinationJson": json_text(combo),
            })

    finally:
        if cnxn is not None:
            cnxn.close()

    write_run_log(RUN_LOG_CSV, log_rows)

    success_count = sum(1 for r in log_rows if r["Status"] in ("success", "dry_run"))
    error_count = sum(1 for r in log_rows if r["Status"] == "error")

    print()
    print("Run complete.")
    print(f"Successful/dry-run combinations: {success_count}")
    print(f"Errored combinations: {error_count}")
    print(f"Run log written to: {RUN_LOG_CSV.resolve()}")


if __name__ == "__main__":
    main()