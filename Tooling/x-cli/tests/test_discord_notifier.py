"""Discord notifier tests (FGC-REQ-NOT-004)."""

import json
import urllib.request
from urllib.error import HTTPError
from io import BytesIO

from notifications.discord_notifier import DiscordNotifier


def test_import_and_dry_run_payload(monkeypatch, capsys):
    monkeypatch.setenv("NOTIFICATIONS_DRY_RUN", "1")
    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "https://example.com/webhook")
    notifier = DiscordNotifier()
    result = notifier.send_alert("hello", {"dashboard_url": "http://x"})
    assert result is True
    content = notifier._last_payload["content"]
    assert "hello" in content
    assert "Dashboard: http://x" in content
    out = capsys.readouterr().out.strip()
    prefix, payload = out.split(": ", 1)
    assert prefix == "DRYRUN discord"
    data = json.loads(payload)
    assert data["content"].endswith("Dashboard: http://x")


def test_metadata_link_appended(monkeypatch):
    monkeypatch.setenv("NOTIFICATIONS_DRY_RUN", "1")
    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "https://example.com/webhook")
    notifier = DiscordNotifier()
    notifier.send_alert("msg", {"dashboard_url": "http://dash"})
    assert notifier._last_payload["content"].endswith("Dashboard: http://dash")


def test_returns_false_without_url(monkeypatch):
    monkeypatch.delenv("DISCORD_WEBHOOK_URL", raising=False)
    notifier = DiscordNotifier()
    assert notifier.send_alert("hi") is False


def test_override_allows_network(monkeypatch):
    captured = {}

    class DummyResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_urlopen(req, timeout=0):
        captured["url"] = req.full_url
        return DummyResponse()

    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.setenv("NOTIFICATIONS_DRY_RUN", "1")
    monkeypatch.setenv("ENABLE_DISCORD_LIVE", "1")
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    notifier = DiscordNotifier()
    ok = notifier.send_alert("hi")

    assert ok is True
    assert captured["url"] == "https://example.com/webhook"


def test_real_post_invoked(monkeypatch):
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

    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.setenv("ENABLE_DISCORD_LIVE", "1")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    notifier = DiscordNotifier()
    ok = notifier.send_alert("hello")

    assert ok is True
    assert captured["url"] == "https://example.com/webhook"
    assert json.loads(captured["data"].decode()) == {"content": "hello"}
    assert captured["headers"]["content-type"] == "application/json"
    assert captured["timeout"] == 5


def test_retry_then_success(monkeypatch):
    attempts = {"count": 0}

    class DummyResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_urlopen(req, timeout=0):
        attempts["count"] += 1
        if attempts["count"] == 1:
            raise RuntimeError("boom")
        return DummyResponse()

    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.setenv("ENABLE_DISCORD_LIVE", "1")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    notifier = DiscordNotifier()
    ok = notifier.send_alert("hello")

    assert ok is True
    assert attempts["count"] == 2


def test_final_failure_logs(monkeypatch, capsys):
    def fake_urlopen(req, timeout=0):
        raise RuntimeError("boom")

    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.setenv("ENABLE_DISCORD_LIVE", "1")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    notifier = DiscordNotifier()
    ok = notifier.send_alert("hi")
    stderr = capsys.readouterr().err

    assert ok is False
    assert "DiscordNotifier:" in stderr


def test_http_error_logs_status_and_body(monkeypatch, capsys):
    def fake_urlopen(req, timeout=0):
        fp = BytesIO(b"forbidden")
        raise HTTPError(req.full_url, 403, "Forbidden", None, fp)

    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.setenv("ENABLE_DISCORD_LIVE", "1")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    notifier = DiscordNotifier()
    ok = notifier.send_alert("hi")
    stderr = capsys.readouterr().err

    assert ok is False
    assert "DiscordNotifier: HTTPError 403: forbidden" in stderr

