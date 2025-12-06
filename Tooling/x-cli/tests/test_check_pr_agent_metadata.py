"""Tests Agent Checklist and AGENTS digest validator (FGC-REQ-CI-017)."""
from pathlib import Path
import hashlib
import sys

from tests.TestUtil.run import run

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "check_pr_agent_metadata.py"
ROOT = Path(__file__).resolve().parent.parent


def _digest() -> str:
    data = (ROOT / "AGENTS.md").read_bytes()
    return hashlib.sha256(data).hexdigest()


def call(text: str, tmp_path: Path) -> int:
    pr = tmp_path / "desc.md"
    pr.write_text(text, encoding="utf-8")
    proc = run(
        [sys.executable, str(SCRIPT), str(pr), "--digest", _digest()],
        check=False,
    )
    return proc.returncode


def test_valid(tmp_path: Path) -> None:
    d = _digest()
    text = f"## Agent Checklist\n- [ ] item\n\nAGENTS.md digest: SHA256 {d}\n"
    assert call(text, tmp_path) == 0


def test_missing_checklist(tmp_path: Path) -> None:
    d = _digest()
    text = f"AGENTS.md digest: SHA256 {d}\n"
    assert call(text, tmp_path) != 0


def test_bad_digest(tmp_path: Path) -> None:
    text = "## Agent Checklist\n- [ ] item\n\nAGENTS.md digest: SHA256 123\n"
    assert call(text, tmp_path) != 0
