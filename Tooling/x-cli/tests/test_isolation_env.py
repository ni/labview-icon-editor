import os
from pathlib import Path


def test_isolated_environment() -> None:
    """Each test runs in a unique temp directory exported via FAKEG_REPO_ROOT."""
    cwd = Path.cwd().resolve()
    repo_root = Path(__file__).resolve().parents[1]
    assert cwd != repo_root
    assert os.environ["FAKEG_REPO_ROOT"] == str(cwd)
    docs = cwd / "docs"
    assert docs.is_dir()
    marker = docs / "write_test.txt"
    marker.write_text("ok", encoding="utf-8")
    assert marker.read_text(encoding="utf-8") == "ok"
    assert not (repo_root / "docs" / "write_test.txt").exists()

