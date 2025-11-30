"""Tests for verify_srs_registry.py (FGC-REQ-SPEC-001)."""

import sys
from pathlib import Path

import shutil
from tests.TestUtil.run import run

SCRIPT_SRC = Path(__file__).resolve().parent.parent / "scripts" / "verify_srs_registry.py"


def _run(repo: Path) -> int:
    proc = run([sys.executable, str(repo / "scripts" / "verify_srs_registry.py")], cwd=repo, check=False)
    return proc.returncode


def test_registry_passes_on_repo_root(tmp_path):
    repo = tmp_path
    root = Path(__file__).resolve().parents[1]
    shutil.copytree(root / "docs", repo / "docs", dirs_exist_ok=True)
    shutil.copytree(root / "scripts", repo / "scripts", dirs_exist_ok=True)
    assert _run(repo) == 0


def test_missing_version_line(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST-REQ-DEV-999.md").write_text("# TEST-REQ-DEV-999\n", encoding="utf-8")
    (repo / "scripts/verify_srs_registry.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_missing_requirement_id(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST.md").write_text("Version: 0.0.1\n", encoding="utf-8")
    (repo / "scripts/verify_srs_registry.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_duplicate_ids_fail(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    text = "# TEST-REQ-DEV-999\nVersion: 0.0.1\n"
    (repo / "docs/srs/TEST-REQ-DEV-999.md").write_text(text, encoding="utf-8")
    (repo / "docs/srs/TEST-REQ-DEV-999b.md").write_text(text, encoding="utf-8")
    (repo / "scripts/verify_srs_registry.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_invalid_id_format_fails(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    # ID missing area segment
    (repo / "docs/srs/TEST.md").write_text("# TEST-REQ-99\nVersion: 0.0.1\n", encoding="utf-8")
    (repo / "scripts/verify_srs_registry.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_hyphenated_domain_succeeds(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST-REQ-QA-ISO-999.md").write_text(
        "# TEST-REQ-QA-ISO-999\nVersion: 0.0.1\n", encoding="utf-8"
    )
    (repo / "scripts/verify_srs_registry.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) == 0


def test_invalid_version_format(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST-REQ-DEV-999.md").write_text(
        "# TEST-REQ-DEV-999\nVersion: 0\n", encoding="utf-8"
    )
    (repo / "scripts/verify_srs_registry.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0
