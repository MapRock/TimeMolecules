from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
from typing import Any
import os


def make_ai_agent_natural_key(agent_name: str, workflow_name: str | None = None) -> str:
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    workflow_part = f"{workflow_name}:" if workflow_name else ""
    return f"ai-agent:{workflow_part}{agent_name}:{ts}:{uuid.uuid4().hex[:12]}"


def _is_url(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    parsed = urlparse(value)
    return parsed.scheme in ("http", "https") and bool(parsed.netloc)


def _is_pathlike(value: Any) -> bool:
    return isinstance(value, (str, os.PathLike)) and not _is_url(str(value))


def _is_pyodbc_connection(value: Any) -> bool:
    return value is not None and hasattr(value, "cursor") and hasattr(value, "commit")


def _build_stage_event_record(
    *,
    agent_name: str,
    natural_key: str,
    phase: str,
    source_id: int,
    workflow_name: str | None = None,
    access_bitmap: int | None = None,
    extra_actual_properties: dict | None = None,
) -> dict[str, Any]:
    # phase_norm = (phase or "").strip().lower()
    # if phase_norm not in {"start", "end"}:
    #     raise ValueError("phase must be 'start' or 'end'")


    now_utc = datetime.now(timezone.utc)
    now_local = datetime.now()

    actual_properties = {
        "agent_name": agent_name,
        "natural_key": natural_key,
        "phase": phase,
        "workflow_name": workflow_name,
        "logged_at_utc": now_utc.isoformat(),
    }

    if extra_actual_properties:
        actual_properties.update(extra_actual_properties)

    return {
        "SourceID": source_id,
        "CaseID": natural_key,
        "Event": phase,
        "EventDate": now_local,     # keep as datetime for pyodbc
        "AccessBitmap": access_bitmap,
        "CaseProperties": None,
        "CaseTargetProperties": None,
        "CaseType": "AI Agent Workflow",
        "DateAdded": now_local,     # keep as datetime for pyodbc
        "EventDescription": phase,
        "EventActualProperties": actual_properties,
        "EventExpectedProperties": None,
        "EventAggregationProperties": None,
        "EventIntendedProperties": None,
    }


def _record_for_json_output(record: dict[str, Any]) -> dict[str, Any]:
    """
    Convert datetime values to strings only for file/URL output.
    """
    out = dict(record)
    for key in ("EventDate", "DateAdded"):
        value = out.get(key)
        if isinstance(value, datetime):
            out[key] = value.isoformat()
    return out


def _write_stage_event_to_pyodbc(cnxn: Any, record: dict[str, Any]) -> bool:
    sql = """
    INSERT INTO STAGE.ImportEvents
    (
        SourceID,
        CaseID,
        [Event],
        EventDate,
        AccessBitmap,
        CaseProperties,
        CaseTargetProperties,
        CaseType,
        DateAdded,
        EventDescription,
        EventActualProperties,
        EventExpectedProperties,
        EventAggregationProperties,
        EventIntendedProperties
    )
    VALUES
    (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
    );
    """

    try:
        cur = cnxn.cursor()
        cur.execute(
            sql,
            record["SourceID"],
            record["CaseID"],
            record["Event"],
            record["EventDate"],  # datetime object
            record["AccessBitmap"],
            record["CaseProperties"],
            record["CaseTargetProperties"],
            record["CaseType"],
            record["DateAdded"],  # datetime object
            record["EventDescription"],
            json.dumps(record["EventActualProperties"], ensure_ascii=False),
            record["EventExpectedProperties"],
            record["EventAggregationProperties"],
            record["EventIntendedProperties"],
        )
        cnxn.commit()
        return True
    except Exception as e:
        print(f"⚠️ Failed to write AI agent stage event to SQL Server: {e}")
        try:
            cnxn.rollback()
        except Exception:
            pass
        return False


def _write_stage_event_to_file(path_value: str | os.PathLike, record: dict[str, Any]) -> bool:
    try:
        path = Path(path_value)
        path.parent.mkdir(parents=True, exist_ok=True)

        json_record = _record_for_json_output(record)

        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(json_record, ensure_ascii=False) + "\n")

        return True
    except Exception as e:
        print(f"⚠️ Failed to write AI agent stage event to file '{path_value}': {e}")
        return False


def _write_stage_event_to_url(url: str, record: dict[str, Any], timeout: int = 10) -> bool:
    try:
        json_record = _record_for_json_output(record)
        payload = json.dumps(json_record, ensure_ascii=False).encode("utf-8")

        req = Request(
            url,
            data=payload,
            headers={"Content-Type": "application/json; charset=utf-8"},
            method="POST",
        )

        with urlopen(req, timeout=timeout) as resp:
            status = getattr(resp, "status", 200)
            return 200 <= status < 300

    except HTTPError as e:
        print(f"⚠️ Failed to write AI agent stage event to URL '{url}': HTTP {e.code}")
        return False
    except URLError as e:
        print(f"⚠️ Failed to write AI agent stage event to URL '{url}': {e}")
        return False
    except Exception as e:
        print(f"⚠️ Failed to write AI agent stage event to URL '{url}': {e}")
        return False


def log_ai_agent_stage_event(
    cnxn,
    *,
    agent_name: str,
    natural_key: str,
    phase: str,
    source_id: int,
    workflow_name: str | None = None,
    access_bitmap: int | None = None,
    extra_actual_properties: dict | None = None,
) -> bool:
    if cnxn is None:
        return False

    record = _build_stage_event_record(
        agent_name=agent_name,
        natural_key=natural_key,
        phase=phase,
        source_id=source_id,
        workflow_name=workflow_name,
        access_bitmap=access_bitmap,
        extra_actual_properties=extra_actual_properties,
    )

    if _is_pyodbc_connection(cnxn):
        return _write_stage_event_to_pyodbc(cnxn, record)
    if _is_url(cnxn):
        return _write_stage_event_to_url(cnxn, record)
    if _is_pathlike(cnxn):
        return _write_stage_event_to_file(cnxn, record)

    print("⚠️ Unsupported cnxn type for log_ai_agent_stage_event.")
    return False