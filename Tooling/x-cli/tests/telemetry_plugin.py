"""pytest plugin capturing telemetry from test runs."""

"""Pytest plugin to record telemetry (FGC-REQ-TEL-001)."""

import json
from pathlib import Path
from typing import Dict, List

_marker_cache: Dict[str, List[str]] = {}


def pytest_sessionstart(session):
    path = Path("artifacts/test-telemetry.jsonl")
    if path.exists():
        path.unlink()


def pytest_runtest_setup(item):
    deps = [m.args[0] for m in item.iter_markers(name="external_dep")]
    _marker_cache[item.nodeid] = deps


def pytest_runtest_logreport(report):
    if report.when != "call" and not (report.when == "setup" and report.outcome == "skipped"):
        return
    deps = _marker_cache.get(report.nodeid, [])
    entry = {
        "test": report.nodeid,
        "language": "python",
        "dependencies": deps,
        "outcome": report.outcome,
        "duration": report.duration,
    }
    path = Path("artifacts")
    path.mkdir(exist_ok=True)
    with (path / "test-telemetry.jsonl").open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")
