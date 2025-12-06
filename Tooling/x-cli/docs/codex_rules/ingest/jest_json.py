"""Jest JSON ingestor.

Parses output from `jest --json --outputFile=...`. It expects an object with a
`testResults` array, each containing `assertionResults`.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List


def parse_jest_json(path: str) -> List[Dict]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    events: List[Dict] = []
    suites = data.get("testResults") if isinstance(data, dict) else None
    if not isinstance(suites, list):
        return events
    for suite in suites:
        file_path = suite.get("name") or suite.get("testFilePath") or ""
        suite_name = Path(file_path).name or "jest"
        for ar in suite.get("assertionResults", []) or []:
            status = "failed" if (ar.get("status") or "").lower() == "failed" else "passed"
            title = (ar.get("title") or "").strip() or "unknown"
            duration_ms = int(ar.get("duration") or 0)
            test_id = f"{suite_name}#{title}"
            events.append(
                {
                    "test_id": test_id,
                    "suite": suite_name,
                    "status": status,
                    "duration_ms": duration_ms,
                    "file": file_path,
                }
            )
    return events
