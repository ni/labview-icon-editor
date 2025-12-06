"""Tests telemetry feedback block validator (FGC-REQ-TEL-001, FGC-REQ-DEV-004)."""

import json
import sys
from pathlib import Path

from tests.TestUtil.run import run


SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "check_telemetry_block.py"
BLOCK = (
    "### Cross-Agent Telemetry Recommendation\n\n"
    "#### Effectiveness\n-\n\n"
    "#### Obstacles\n-\n\n"
    "#### Improvements\n-\n"
)

def write(entries, path):
    path.write_text(json.dumps({"entries": entries}), encoding="utf-8")

def call(path):
    return run([sys.executable, str(SCRIPT), str(path)], check=False)

def test_valid_block(tmp_path):
    telemetry = tmp_path / "telemetry.json"
    write([{"agent_feedback": BLOCK}], telemetry)
    proc = call(telemetry)
    assert proc.returncode == 0

def test_missing_section(tmp_path):
    telemetry = tmp_path / "telemetry.json"
    bad = (
        "### Cross-Agent Telemetry Recommendation\n\n"
        "#### Effectiveness\n-\n\n"
        "#### Obstacles\n-\n"
    )
    write([{"agent_feedback": bad}], telemetry)
    proc = call(telemetry)
    assert proc.returncode != 0
