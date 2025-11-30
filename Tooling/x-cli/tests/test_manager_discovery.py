"""Notification manager discovery (FGC-REQ-NOT-001/002/003/004)."""

from notifications.manager import NotificationManager
from notifications.slack_notifier import SlackNotifier
from notifications.email_notifier import EmailNotifier
from notifications.github_notifier import GitHubNotifier
from notifications.discord_notifier import DiscordNotifier
from notifications.utils import provider_name


def test_from_env_discovers_slack(monkeypatch):
    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://example.com/webhook")
    manager = NotificationManager.from_env()
    assert len(manager._providers) == 1
    provider = manager._providers[0]
    assert isinstance(provider, SlackNotifier)
    assert provider.webhook_url == "https://example.com/webhook"


def test_from_env_discovers_email_and_slack(monkeypatch):
    monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://example.com/webhook")
    monkeypatch.setenv("ALERT_EMAIL", "dev@example.com")
    manager = NotificationManager.from_env()
    assert len(manager._providers) == 2
    assert isinstance(manager._providers[0], SlackNotifier)
    assert isinstance(manager._providers[1], EmailNotifier)


def test_from_env_discovers_github(monkeypatch):
    monkeypatch.setenv("GITHUB_REPO", "octo/repo")
    monkeypatch.setenv("GITHUB_ISSUE", "5")
    monkeypatch.setenv("ADMIN_TOKEN", "tok")
    manager = NotificationManager.from_env()
    providers = manager._providers
    assert any(isinstance(p, GitHubNotifier) for p in providers)
    gh = [p for p in providers if isinstance(p, GitHubNotifier)][0]
    assert gh.repo == "octo/repo"
    assert gh.issue == 5


def test_discovers_discord_from_env(monkeypatch):
    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "dummy")
    manager = NotificationManager.from_env()
    providers = manager._providers
    assert any(isinstance(p, DiscordNotifier) for p in providers)


def test_discovery_order(monkeypatch):
    monkeypatch.setenv("SLACK_WEBHOOK_URL", "s")
    monkeypatch.setenv("DISCORD_WEBHOOK_URL", "d")
    monkeypatch.setenv("ALERT_EMAIL", "a@example.com")
    monkeypatch.setenv("GITHUB_REPO", "o/r")
    monkeypatch.setenv("GITHUB_ISSUE", "1")
    monkeypatch.setenv("ADMIN_TOKEN", "t")
    manager = NotificationManager.from_env()
    names = [provider_name(p) for p in manager._providers]
    assert names == ["slack", "discord", "email", "github"]
