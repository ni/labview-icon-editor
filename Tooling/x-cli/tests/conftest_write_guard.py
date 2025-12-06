"""
CI write-guard: when ENFORCE_WRITE_GUARD=1, prevent tests from writing outside the per-test
temporary working directory. Complements isolation fixtures and catches residual shared-state writes.
"""
from __future__ import annotations
import builtins, os
from pathlib import Path
import pytest

ALLOW_SUFFIXES = ("coverage_html", "coverage.xml", ".pytest_cache")

def _is_allowed_write(path: Path, cwd: Path) -> bool:
    try:
        p = path.resolve()
    except Exception:
        return False
    # Normalize for Windows case-insensitive paths
    p_str = str(p)
    cwd_str = str(cwd)
    if os.name == "nt":
        p_str = p_str.lower()
        cwd_str = cwd_str.lower()
    if p_str.startswith(cwd_str):
        return True
    for suf in ALLOW_SUFFIXES:
        if str(p).endswith(suf):
            return True
    return False

@pytest.fixture(autouse=True)
def _fs_write_guard(monkeypatch):
    if os.getenv("ENFORCE_WRITE_GUARD", "") != "1":
        return
    cwd = Path.cwd()
    real_open = builtins.open
    def guarded_open(file, mode="r", *args, **kwargs):
        if any(m in mode for m in ("w", "a", "+")) and not _is_allowed_write(Path(file), cwd):
            raise PermissionError(f"Write outside tmp cwd blocked by guard: {file}")
        return real_open(file, mode, *args, **kwargs)
    monkeypatch.setattr(builtins, "open", guarded_open, raising=True)
    # Guard Path.write_* as well
    P = Path
    real_wt, real_wb = P.write_text, P.write_bytes
    def _wt(self, *a, **k):
        if not _is_allowed_write(self, cwd):
            raise PermissionError(f"write_text blocked outside tmp cwd: {self}")
        return real_wt(self, *a, **k)
    def _wb(self, *a, **k):
        if not _is_allowed_write(self, cwd):
            raise PermissionError(f"write_bytes blocked outside tmp cwd: {self}")
        return real_wb(self, *a, **k)
    monkeypatch.setattr(P, "write_text", _wt, raising=True)
    monkeypatch.setattr(P, "write_bytes", _wb, raising=True)
