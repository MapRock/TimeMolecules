"""
Time Molecules AI Agent Event Logging Utility

Purpose
-------
This module writes lightweight AI-agent workflow events into a Time Molecules-
friendly shape, primarily for loading into STAGE.ImportEvents. It is intended
to let an AI agent or related workflow emit process events such as "start" and
"end" in a form that can later be ingested, analyzed, and modeled as part of
the larger event stream.

What it does
------------
- Creates a natural key for an AI-agent workflow case.
- Builds a stage-event record using the Time Molecules event shape.
- Writes that record to one of three targets:
    1. a live pyodbc SQL Server connection
    2. a local newline-delimited JSON file
    3. an HTTP/HTTPS endpoint via POST

Intended use
------------
Use this module when you want AI-agent activity to become part of the event
ensemble rather than remain trapped inside application logs. This allows agent
runs to be treated as cases made of events, such as workflow start, workflow
end, retries, approvals, or failures.

Current event shape
-------------------
The helper writes records with:
- CaseType = "AI Agent Workflow"
- Event = the supplied phase value
- CaseID = the generated or supplied natural key
- EventActualProperties = a JSON object containing agent context

Notes
-----
- The phase value is intentionally flexible right now. The old "start/end only"
  validation is commented out, which allows broader event naming if desired.
- For SQL Server writes, datetime values are kept as Python datetime objects for
  pyodbc insertion.
- For file and URL output, datetime values are converted to ISO-8601 strings.
- This module does not orchestrate the workflow itself. It only emits events.

Typical usage
-------------
1. Create a natural key once for the workflow case.
2. Call log_ai_agent_stage_event(...) at key points in the workflow.
3. Point the output either at SQL Server, a file, or an endpoint.

Example
-------
natural_key = make_ai_agent_natural_key("Time Molecules Agent", "metadata search")

log_ai_agent_stage_event(
    cnxn,
    agent_name="Time Molecules Agent",
    natural_key=natural_key,
    phase="start",
    source_id=62,
    workflow_name="metadata search",
    extra_actual_properties={"prompt": "How are Markov models created?"}
)

Author intent
-------------
This module is part of the larger idea that AI-agent runs can themselves be
modeled as event-driven processes inside Time Molecules, rather than treated
as opaque black boxes.
"""
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