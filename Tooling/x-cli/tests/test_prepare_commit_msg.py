"""Tests for commit message template population (FGC-REQ-DEV-005)."""

import json
import sys
from pathlib import Path

from tests.TestUtil.run import run


def test_prepare_commit_msg(tmp_path):
    repo_root = Path(__file__).resolve().parent.parent
    meta_path = repo_root / ".codex" / "metadata.json"
    original = meta_path.read_text(encoding="utf-8") if meta_path.exists() else None

    meta_path.write_text(
        json.dumps(
            {
                "summary": "Test commit",
                "change_type": "impl",
                "srs_ids": ["FGC-REQ-CLI-001"],
                "issue": 42,
            }
        ),
        encoding="utf-8",
    )

    msg_path = tmp_path / "COMMIT_MSG"
    msg_path.write_text("", encoding="utf-8")

    script = repo_root / "scripts" / "prepare-commit-msg.py"
    run([sys.executable, str(script), str(msg_path)])

    try:
        text = msg_path.read_text(encoding="utf-8")
        assert text == "Test commit\n\ncodex: impl | SRS: FGC-REQ-CLI-001@1.0 | issue: #42\n"
        check_script = repo_root / "scripts" / "check-commit-msg.py"
        proc = run([sys.executable, str(check_script), str(msg_path)], check=False)
        assert proc.returncode == 0
    finally:
        if original is None:
            meta_path.unlink()
        else:
            meta_path.write_text(original, encoding="utf-8")
