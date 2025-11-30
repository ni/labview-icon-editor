"""Notification manager multi-channel tests (FGC-REQ-NOT-001/002/003/004)."""

import threading

from notifications.channel import NotificationChannel
from notifications.manager import NotificationManager
from notifications.slack_notifier import SlackNotifier
from notifications.discord_notifier import DiscordNotifier
from notifications.email_notifier import EmailNotifier
from notifications.github_notifier import GitHubNotifier


def _setup_env(monkeypatch):
    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://slack.example/webhook")
    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "https://discord.example/webhook")
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    monkeypatch.setenv("GITHUB_REPO", "octo/repo")
    monkeypatch.setenv("GITHUB_ISSUE", "42")
    monkeypatch.setenv("ADMIN_TOKEN", "tok")
    monkeypatch.setenv("NOTIFICATIONS_DRY_RUN", "1")


def test_from_env_discovers_all_channels(monkeypatch):
    _setup_env(monkeypatch)
    manager = NotificationManager.from_env()
    types = {type(p) for p in manager._providers}
    assert SlackNotifier in types
    assert DiscordNotifier in types
    assert EmailNotifier in types
    assert GitHubNotifier in types


def test_notify_all_reports_all_channels(monkeypatch):
    _setup_env(monkeypatch)
    manager = NotificationManager.from_env()
    results = manager.notify_all("hello")
    assert "slack" in results
    assert "discord" in results
    assert "email" in results
    assert "github" in results


def test_notify_all_waits_for_providers():
    started = threading.Event()
    release = threading.Event()
    results = {}

    class SlowNotifier(NotificationChannel):
        name = "slow"

        def send_alert(self, message: str, metadata):
            started.set()
            release.wait(timeout=1)
            return True

    manager = NotificationManager([SlowNotifier()])

    def run():
        results.update(manager.notify_all("hi"))

    thread = threading.Thread(target=run)
    thread.start()

    started.wait()
    assert thread.is_alive()

    release.set()
    thread.join(timeout=1)

    assert results["slow"]


def test_notify_all_partial_failure():
    class Good(NotificationChannel):
        name = "good"

        def send_alert(self, message: str, metadata):
            return True

    class Bad(NotificationChannel):
        name = "bad"

        def send_alert(self, message: str, metadata):
            raise RuntimeError("boom")

    manager = NotificationManager([Good(), Bad()])
    results = manager.notify_all("hi")
    assert results == {"good": True, "bad": False}


def test_notify_all_defaults_to_class_name():
    class SampleNotifier(NotificationChannel):
        def send_alert(self, message: str, metadata=None):
            return True

    manager = NotificationManager([SampleNotifier()])
    results = manager.notify_all("hi")
    assert results == {"Sample": True}
