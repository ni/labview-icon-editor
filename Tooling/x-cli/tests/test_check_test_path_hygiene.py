"""Tests for the path hygiene checker script."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).parents[1] / "scripts" / "check_test_path_hygiene.py"


def run_check(test_dir: Path) -> tuple[int, str]:
    """Run the hygiene script on *test_dir* and return (rc, stdout)."""

    result = subprocess.run(
        [sys.executable, str(SCRIPT), str(test_dir)],
        capture_output=True,
        text=True,
    )
    return result.returncode, result.stdout


def test_no_violation(tmp_path: Path) -> None:
    (tmp_path / "test_ok.py").write_text(
        'from pathlib import Path\nPath(__file__).resolve().parents[1] / "docs/foo.txt"\n'
    )
    rc, out = run_check(tmp_path)
    assert rc == 0
    assert "Path hygiene OK." in out


def test_violation(tmp_path: Path) -> None:
    (tmp_path / "test_bad.py").write_text(
        'from pathlib import Path\nPath("docs/foo.txt").read_text()\n'
    )
    rc, out = run_check(tmp_path)
    assert rc == 1
    assert "avoid 'docs/...' relative to the working directory" in out


def test_nested_violation(tmp_path: Path) -> None:
    (tmp_path / "test_nested.py").write_text(
        'open("docs/guide/foo.txt")\n'
    )
    rc, out = run_check(tmp_path)
    assert rc == 1
    assert "avoid 'docs/...' relative to the working directory" in out


def test_symlink_violation(tmp_path: Path) -> None:
    src = tmp_path / "test_src.py"
    src.write_text('Path("docs/foo.txt").read_text()\n')
    try:
        (tmp_path / "test_link.py").symlink_to(src)
    except (OSError, NotImplementedError):
        pytest.skip("symlink creation requires elevated privileges")
    rc, out = run_check(tmp_path)
    assert rc == 1
    assert "avoid 'docs/...' relative to the working directory" in out


def test_open_path_violation(tmp_path: Path) -> None:
    (tmp_path / "test_open_path.py").write_text(
        'from pathlib import Path\nopen(Path("docs/foo.txt"))\n'
    )
    rc, out = run_check(tmp_path)
    assert rc == 1
    assert "avoid 'docs/...' relative to the working directory" in out


def test_violation_in_subdirectory(tmp_path: Path) -> None:
    sub = tmp_path / "nested" / "pkg"
    sub.mkdir(parents=True)
    (sub / "test_bad.py").write_text('open("docs/foo.txt")\n')
    rc, out = run_check(tmp_path)
    assert rc == 1
    assert "avoid 'docs/...' relative to the working directory" in out

