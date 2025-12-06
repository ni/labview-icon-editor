"""Tests for telemetry agent feedback check (FGC-REQ-DEV-003)."""

import sys
from pathlib import Path

from tests.TestUtil.run import run

SCRIPT_SRC = Path(__file__).resolve().parent.parent / "scripts" / "check_agent_feedback.py"


def setup_repo(tmp_path, module_text: str) -> Path:
    repo = tmp_path / "repo"
    repo.mkdir()
    (repo / "scripts").mkdir()
    (repo / "codex_rules").mkdir()
    (repo / "scripts" / "check_agent_feedback.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    (repo / "codex_rules" / "rule.py").write_text(module_text, encoding="utf-8")
    return repo


def run_check(repo: Path):
    script = repo / "scripts" / "check_agent_feedback.py"
    return run([sys.executable, str(script)], cwd=repo, check=False)


def test_detects_missing_agent_feedback(tmp_path):
    repo = setup_repo(tmp_path, "from foo import append_telemetry_entry\n")
    proc = run_check(repo)
    assert proc.returncode != 0
    assert "codex_rules/rule.py" in proc.stdout


def test_accepts_agent_feedback(tmp_path):
    module = (
        "from foo import append_telemetry_entry\n"
        "def main(agent_feedback):\n"
        "    pass\n"
    )
    repo = setup_repo(tmp_path, module)
    proc = run_check(repo)
    assert proc.returncode == 0

