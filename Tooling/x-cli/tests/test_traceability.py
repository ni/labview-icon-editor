"""Tests for verify-traceability script (FGC-REQ-DEV-002)."""

import sys
from pathlib import Path

from tests.TestUtil.run import run

def run_check() -> int:
    script = Path(__file__).resolve().parent.parent / 'scripts' / 'verify-traceability.py'
    proc = run([sys.executable, str(script)])
    return proc.returncode

def test_traceability_file_sources_exist():
    assert run_check() == 0


def test_missing_source_file(tmp_path):
    repo = tmp_path / "repo"
    (repo / "docs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    trace = repo / "docs" / "traceability.yaml"
    trace.write_text(
        # TEST-REQ-DEV-999 is a placeholder requirement ID for negative testing.
        "requirements:\n  - id: TEST-REQ-DEV-999\n    source: missing.md\n",
        encoding="utf-8",
    )
    script_src = Path(__file__).resolve().parent.parent / "scripts" / "verify-traceability.py"
    script_dst = repo / "scripts" / "verify-traceability.py"
    script_dst.write_text(script_src.read_text(encoding="utf-8"), encoding="utf-8")
    proc = run([sys.executable, str(script_dst)], cwd=repo, check=False)
    assert proc.returncode != 0


def test_missing_requirement_id(tmp_path):
    repo = tmp_path / "repo"
    (repo / "docs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    source = repo / "docs" / "dummy.md"
    source.write_text("placeholder\n", encoding="utf-8")
    trace = repo / "docs" / "traceability.yaml"
    trace.write_text(
        # TEST-REQ-DEV-999 is a placeholder requirement ID for negative testing.
        "requirements:\n  - id: TEST-REQ-DEV-999\n    source: docs/dummy.md\n",
        encoding="utf-8",
    )
    script_src = Path(__file__).resolve().parent.parent / "scripts" / "verify-traceability.py"
    script_dst = repo / "scripts" / "verify-traceability.py"
    script_dst.write_text(script_src.read_text(encoding="utf-8"), encoding="utf-8")
    proc = run([sys.executable, str(script_dst)], cwd=repo, check=False)
    assert proc.returncode != 0
