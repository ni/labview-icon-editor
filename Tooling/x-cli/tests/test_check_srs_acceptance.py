"""Tests for SRS acceptance criteria validator (FGC-REQ-SPEC-001)."""
from __future__ import annotations

import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "scripts" / "check_srs_acceptance.py"


def run() -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python", str(SCRIPT)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )


def test_passes_when_all_have_acceptance_criteria():
    assert run().returncode == 0


def test_fails_when_missing_section(tmp_path: Path):
    target = tmp_path / "FGC-REQ-TEST-000.md"
    target.write_text("# Test\n", encoding="utf-8")
    repo_srs = REPO_ROOT / "docs" / "srs"
    # place file in docs/srs temporarily
    tmp_file = repo_srs / target.name
    tmp_file.write_text(target.read_text(encoding="utf-8"), encoding="utf-8")
    try:
        proc = run()
        assert proc.returncode != 0
        assert target.name in proc.stderr
    finally:
        tmp_file.unlink()
