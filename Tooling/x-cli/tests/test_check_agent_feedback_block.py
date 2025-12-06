"""Tests PR description feedback block validator (FGC-REQ-DEV-004)."""
from pathlib import Path
import sys

from tests.TestUtil.run import run

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "check_agent_feedback_block.py"
BLOCK = (
    "### Cross-Agent Telemetry Recommendation\n\n"
    "#### Effectiveness\n-\n\n"
    "#### Obstacles\n-\n\n"
    "#### Improvements\n-\n"
)

def call(path):
    return run([sys.executable, str(SCRIPT), str(path)], check=False)

def test_valid_block(tmp_path):
    pr = tmp_path / "desc.md"
    pr.write_text(BLOCK, encoding="utf-8")
    proc = call(pr)
    assert proc.returncode == 0

def test_missing_section(tmp_path):
    pr = tmp_path / "desc.md"
    bad = (
        "### Cross-Agent Telemetry Recommendation\n\n"
        "#### Effectiveness\n-\n\n"
        "#### Obstacles\n-\n"
    )
    pr.write_text(bad, encoding="utf-8")
    proc = call(pr)
    assert proc.returncode != 0
