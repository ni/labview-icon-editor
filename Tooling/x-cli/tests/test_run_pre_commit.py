import json
import subprocess
import sys
from pathlib import Path

import pytest
from module_loader import load_module, resolve_path


def ensure_pre_commit() -> None:
    try:
        import pre_commit  # noqa: F401
    except Exception:  # pragma: no cover - network install
        subprocess.run([sys.executable, "-m", "pip", "install", "pre-commit"], check=True)


def test_failing_hook_records_telemetry(tmp_path: Path) -> None:
    ensure_pre_commit()
    subprocess.run(["git", "init"], cwd=tmp_path, check=True)
    (tmp_path / "sample.txt").write_text("hi", encoding="utf-8")
    subprocess.run(["git", "add", "sample.txt"], cwd=tmp_path, check=True)

    config = tmp_path / ".pre-commit-config.yaml"
    config.write_text(
        """
repos:
- repo: local
  hooks:
    - id: fail
      name: fail
      entry: bash -c 'exit 1'
      language: system
      stages: [commit]
""",
        encoding="utf-8",
    )

    script = resolve_path("run_pre_commit")
    result = subprocess.run(
        [sys.executable, str(script)], cwd=tmp_path, capture_output=True, text=True
    )
    assert result.returncode != 0

    telemetry_file = tmp_path / ".codex" / "telemetry.json"
    data = json.loads(telemetry_file.read_text(encoding="utf-8"))
    entry = data["entries"][-1]
    assert entry["source"] == "pre-commit"
    assert entry["failing_hooks"] == ["fail"]

    log_file = tmp_path / ".codex" / "pre-commit.log"
    assert "hook id: fail" in log_file.read_text(encoding="utf-8")


def test_pre_commit_invocation_failure_records_exception(
    tmp_path: Path, monkeypatch
) -> None:
    module = load_module("run_pre_commit")

    def boom(*args, **kwargs):
        raise FileNotFoundError("missing pre-commit")

    monkeypatch.setattr(module.subprocess, "run", boom)
    monkeypatch.chdir(tmp_path)
    with pytest.raises(FileNotFoundError):
        module.main()

    telemetry_file = tmp_path / ".codex" / "telemetry.json"
    data = json.loads(telemetry_file.read_text(encoding="utf-8"))
    entry = data["entries"][-1]
    assert entry["source"] == "pre-commit"
    assert entry["failing_hooks"] == []
    assert entry["exception_type"] == "FileNotFoundError"
    assert entry["exception_message"] == "missing pre-commit"

    log_file = tmp_path / ".codex" / "pre-commit.log"
    assert "missing pre-commit" in log_file.read_text(encoding="utf-8")

