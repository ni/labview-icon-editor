import os
import subprocess
import sys
from pathlib import Path

def run_script(*args):
    return subprocess.run([sys.executable, "scripts/scan_srs_refs.py", *args],
                          cwd=Path(__file__).resolve().parents[1],
                          capture_output=True, text=True)

def test_scan_srs_refs_ok():
    proc = run_script("src", "scripts", ".github/workflows")
    assert proc.returncode == 0, proc.stderr


def test_scan_srs_refs_reports_missing(tmp_path):
    repo_root = Path(__file__).resolve().parents[1]
    tmp_file = repo_root / "src" / "temp_unmapped.cs"
    tmp_file.write_text("// temp")
    try:
        proc = run_script("src", "scripts", ".github/workflows")
    finally:
        tmp_file.unlink()
    assert proc.returncode != 0
    assert "temp_unmapped.cs" in proc.stderr
