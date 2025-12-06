from pathlib import Path
import pytest

from tests.conftest_write_guard import _fs_write_guard


def _activate(monkeypatch, tmp_path):
    monkeypatch.setenv("ENFORCE_WRITE_GUARD", "1")
    monkeypatch.chdir(tmp_path)
    _fs_write_guard.__wrapped__(monkeypatch)


def test_blocks_write_outside(tmp_path, monkeypatch):
    _activate(monkeypatch, tmp_path)
    outside = tmp_path.parent / "outside.txt"
    with pytest.raises(PermissionError):
        open(outside, "w").close()


def test_allows_write_inside(tmp_path, monkeypatch):
    _activate(monkeypatch, tmp_path)
    inside = Path("inside.txt")
    inside.write_text("ok")
    assert inside.exists()
