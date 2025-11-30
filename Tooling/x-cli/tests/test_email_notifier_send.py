"""Email notifier send tests (FGC-REQ-NOT-003)."""

import smtplib

from notifications.email_notifier import EmailNotifier

recorder = {}


class RecorderSMTP:
    def __init__(self, host, port, timeout, **kwargs):
        self.host = host
        self.port = port
        self.timeout = timeout
        self.starttls_called = False
        self.login_called = False
        self.sendmail_args = None
        recorder['instance'] = self

    def starttls(self, context):
        self.starttls_called = True

    def login(self, username, password):
        self.login_called = True
        self.username = username
        self.password = password

    def sendmail(self, sender, recipients, msg):
        self.sendmail_args = (sender, recipients, msg)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        pass


def test_dry_run_when_flag_set(monkeypatch, capsys):
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.setenv("NOTIFICATIONS_DRY_RUN", "1")
    called = {}

    class BoomSMTP:
        def __init__(self, *a, **k):
            called["called"] = True
            raise AssertionError("should not connect in dry-run")

    monkeypatch.setattr(smtplib, "SMTP", BoomSMTP)
    monkeypatch.setattr(smtplib, "SMTP_SSL", BoomSMTP)
    notifier = EmailNotifier()
    assert notifier.send_alert("hello") is True
    assert "called" not in called
    out = capsys.readouterr().out
    assert "DRYRUN email" in out
    assert "Telemetry Regression" in out


def test_plaintext_send_with_login(monkeypatch):
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setenv("SMTP_USERNAME", "user")
    monkeypatch.setenv("SMTP_PASSWORD", "pass")
    monkeypatch.delenv("SMTP_STARTTLS", raising=False)
    monkeypatch.delenv("SMTP_SSL", raising=False)
    recorder.clear()
    monkeypatch.setattr(smtplib, "SMTP", RecorderSMTP)
    notifier = EmailNotifier()
    assert notifier.send_alert("hi") is True
    inst = recorder["instance"]
    assert inst.starttls_called is False
    assert inst.login_called is True
    assert inst.sendmail_args[0] == notifier.sender


def test_plaintext_send_without_login(monkeypatch):
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.delenv("SMTP_USERNAME", raising=False)
    monkeypatch.delenv("SMTP_PASSWORD", raising=False)
    monkeypatch.delenv("SMTP_STARTTLS", raising=False)
    monkeypatch.delenv("SMTP_SSL", raising=False)
    recorder.clear()
    monkeypatch.setattr(smtplib, "SMTP", RecorderSMTP)
    notifier = EmailNotifier()
    assert notifier.send_alert("hi") is True
    inst = recorder["instance"]
    assert inst.login_called is False


def test_starttls_path(monkeypatch):
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setenv("SMTP_STARTTLS", "true")
    monkeypatch.delenv("SMTP_SSL", raising=False)
    monkeypatch.delenv("SMTP_USERNAME", raising=False)
    monkeypatch.delenv("SMTP_PASSWORD", raising=False)
    recorder.clear()
    monkeypatch.setattr(smtplib, "SMTP", RecorderSMTP)
    notifier = EmailNotifier()
    assert notifier.send_alert("hello") is True
    inst = recorder["instance"]
    assert inst.starttls_called is True


def test_ssl_path(monkeypatch):
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setenv("SMTP_SSL", "true")
    monkeypatch.delenv("SMTP_STARTTLS", raising=False)
    recorder.clear()
    monkeypatch.setattr(smtplib, "SMTP_SSL", RecorderSMTP)
    notifier = EmailNotifier()
    assert notifier.send_alert("hello") is True
    inst = recorder["instance"]
    assert inst.starttls_called is False
