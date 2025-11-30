"""Tests for verify_traceability.py (FGC-REQ-DEV-002)."""

import sys
from pathlib import Path

from tests.TestUtil.run import run

SCRIPT_SRC = Path(__file__).resolve().parent.parent / "scripts" / "verify_traceability.py"


def _run(repo: Path) -> int:
    proc = run([sys.executable, str(repo / "scripts" / "verify_traceability.py")], cwd=repo, check=False)
    return proc.returncode


def test_passes_when_all_ids_mapped(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST-REQ-DEV-999.md").write_text(
        "# TEST-REQ-DEV-999\nVersion: 0.0.1\n", encoding="utf-8"
    )
    (repo / "docs/traceability.yaml").write_text(
        "requirements:\n  - id: TEST-REQ-DEV-999\n    source: docs/srs/TEST-REQ-DEV-999.md\n",
        encoding="utf-8",
    )
    (repo / "scripts/verify_traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) == 0


def test_fails_when_requirement_unmapped(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST-REQ-DEV-999.md").write_text(
        "# TEST-REQ-DEV-999\nVersion: 0.0.1\n", encoding="utf-8"
    )
    (repo / "docs/traceability.yaml").write_text("requirements: []\n", encoding="utf-8")
    (repo / "scripts/verify_traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_fails_when_source_missing(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST-REQ-DEV-999.md").write_text(
        "# TEST-REQ-DEV-999\nVersion: 0.0.1\n", encoding="utf-8"
    )
    (repo / "docs/traceability.yaml").write_text(
        "requirements:\n  - id: TEST-REQ-DEV-999\n    source: missing.md\n",
        encoding="utf-8",
    )
    (repo / "scripts/verify_traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_fails_when_test_missing(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST-REQ-DEV-999.md").write_text(
        "# TEST-REQ-DEV-999\nVersion: 0.0.1\n", encoding="utf-8"
    )
    (repo / "docs/traceability.yaml").write_text(
        "requirements:\n  - id: TEST-REQ-DEV-999\n    source: docs/srs/TEST-REQ-DEV-999.md\n    tests:\n      - tests/missing.py\n",
        encoding="utf-8",
    )
    (repo / "scripts/verify_traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_fails_when_entry_missing_fields(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST-REQ-DEV-999.md").write_text(
        "# TEST-REQ-DEV-999\nVersion: 0.0.1\n", encoding="utf-8"
    )
    (repo / "docs/traceability.yaml").write_text(
        "requirements:\n  - source: docs/srs/TEST-REQ-DEV-999.md\n", encoding="utf-8"
    )
    (repo / "scripts/verify_traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_fails_when_id_invalid(tmp_path):
    repo = tmp_path
    (repo / "docs/srs").mkdir(parents=True)
    (repo / "scripts").mkdir()
    (repo / "docs/srs/TEST-REQ-DEV-999.md").write_text(
        "# TEST-REQ-DEV-999\nVersion: 0.0.1\n", encoding="utf-8"
    )
    (repo / "docs/traceability.yaml").write_text(
        "requirements:\n  - id: INVALID\n    source: docs/srs/TEST-REQ-DEV-999.md\n",
        encoding="utf-8",
    )
    (repo / "scripts/verify_traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_fails_on_malformed_yaml(tmp_path):
    repo = tmp_path
    (repo / "docs").mkdir(parents=True, exist_ok=True)
    (repo / "scripts").mkdir()
    (repo / "docs/traceability.yaml").write_text(
        "requirements: [\n", encoding="utf-8"
    )
    (repo / "scripts/verify_traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0


def test_missing_traceability_file(tmp_path):
    repo = tmp_path
    (repo / "scripts").mkdir()
    # Intentionally omit docs/traceability.yaml
    (repo / "scripts/verify_traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    assert _run(repo) != 0
