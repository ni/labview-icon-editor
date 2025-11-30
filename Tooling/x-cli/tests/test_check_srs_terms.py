"""Tests for SRS terminology validator (FGC-REQ-SPEC-001)."""
from __future__ import annotations

import subprocess
from pathlib import Path
import pytest
import shutil

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = "scripts/check_srs_terms.py"


def clone_repo(dst: Path) -> None:
    # Ignore ephemeral spec files created by other tests to avoid races on Windows
    ignore_tmp_specs = shutil.ignore_patterns("tmp_spec*.md")
    shutil.copytree(REPO_ROOT / "docs", dst / "docs", dirs_exist_ok=True, ignore=ignore_tmp_specs)
    shutil.copytree(REPO_ROOT / "scripts", dst / "scripts", dirs_exist_ok=True)


def run(cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["python", str(cwd / SCRIPT)], cwd=cwd, capture_output=True, text=True)


def test_passes_when_no_prohibited_terms(tmp_path):
    repo = tmp_path
    clone_repo(repo)
    assert run(repo).returncode == 0


@pytest.mark.parametrize("term", ["should", "must", "will"])
def test_fails_when_term_present(term: str, tmp_path):
    repo = tmp_path
    clone_repo(repo)
    srs_dir = repo / "docs" / "srs"
    tmp = srs_dir / f"tmp_spec_{term}.md"
    tmp.write_text(f"This {term} fail.\n", encoding="utf-8")
    proc = run(repo)
    assert proc.returncode != 0
    assert tmp.name in proc.stderr
