"""JUnit XML ingestor for the codex rules engine.

Parses JUnit XML files (as produced by Maven/Surefire, pytest‑junit, etc.) and
emits a list of normalized test case records.  Only failing test cases are
relevant for rule generation; however, passed tests are included for completeness.
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from typing import Dict, List


def parse_junit(path: str) -> List[Dict]:
    """Parse a JUnit XML file and return a list of test case dictionaries.

    Each dictionary has the keys:
      - test_id: ``classname#name``
      - suite:  the test suite name (classname)
      - status: 'failed' or 'passed'
      - duration_ms: runtime in milliseconds (if provided)
      - file: file hint (if provided in the testcase attributes)
    """
    results: List[Dict] = []
    tree = ET.parse(path)
    root = tree.getroot()
    for tc in root.iter("testcase"):
        class_name = tc.attrib.get("classname", "")
        name = tc.attrib.get("name", "")
        test_id = f"{class_name}#{name}"
        suite = class_name
        # duration in seconds; convert to ms
        dur_ms = 0
        if "time" in tc.attrib:
            try:
                dur_ms = int(float(tc.attrib["time"]) * 1000)
            except ValueError:
                pass
        # Determine file hint if present
        file_hint = tc.attrib.get("file", "")
        status = "passed"
        # Check for failures or errors
        for child in tc:
            tag = child.tag.lower()
            if tag in {"failure", "error"}:
                status = "failed"
                break
        results.append(
            {
                "test_id": test_id,
                "suite": suite,
                "status": status,
                "duration_ms": dur_ms,
                "file": file_hint,
            }
        )
    return results
