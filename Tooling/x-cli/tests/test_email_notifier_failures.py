"""Email notifier failure scenarios (FGC-REQ-NOT-003)."""

import smtplib

from notifications.email_notifier import EmailNotifier


def test_misconfiguration_returns_false(monkeypatch):
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setenv("SMTP_SSL", "true")
    monkeypatch.setenv("SMTP_STARTTLS", "true")

    class BoomSMTP:
        def __init__(self, *a, **k):
            raise AssertionError("should not connect")

    monkeypatch.setattr(smtplib, "SMTP", BoomSMTP)
    monkeypatch.setattr(smtplib, "SMTP_SSL", BoomSMTP)

    notifier = EmailNotifier()
    assert notifier.send_alert("x") is False


def test_connection_error_returns_false(monkeypatch):
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.delenv("SMTP_SSL", raising=False)
    monkeypatch.delenv("SMTP_STARTTLS", raising=False)

    class FailSMTP:
        def __init__(self, *a, **k):
            raise OSError("boom")

    monkeypatch.setattr(smtplib, "SMTP", FailSMTP)

    notifier = EmailNotifier()
    assert notifier.send_alert("hi") is False


def test_auth_failure_returns_false(monkeypatch):
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setenv("SMTP_USERNAME", "user")
    monkeypatch.setenv("SMTP_PASSWORD", "pass")
    monkeypatch.delenv("SMTP_SSL", raising=False)
    monkeypatch.delenv("SMTP_STARTTLS", raising=False)

    class AuthFailSMTP:
        def __init__(self, host, port, timeout):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            pass

        def login(self, *a, **k):
            raise smtplib.SMTPAuthenticationError(535, b"auth failed")

        def sendmail(self, *a, **k):
            pass

    monkeypatch.setattr(smtplib, "SMTP", AuthFailSMTP)

    notifier = EmailNotifier()
    assert notifier.send_alert("hi") is False

