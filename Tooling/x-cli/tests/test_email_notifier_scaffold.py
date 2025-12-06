"""Email notifier scaffold tests (FGC-REQ-NOT-003)."""

from notifications.email_notifier import EmailNotifier


def test_resolves_recipients_single_and_multiple(monkeypatch):
    monkeypatch.setenv("ALERT_EMAIL", "a@example.com")
    notifier = EmailNotifier()
    assert notifier.recipients == ["a@example.com"]
    monkeypatch.setenv("ALERT_EMAIL", "a@example.com, b@example.com")
    notifier = EmailNotifier()
    assert notifier.recipients == ["a@example.com", "b@example.com"]
    monkeypatch.setenv("ALERT_EMAIL", "a@example.com; b@example.com")
    notifier = EmailNotifier()
    assert notifier.recipients == ["a@example.com", "b@example.com"]


def test_mime_construction_includes_optional_dashboard(monkeypatch):
    monkeypatch.setenv("NOTIFICATIONS_DRY_RUN", "1")
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    notifier = EmailNotifier()
    ok = notifier.send_alert("hello", {"dashboard_url": "https://dash"})
    mime = notifier._last_mime
    assert ok is True
    assert "Telemetry" in mime["Subject"]
    body = mime.get_payload(decode=True).decode()
    assert "hello" in body
    assert "https://dash" in body
    ok2 = notifier.send_alert("plain message")
    mime2 = notifier._last_mime
    assert ok2 is True
    assert "plain message" in mime2.get_payload(decode=True).decode()


def test_send_alert_requires_recipients(monkeypatch):
    monkeypatch.setenv("NOTIFICATIONS_DRY_RUN", "1")
    monkeypatch.delenv("ALERT_EMAIL", raising=False)
    notifier = EmailNotifier()
    assert notifier.send_alert("hi") is False
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    notifier = EmailNotifier()
    assert notifier.send_alert("hi") is True
