"""QA telemetry dashboard tests (FGC-REQ-TEL-001)."""

import json
import os
import subprocess
from pathlib import Path

from module_loader import load_module, resolve_path

render_qa_dashboard = load_module("render_qa_telemetry_dashboard")


def write_history(tmp_path: Path, records):
    history = tmp_path / "qa-telemetry-summary-history.jsonl"
    with history.open("w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
    return history


def run_dashboard(tmp_path: Path, records):
    history = write_history(tmp_path, records)
    script = resolve_path("render_qa_telemetry_dashboard")
    env = os.environ.copy()
    env["SRS_IDS"] = "FGC-REQ-TEL-001"
    result = subprocess.run(
        ["python", str(script), str(history)],
        capture_output=True,
        text=True,
        env=env,
    )
    return result, history.with_name("qa-telemetry-dashboard.html")


def run_dashboard_inproc(tmp_path: Path, records, argv=None):
    history = write_history(tmp_path, records)
    os.environ["SRS_IDS"] = "FGC-REQ-TEL-001"
    exit_code = render_qa_dashboard.main([str(history)] + (argv or []))
    return exit_code, history.with_name("qa-telemetry-dashboard.html")


def test_dashboard_html_created(tmp_path):
    records = [
        {
            "timestamp": "2024-01-01T00:00:00Z",
            "step_averages": [{"step": "build", "avg_duration_ms": 1}],
            "failure_counts": {},
        }
    ]
    result, html_path = run_dashboard(tmp_path, records)
    assert result.returncode == 0
    assert html_path.is_file()


def test_recurring_failure_flags(tmp_path):
    records = [
        {
            "timestamp": "2024-01-01T00:00:00Z",
            "step_averages": [{"step": "build", "avg_duration_ms": 1}],
            "failure_counts": {"build": 1},
        },
        {
            "timestamp": "2024-01-02T00:00:00Z",
            "step_averages": [{"step": "build", "avg_duration_ms": 2}],
            "failure_counts": {"build": 2},
        },
    ]
    result, html_path = run_dashboard(tmp_path, records)
    assert result.returncode == 1
    assert "Recurring failures" in result.stderr
    assert html_path.is_file()


def test_slack_alert(monkeypatch, tmp_path):
    records = [
        {
            "timestamp": "2024-01-01T00:00:00Z",
            "step_averages": [{"step": "build", "avg_duration_ms": 1}],
            "failure_counts": {"build": 1},
        },
        {
            "timestamp": "2024-01-02T00:00:00Z",
            "step_averages": [{"step": "build", "avg_duration_ms": 1}],
            "failure_counts": {"build": 1},
        },
    ]
    captured: dict[str, str] = {}

    class DummyManager:
        def notify_all(self, message, metadata=None):
            captured["message"] = message
            captured["metadata"] = metadata
            return {}

    def fake_from_env():
        captured["called"] = True
        return DummyManager()

    monkeypatch.setenv("SLACK_WEBHOOK_URL", "http://example.com/hook")
    monkeypatch.setenv(
        "QA_TELEMETRY_DASHBOARD_URL",
        "https://example.com/qa-telemetry-dashboard.html",
    )
    monkeypatch.setattr(
        render_qa_dashboard.NotificationManager,
        "from_env",
        staticmethod(fake_from_env),
    )
    exit_code, html_path = run_dashboard_inproc(tmp_path, records)
    assert exit_code == 1
    assert html_path.is_file()
    assert captured["called"]
    assert "QA telemetry regression detected" in captured["message"]
    assert captured["metadata"] == {
        "dashboard_url": "https://example.com/qa-telemetry-dashboard.html",
        "srs_ids": ["FGC-REQ-TEL-001"],
    }
