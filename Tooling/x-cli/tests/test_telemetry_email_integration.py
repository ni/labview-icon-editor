"""Telemetry email integration tests (FGC-REQ-TEL-001/FGC-REQ-NOT-003)."""

import json
import os
from pathlib import Path

import scripts.render_telemetry_dashboard as rtd
from notifications.email_notifier import EmailNotifier


def write_history(tmp_path: Path, records):
    path = tmp_path / "telemetry-summary-history.jsonl"
    with path.open("w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
    return path

def test_email_notifier_invoked_on_regression(monkeypatch, tmp_path):
    history = write_history(
        tmp_path,
        [
            {"timestamp": "t1", "slow_test_count": 1, "dependency_failures": {}},
            {"timestamp": "t2", "slow_test_count": 2, "dependency_failures": {}},
        ],
    )

    called: dict[str, object] = {}

    def fake_send(self, message, metadata=None):
        called["message"] = message
        called["metadata"] = metadata
        return True

    monkeypatch.setattr(EmailNotifier, "send_alert", fake_send)
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.setenv("TELEMETRY_DASHBOARD_URL", "https://example.com/dash")
    exit_code = rtd.main([str(history)])
    assert exit_code == 1
    assert "Telemetry regression detected" in called["message"]
    assert called["metadata"] == {"dashboard_url": "https://example.com/dash"}
