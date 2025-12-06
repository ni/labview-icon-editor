import logging

from notifications.manager import NotificationManager


def _clear_env(monkeypatch):
    for var in [
        "SLACK_WEBHOOK_URL",
        "DISCORD_WEBHOOK_URL",
        "ALERT_EMAIL",
        "GITHUB_REPO",
        "GITHUB_ISSUE",
        "ADMIN_TOKEN",
        "GITHUB_TOKEN",
    ]:
        monkeypatch.delenv(var, raising=False)


def test_from_env_warns_when_no_providers(monkeypatch, caplog):
    _clear_env(monkeypatch)
    caplog.set_level(logging.WARNING)
    manager = NotificationManager.from_env()
    assert isinstance(manager, NotificationManager)
    assert len(manager._providers) == 0
    assert "No notification providers" in caplog.text


def test_notify_all_warns_when_no_providers(caplog):
    manager = NotificationManager([])
    caplog.set_level(logging.WARNING)
    assert manager.notify_all("test message") == {}
    assert "No notification providers" in caplog.text
