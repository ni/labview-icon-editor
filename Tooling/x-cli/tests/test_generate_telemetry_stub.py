"""Tests telemetry stub generator script."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from tests.TestUtil.run import run

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "generate_telemetry_stub.py"


def call(path: Path):
    return run([sys.executable, str(SCRIPT), str(path)], check=False)


def test_generates_stub_with_agent_feedback(tmp_path):
    target = tmp_path / "telemetry.json"
    proc = call(target)
    assert proc.returncode == 0
    data = json.loads(target.read_text())
    af = data["entries"][0]["agent_feedback"]
    assert af.startswith("### Cross-Agent Telemetry Recommendation")
    assert "no cross-agent feedback collected yet" in af
    assert "placeholder" not in af
    assert any(entry.get("source") == "qa.sh" for entry in data["entries"])

