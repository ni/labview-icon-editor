"""Tests for SRS telemetry analyzer (FGC-REQ-TEL-001)."""

import json
import os
import subprocess
from pathlib import Path

import pytest

from module_loader import resolve_path


def run_script(tmp_path: Path, entries, env=None):
    telemetry = tmp_path / ".codex" / "telemetry.json"
    telemetry.parent.mkdir(parents=True, exist_ok=True)
    telemetry.write_text(json.dumps({"entries": entries}), encoding="utf-8")

    full_env = os.environ.copy()
    full_env["SRS_IDS"] = "FGC-REQ-TEL-001"
    if env:
        full_env.update(env)
    script = resolve_path("analyze_srs_telemetry")
    return subprocess.run(
        ["python", str(script), str(telemetry)],
        capture_output=True,
        text=True,
        env=full_env,
        cwd=tmp_path,
    )


def test_omission_rate_threshold(tmp_path):
    entries = [{"srs_omitted": True}, {"srs_omitted": False}]
    result = run_script(tmp_path, entries, env={"MAX_SRS_OMISSION_RATE": "0.3"})
    assert result.returncode == 1
    assert "::warning::" in result.stderr


def test_summary_file_contains_counts(tmp_path):
    entries = [
        {"srs_omitted": True},
        {"srs_omitted": False},
        {"srs_omitted": True},
    ]
    result = run_script(tmp_path, entries, env={"MAX_SRS_OMISSION_RATE": "1"})
    assert result.returncode == 0
    summary_path = tmp_path / "artifacts" / "srs-telemetry-summary.json"
    assert summary_path.is_file()
    summary = json.loads(summary_path.read_text())
    assert summary["srs_ids"] == ["FGC-REQ-TEL-001"]
    assert summary["total_entries"] == 3
    assert summary["srs_omitted_count"] == 2
    assert summary["srs_omission_rate"] == pytest.approx(2 / 3)


def test_history_rolls(tmp_path):
    entries = [{"srs_omitted": False}]
    for _ in range(25):
        run_script(tmp_path, entries, env={"MAX_SRS_OMISSION_RATE": "1"})
    history_path = tmp_path / "artifacts" / "srs-telemetry-summary-history.jsonl"
    assert history_path.is_file()
    lines = history_path.read_text().strip().splitlines()
    assert len(lines) == 20
    record = json.loads(lines[-1])
    assert record["srs_omission_rate"] == 0
    assert "timestamp" in record

