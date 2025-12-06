"""Tests for QA telemetry analyzer (FGC-REQ-TEL-001)."""

import json
import os
import subprocess
from pathlib import Path

from module_loader import resolve_path


def run_script(tmp_path: Path, entries, env=None):
    telemetry = tmp_path / "qa-telemetry.jsonl"
    with telemetry.open("w", encoding="utf-8") as f:
        for e in entries:
            f.write(json.dumps(e) + "\n")
    full_env = os.environ.copy()
    if env:
        full_env.update(env)
    script = resolve_path("analyze_qa_telemetry")
    return subprocess.run(
        ["python", str(script), str(telemetry)],
        capture_output=True,
        text=True,
        env=full_env,
    )


def test_failure_threshold(tmp_path):
    entries = [
        {"step": "build", "duration_ms": 1, "status": "fail", "start": 0, "end": 1},
        {"step": "test", "duration_ms": 1, "status": "pass", "start": 0, "end": 1},
    ]
    result = run_script(tmp_path, entries, env={"MAX_QA_FAILURES": "0"})
    assert result.returncode == 1
    assert "Step build failed" in result.stderr


def test_summary_and_history(tmp_path):
    entries = [
        {"step": "build", "duration_ms": 1, "status": "fail", "start": 0, "end": 1},
        {"step": "test", "duration_ms": 2, "status": "pass", "start": 0, "end": 2},
    ]
    result = run_script(tmp_path, entries, env={"MAX_QA_FAILURES": "1"})
    assert result.returncode == 0
    summary_path = tmp_path / "qa-telemetry-summary.json"
    assert summary_path.is_file()
    summary = json.loads(summary_path.read_text())
    assert summary["failure_counts"]["build"] == 1
    history_path = tmp_path / "qa-telemetry-summary-history.jsonl"
    assert history_path.is_file()
    lines = history_path.read_text().strip().splitlines()
    assert len(lines) == 1
    record = json.loads(lines[0])
    assert record["step_averages"]


def test_appends_to_archive(tmp_path):
    entries = [
        {"step": "build", "duration_ms": 1, "status": "pass", "start": 0, "end": 1}
    ]
    archive = tmp_path / "archive.jsonl"
    result = run_script(
        tmp_path,
        entries,
        env={"QA_TELEMETRY_ARCHIVE": str(archive)},
    )
    assert result.returncode == 0
    assert archive.is_file()
    lines = archive.read_text().strip().splitlines()
    assert len(lines) == 1
    record = json.loads(lines[0])
    assert record["step_averages"]
