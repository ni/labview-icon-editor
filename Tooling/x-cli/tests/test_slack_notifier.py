import json
import urllib.request
import time

"""Slack notifier tests (FGC-REQ-NOT-002)."""

from notifications.slack_notifier import SlackNotifier


def test_slack_notifier_posts_payload(monkeypatch):
    captured = {}

    class DummyResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_urlopen(req, timeout=0):
        captured["url"] = req.full_url
        captured["data"] = req.data
        captured["headers"] = {k.lower(): v for k, v in req.headers.items()}
        captured["timeout"] = timeout
        return DummyResponse()

    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    notifier = SlackNotifier()
    result = notifier.send_alert("hello")

    assert result is True
    assert json.loads(captured["data"].decode()) == {"text": "hello"}
    assert captured["headers"]["content-type"] == "application/json"
    assert captured["timeout"] == 5


def test_slack_notifier_appends_signature(monkeypatch):
    captured = {}

    class DummyResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_urlopen(req, timeout=0):
        captured["data"] = req.data
        return DummyResponse()

    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    notifier = SlackNotifier()
    result = notifier.send_alert("hi", signature="bot")

    assert result is True
    assert json.loads(captured["data"].decode()) == {"text": "hi -- bot"}


def test_send_alert_without_env_returns_false(monkeypatch):
    monkeypatch.delenv("SLACK_WEBHOOK_URL", raising=False)
    notifier = SlackNotifier()
    assert notifier.send_alert("hi") is False


def test_slack_notifier_retries_once_on_failure(monkeypatch):
    calls = {"count": 0}

    class DummyResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_urlopen(req, timeout=0):
        calls["count"] += 1
        if calls["count"] == 1:
            raise OSError("boom")
        return DummyResponse()

    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    monkeypatch.setattr(time, "sleep", lambda s: None)

    notifier = SlackNotifier()
    result = notifier.send_alert("hello")

    assert result is True
    assert calls["count"] == 2


def test_dry_run_logs_payload(monkeypatch, capsys):
    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.setenv("NOTIFICATIONS_DRY_RUN", "1")
    notifier = SlackNotifier()
    notifier.send_alert("hello", {"dashboard_url": "http://dash"})
    out = capsys.readouterr().out.strip()
    prefix, payload = out.split(": ", 1)
    assert prefix == "DRYRUN slack"
    data = json.loads(payload)
    assert data["text"].endswith("Dashboard: http://dash")
