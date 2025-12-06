"""Tests for workflow SRS annotation verifier (FGC-REQ-DEV-006)."""

import sys
from pathlib import Path

from tests.TestUtil.run import run

SCRIPT_SRC = Path(__file__).resolve().parent.parent / "scripts" / "verify-workflow-srs.py"


def setup_repo(tmp_path, workflow_text: str, trace_text: str) -> Path:
    repo = tmp_path / "repo"
    (repo / ".github" / "workflows").mkdir(parents=True)
    (repo / "docs").mkdir()
    (repo / "scripts").mkdir()
    (repo / ".github" / "workflows" / "test.yml").write_text(workflow_text, encoding="utf-8")
    (repo / "docs" / "traceability.yaml").write_text(trace_text, encoding="utf-8")
    (repo / "scripts" / "verify-workflow-srs.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    return repo


def run_check(repo: Path):
    script = repo / "scripts" / "verify-workflow-srs.py"
    return run([sys.executable, str(script)], cwd=repo, check=False)


def test_valid_workflow(tmp_path):
    repo = setup_repo(
        tmp_path,
        "# SRS: FGC-REQ-DEV-001\n",
        "requirements:\n  - id: FGC-REQ-DEV-001\n",
    )
    assert run_check(repo).returncode == 0


def test_missing_annotation(tmp_path):
    repo = setup_repo(
        tmp_path,
        "name: test\n",
        "requirements:\n  - id: FGC-REQ-DEV-001\n",
    )
    proc = run_check(repo)
    assert proc.returncode != 0
    assert "missing '# SRS:' annotation" in proc.stderr


def test_unknown_id(tmp_path):
    repo = setup_repo(
        tmp_path,
        "# SRS: TEST-REQ-DEV-999\n",
        "requirements:\n  - id: FGC-REQ-DEV-001\n",
    )
    proc = run_check(repo)
    assert proc.returncode != 0
    # TEST-REQ-DEV-999 is a placeholder requirement ID used for negative testing.
    assert "unknown SRS ID TEST-REQ-DEV-999" in proc.stderr

