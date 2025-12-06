from __future__ import annotations

import importlib.util
import json
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


def test_policy_command(monkeypatch: pytest.MonkeyPatch, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    event = {
        "issue": {"number": 0},
        "repository": {"owner": {"login": "foo"}, "name": "bar"},
        "comment": {"body": "/codex policy", "user": {"login": "alice"}},
    }
    ev_path = tmp_path / "event.json"
    ev_path.write_text(json.dumps(event), encoding="utf-8")

    monkeypatch.setenv("GITHUB_TOKEN", "t")
    monkeypatch.setenv("LLM_API_KEY", "k")
    monkeypatch.setenv("CODEX_ALLOWED_USERS", "alice,bob")
    monkeypatch.setenv("CODEX_LABEL_REQUIRED", "codex-ready")
    monkeypatch.setenv("CODEX_ALLOWED_GLOBS", "src/**,docs/**")
    monkeypatch.setenv("CODEX_MAX_LINES", "123")
    monkeypatch.setattr(sys, "argv", ["codex_bridge.py", "--event", str(ev_path)])

    with pytest.raises(SystemExit) as exc:
        codex_bridge.main()
    assert exc.value.code == 0

    out = capsys.readouterr().out
    assert "**Codex Policy**" in out
    assert "- Allowed users: alice, bob" in out
    assert "- Required label: #codex-ready" in out
    assert "- Allowed globs: docs/**, src/**" in out
    assert "- Max patch lines: 123" in out
    assert ".codex/README.md" in out


def test_policy_defaults(monkeypatch: pytest.MonkeyPatch, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    event = {
        "issue": {"number": 0},
        "repository": {"owner": {"login": "foo"}, "name": "bar"},
        "comment": {"body": "/codex policy", "user": {"login": "alice"}},
    }
    ev_path = tmp_path / "event.json"
    ev_path.write_text(json.dumps(event), encoding="utf-8")

    monkeypatch.setenv("GITHUB_TOKEN", "t")
    monkeypatch.setenv("LLM_API_KEY", "k")
    monkeypatch.delenv("CODEX_ALLOWED_USERS", raising=False)
    monkeypatch.delenv("CODEX_LABEL_REQUIRED", raising=False)
    monkeypatch.delenv("CODEX_ALLOWED_GLOBS", raising=False)
    monkeypatch.delenv("CODEX_MAX_LINES", raising=False)
    monkeypatch.setattr(sys, "argv", ["codex_bridge.py", "--event", str(ev_path)])

    with pytest.raises(SystemExit) as exc:
        codex_bridge.main()
    assert exc.value.code == 0

    out = capsys.readouterr().out
    assert "- Allowed users: (any)" in out
    assert "- Required label: (none)" in out
    assert "docs/srs/**" in out
    assert "- Max patch lines: 500" in out
    assert ".codex/README.md" in out
