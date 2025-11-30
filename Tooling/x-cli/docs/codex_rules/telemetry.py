"""Telemetry utilities for cross-agent coordination.

Implements FGC-REQ-TEL-001.

Entries may include optional ``agent_feedback`` summarising the session and
details about failures via ``exception_type`` and ``exception_message``.
"""
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Sequence

TELEMETRY_PATH = Path(".codex/telemetry.json")
SUMMARY_PATH = Path("telemetry/summary.json")


def load_telemetry() -> List[Dict[str, Any]]:
    """Return all telemetry entries from the JSON file."""
    if TELEMETRY_PATH.exists():
        try:
            data = json.loads(TELEMETRY_PATH.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                return list(data.get("entries", []))
        except Exception as exc:
            print(
                f"Warning: failed to load telemetry from {TELEMETRY_PATH} "
                f"({type(exc).__name__})",
                file=sys.stderr,
            )
    return []


def append_telemetry_entry(
    entry: Dict[str, Any],
    agent_feedback: str | None = None,
    srs_ids: List[str] | None = None,
    command: Sequence[str] | str | None = None,
    exit_status: int | None = None,
    exception_type: str | None = None,
    exception_message: str | None = None,
) -> None:
    """Append a telemetry entry and persist it to disk.

    The entry must contain at least ``modules_inspected`` and ``checks_skipped``.
    Optional fields ``ci_log_paths`` and ``failing_tests`` are normalised to lists.
    Optional ``srs_ids`` are recorded (defaults to an empty list).
    Optional ``agent_feedback`` is stored verbatim to capture human context.
    Optional ``command`` and ``exit_status`` capture subprocess context for
    diagnosing tool failures. ``command`` is normalised to a list of strings.
    Optional ``exception_type`` and ``exception_message`` capture exception
    details for diagnostics.
    A UTC ``timestamp`` is added if not already present.
    A boolean ``srs_omitted`` records whether any SRS IDs were supplied.
    """
    def _list_of_strings(value: Any, field: str) -> List[str]:
        """Return *value* as a list of strings or raise ``ValueError``."""
        if isinstance(value, list):
            items = value
        elif isinstance(value, tuple):
            items = list(value)
        elif isinstance(value, str):
            items = [value]
        else:
            raise ValueError(f"{field} must be a list of strings")
        if not all(isinstance(v, str) for v in items):
            raise ValueError(f"{field} entries must be strings")
        return items

    # Validate required fields
    for required in ("modules_inspected", "checks_skipped"):
        if required not in entry:
            raise ValueError(f"{required} is required")
        entry[required] = _list_of_strings(entry[required], required)

    # Normalise optional list fields
    for key in ("ci_log_paths", "failing_tests"):
        if key in entry:
            entry[key] = _list_of_strings(entry[key], key)
        else:
            entry[key] = []

    if agent_feedback is not None:
        if not isinstance(agent_feedback, str):
            raise ValueError("agent_feedback must be a string")
        entry["agent_feedback"] = agent_feedback
    if command is not None:
        command_list = [command] if isinstance(command, str) else list(command)
        if not all(isinstance(v, str) for v in command_list):
            raise ValueError("command entries must be strings")
        entry["command"] = command_list
    if exit_status is not None and not isinstance(exit_status, int):
        raise ValueError("exit_status must be an int")
    if exit_status is not None:
        entry["exit_status"] = exit_status
    if exception_type is not None:
        if not isinstance(exception_type, str):
            raise ValueError("exception_type must be a string")
        entry["exception_type"] = exception_type
    if exception_message is not None:
        if not isinstance(exception_message, str):
            raise ValueError("exception_message must be a string")
        entry["exception_message"] = exception_message
    if srs_ids is None:
        srs_ids = []
    else:
        srs_ids = _list_of_strings(srs_ids, "srs_ids")
    entry["srs_ids"] = srs_ids
    entry["srs_omitted"] = len(srs_ids) == 0

    if "timestamp" not in entry:
        entry["timestamp"] = datetime.utcnow().isoformat()

    entries = load_telemetry()
    entries.append(entry)
    TELEMETRY_PATH.parent.mkdir(parents=True, exist_ok=True)
    TELEMETRY_PATH.write_text(
        json.dumps({"entries": entries}, indent=2), encoding="utf-8"
    )


def _write_summary(entries: List[Dict[str, Any]]) -> None:
    """Write a condensed summary of ``entries`` to ``telemetry/summary.json``."""
    total = len(entries)
    omitted = sum(1 for e in entries if e.get("srs_omitted"))
    srs_ids: List[str] = []
    for e in entries:
        for sid in e.get("srs_ids", []):
            if sid not in srs_ids:
                srs_ids.append(sid)
    summary = {
        "total_entries": total,
        "srs_omitted_count": omitted,
        "srs_omission_rate": omitted / total if total else 0.0,
        "srs_ids": sorted(srs_ids),
    }
    SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2), encoding="utf-8")


def record_telemetry_entry(
    entry: Dict[str, Any],
    agent_feedback: str | None = None,
    srs_ids: List[str] | None = None,
    command: Sequence[str] | str | None = None,
    exit_status: int | None = None,
    exception_type: str | None = None,
    exception_message: str | None = None,
) -> None:
    """Append a telemetry entry and update the summary file."""
    append_telemetry_entry(
        entry,
        agent_feedback=agent_feedback,
        srs_ids=srs_ids,
        command=command,
        exit_status=exit_status,
        exception_type=exception_type,
        exception_message=exception_message,
    )
    _write_summary(load_telemetry())
