"""Telemetry dashboard rendering tests (FGC-REQ-TEL-001)."""

import json
import os
import subprocess
from pathlib import Path

from module_loader import load_module, resolve_path

# Requirement ID included in generated dashboard
SRS_ID = "FGC-REQ-TEL-001"

render_telemetry_dashboard = load_module("render_telemetry_dashboard")


def write_history(tmp_path: Path, records):
    history = tmp_path / "telemetry-summary-history.jsonl"
    with history.open("w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
    return history


def write_srs_history(tmp_path: Path, counts):
    summary = tmp_path / "srs-telemetry-summary.json"
    history = summary.with_name("srs-telemetry-summary-history.jsonl")
    entries = []
    for i, c in enumerate(counts, start=1):
        entry = {
            "timestamp": f"2024-01-0{i}T00:00:00Z",
            "srs_omitted_count": c,
            "total_entries": 1,
            "srs_omission_rate": float(c),
        }
        entries.append(entry)
    summary.write_text(json.dumps(entries[-1]), encoding="utf-8")
    with history.open("w", encoding="utf-8") as f:
        for e in entries:
            f.write(json.dumps(e) + "\n")
    return summary


def run_dashboard(tmp_path: Path, records, env=None, srs_counts=None):
    history = write_history(tmp_path, records)
    srs_arg = []
    if srs_counts is not None:
        srs_summary = write_srs_history(tmp_path, srs_counts)
        srs_arg = ["--srs-summary", str(srs_summary)]
    script = resolve_path("render_telemetry_dashboard")
    full_env = os.environ.copy()
    if env:
        full_env.update(env)
    result = subprocess.run(
        ["python", str(script), str(history)] + srs_arg,
        capture_output=True,
        text=True,
        env=full_env,
    )
    return result, history.with_name("telemetry-dashboard.html")


def run_dashboard_inproc(tmp_path: Path, records, argv=None, srs_counts=None):
    history = write_history(tmp_path, records)
    args = [str(history)] + (argv or [])
    if srs_counts is not None:
        srs_summary = write_srs_history(tmp_path, srs_counts)
        args.extend(["--srs-summary", str(srs_summary)])
    exit_code = render_telemetry_dashboard.main(args)
    return exit_code, history.with_name("telemetry-dashboard.html")


def test_dashboard_html_created(tmp_path):
    records = [
        {
            "timestamp": "2024-01-01T00:00:00Z",
            "slow_test_count": 1,
            "dependency_failures": {},
        },
    ]
    result, html_path = run_dashboard(
        tmp_path, records, env={"SRS_IDS": SRS_ID}
    )
    assert result.returncode == 0
    assert html_path.is_file()
    assert SRS_ID in html_path.read_text()


def test_regression_flags(tmp_path):
    records = [
        {
            "timestamp": "2024-01-01T00:00:00Z",
            "slow_test_count": 1,
            "dependency_failures": {},
        },
        {
            "timestamp": "2024-01-02T00:00:00Z",
            "slow_test_count": 3,
            "dependency_failures": {"git": 1},
        },
    ]
    result, html_path = run_dashboard(tmp_path, records)
    assert result.returncode == 1
    assert "Slow test count increased" in result.stderr
    assert html_path.is_file()


def test_srs_omission_render(tmp_path):
    records = [
        {
            "timestamp": "2024-01-01T00:00:00Z",
            "slow_test_count": 0,
            "dependency_failures": {},
        },
        {
            "timestamp": "2024-01-02T00:00:00Z",
            "slow_test_count": 0,
            "dependency_failures": {},
        },
    ]
    result, html_path = run_dashboard(tmp_path, records, srs_counts=[1, 1])
    assert result.returncode == 0
    html = html_path.read_text()
    assert "Current SRS omissions: 1" in html
    assert "<canvas id='srsOmissions'></canvas>" in html


def test_srs_omission_warning(tmp_path):
    records = [
        {
            "timestamp": "2024-01-01T00:00:00Z",
            "slow_test_count": 0,
            "dependency_failures": {},
        },
        {
            "timestamp": "2024-01-02T00:00:00Z",
            "slow_test_count": 0,
            "dependency_failures": {},
        },
    ]
    result, _ = run_dashboard(tmp_path, records, srs_counts=[1, 3])
    assert result.returncode == 1
    assert "SRS omission count increased" in result.stderr


def test_srs_summary_load_failure(tmp_path):
    records = [
        {
            "timestamp": "2024-01-01T00:00:00Z",
            "slow_test_count": 0,
            "dependency_failures": {},
        }
    ]
    history = write_history(tmp_path, records)
    bad_summary = tmp_path / "srs-telemetry-summary.json"
    bad_summary.write_text("{", encoding="utf-8")
    script = resolve_path("render_telemetry_dashboard")
    result = subprocess.run(
        ["python", str(script), str(history), "--srs-summary", str(bad_summary)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "Failed to load SRS summary" in result.stderr
    html_path = history.with_name("telemetry-dashboard.html")
    assert html_path.is_file()
    html = html_path.read_text()
    assert "<canvas id='srsOmissions'></canvas>" not in html


def test_slack_alert(monkeypatch, tmp_path):
    records = [
        {"timestamp": "2024-01-01T00:00:00Z", "slow_test_count": 1, "dependency_failures": {}},
        {
            "timestamp": "2024-01-02T00:00:00Z",
            "slow_test_count": 2,
            "dependency_failures": {},
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
        "TELEMETRY_DASHBOARD_URL", "https://example.com/telemetry-dashboard.html"
    )
    monkeypatch.setattr(
        render_telemetry_dashboard.NotificationManager,
        "from_env",
        staticmethod(fake_from_env),
    )
    exit_code, html_path = run_dashboard_inproc(tmp_path, records)
    assert exit_code == 1
    assert html_path.is_file()
    assert captured["called"]
    assert "Telemetry regression detected" in captured["message"]
    assert captured["metadata"] == {
        "dashboard_url": "https://example.com/telemetry-dashboard.html"
    }


def test_email_alert(monkeypatch, tmp_path):
    records = [
        {"timestamp": "2024-01-01T00:00:00Z", "slow_test_count": 0, "dependency_failures": {}},
        {
            "timestamp": "2024-01-02T00:00:00Z",
            "slow_test_count": 1,
            "dependency_failures": {},
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

    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.setenv(
        "TELEMETRY_DASHBOARD_URL", "https://example.com/telemetry-dashboard.html"
    )
    monkeypatch.setattr(
        render_telemetry_dashboard.NotificationManager,
        "from_env",
        staticmethod(fake_from_env),
    )
    exit_code, _ = run_dashboard_inproc(tmp_path, records)
    assert exit_code == 1
    assert captured["called"]
    assert "Telemetry regression detected" in captured["message"]
    assert captured["metadata"] == {
        "dashboard_url": "https://example.com/telemetry-dashboard.html"
    }

