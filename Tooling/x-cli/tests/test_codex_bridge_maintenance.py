"""Tests for maintenance hook in codex_bridge (FGC-REQ-AIC-004@1.0)."""
from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import types
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parent.parent

# codex_bridge depends on requests; stub it for isolation
requests_stub = types.ModuleType("requests")
sys.modules.setdefault("requests", requests_stub)

SPEC = importlib.util.spec_from_file_location(
    "codex_bridge", ROOT / "scripts" / "codex_bridge.py"
)
codex_bridge = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(codex_bridge)


def _write_script(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")
    path.chmod(0o755)


def test_run_maintenance_env(monkeypatch, tmp_path: Path) -> None:
    script = tmp_path / "hook.sh"
    _write_script(script, "#!/usr/bin/env bash\necho hi > ran\n")
    monkeypatch.setenv("CODEX_MAINTENANCE_CMD", str(script))
    monkeypatch.chdir(tmp_path)
    codex_bridge._run_maintenance()
    assert (tmp_path / "ran").exists()


def test_run_maintenance_default(monkeypatch, tmp_path: Path) -> None:
    maint = tmp_path / ".codex" / "maintenance.sh"
    maint.parent.mkdir()
    _write_script(maint, "#!/usr/bin/env bash\necho ok > ran\n")
    monkeypatch.delenv("CODEX_MAINTENANCE_CMD", raising=False)
    monkeypatch.chdir(tmp_path)
    codex_bridge._run_maintenance()
    assert (tmp_path / "ran").exists()


def test_run_maintenance_failure(monkeypatch, tmp_path: Path) -> None:
    bad = tmp_path / "bad.sh"
    _write_script(bad, "#!/usr/bin/env bash\nexit 2\n")
    monkeypatch.setenv("CODEX_MAINTENANCE_CMD", str(bad))
    monkeypatch.chdir(tmp_path)
    with pytest.raises(subprocess.CalledProcessError):
        codex_bridge._run_maintenance()

