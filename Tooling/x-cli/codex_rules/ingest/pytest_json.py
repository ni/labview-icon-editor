"""Pytest JSON ingestor.

Supports the `pytest-json-report` plugin format (top-level key `tests`) as well
as simple arrays of test case dicts. Falls back gracefully when fields are
missing.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List


def parse_pytest_json(path: str) -> List[Dict]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    events: List[Dict] = []

    # Format A: {"tests": [{ "nodeid": "path::Class::test", "outcome": "failed", "duration": 0.12 }, ...]}
    tests = None
    if isinstance(data, dict) and isinstance(data.get("tests"), list):
        tests = data["tests"]
    elif isinstance(data, list):  # Format B: simplified array of dicts
        tests = data

    if not tests:
        return events

    for t in tests:
        nodeid = t.get("nodeid") or t.get("id") or ""
        outcome = (t.get("outcome") or "").lower()
        status = "failed" if outcome == "failed" else "passed"
        # duration is seconds; fall back to 0
        dur_s = t.get("duration") or t.get("call", {}).get("duration") or 0
        try:
            duration_ms = int(float(dur_s) * 1000)
        except Exception:
            duration_ms = 0
        # nodeid looks like: "tests/test_logging.py::TestLogger::test_no_deadlock"
        parts = nodeid.split("::") if nodeid else []
        file_hint = parts[0] if parts else ""
        suite = parts[0] if parts else "pytest"
        test_name = parts[-1] if parts else nodeid or "unknown"
        test_id = f"{suite}#{test_name}"
        events.append(
            {
                "test_id": test_id,
                "suite": suite,
                "status": status,
                "duration_ms": duration_ms,
                "file": file_hint,
            }
        )
    return events
