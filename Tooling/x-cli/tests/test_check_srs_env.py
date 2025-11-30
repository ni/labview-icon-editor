"""Tests for SRS_ID environment validator (FGC-REQ-DEV-005)."""
from __future__ import annotations

import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "scripts" / "check_srs_env.py"

def run(ids: str):
    env = os.environ.copy()
    env["SRS_IDS"] = ids
    return subprocess.run(
        ["python", str(SCRIPT)],
        cwd=REPO_ROOT,
        env=env,
        capture_output=True,
        text=True,
    )

def test_valid_id_passes():
    assert run("FGC-REQ-DEV-005").returncode == 0

def test_unknown_id_fails():
    # TEST-REQ-XYZ-999 is a placeholder requirement ID used for negative testing.
    proc = run("TEST-REQ-XYZ-999")
    assert proc.returncode != 0
    assert "unknown SRS ID TEST-REQ-XYZ-999" in proc.stderr

def test_ambiguous_id_requires_version(tmp_path):
    srs_dir = REPO_ROOT / "docs" / "srs"
    tmp = srs_dir / "tmp_spec.md"
    tmp.write_text("Version: 2.0\n\nFGC-REQ-NOT-001\n")
    try:
        proc = run("FGC-REQ-NOT-001")
        assert proc.returncode != 0
        assert "maps to multiple specs" in proc.stderr
    finally:
        tmp.unlink()

def test_version_disambiguates(tmp_path):
    srs_dir = REPO_ROOT / "docs" / "srs"
    tmp = srs_dir / "tmp_spec.md"
    tmp.write_text("Version: 2.0\n\nFGC-REQ-NOT-001\n")
    try:
        assert run("FGC-REQ-NOT-001@1.0").returncode == 0
    finally:
        tmp.unlink()
