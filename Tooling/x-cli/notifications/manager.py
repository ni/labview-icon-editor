from __future__ import annotations
"""Notification manager for multiple channels (FGC-REQ-NOT-001/002/003/004)."""

import logging
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional

from .channel import NotificationChannel
from .utils import provider_name

from .email_notifier import EmailNotifier
from .slack_notifier import SlackNotifier
from .github_notifier import GitHubNotifier
from .discord_notifier import DiscordNotifier


logger = logging.getLogger(__name__)


class NotificationManager:
    """Manage a collection of notification providers."""

    def __init__(self, providers: List[NotificationChannel]):
        self._providers = list(providers)

    @classmethod
    def from_env(cls) -> "NotificationManager":
        """Discover providers from environment settings."""
        providers: List[NotificationChannel] = []
        slack_url = os.getenv("SLACK_WEBHOOK_URL")
        if slack_url:
            providers.append(SlackNotifier(slack_url))
        discord_url = os.getenv("DISCORD_WEBHOOK_URL")
        if discord_url:
            providers.append(DiscordNotifier(discord_url))
        alert_email = os.getenv("ALERT_EMAIL")
        if alert_email:
            providers.append(EmailNotifier())
        repo = os.getenv("GITHUB_REPO")
        issue = os.getenv("GITHUB_ISSUE")
        token = os.getenv("ADMIN_TOKEN") or os.getenv("GITHUB_TOKEN")
        if repo and issue and token:
            try:
                issue_num = int(issue)
            except ValueError:
                issue_num = None
            if issue_num is not None:
                providers.append(GitHubNotifier(repo, issue_num, token))
        if not providers:
            logger.warning("No notification providers configured via environment variables.")
        return cls(providers)

    def notify_all(self, message: str, metadata: Optional[Dict] = None) -> Dict[str, bool]:
        """Send a notification via all providers.

        Notifications are dispatched concurrently to avoid cumulative
        network delays. Each provider's result is recorded independently,
        and failures are isolated per channel. The method blocks until all
        providers have completed.

        Returns a mapping of provider name to success boolean.
        """
        results: Dict[str, bool] = {}
        if not self._providers:
            logger.warning("No notification providers configured; skipping notifications.")
            return results

        def worker(provider: NotificationChannel) -> bool:
            name = provider_name(provider)
            try:
                return bool(provider.send_alert(message, metadata))
            except Exception as exc:
                print(f"{name} notifier failed: {exc}", file=sys.stderr)
                return False

        with ThreadPoolExecutor() as executor:
            future_to_name = {
                executor.submit(worker, provider): provider_name(provider)
                for provider in self._providers
            }
            for future in as_completed(future_to_name):
                name = future_to_name[future]
                try:
                    results[name] = future.result()
                except Exception as exc:  # pragma: no cover
                    print(f"{name} notifier failed: {exc}", file=sys.stderr)
                    results[name] = False

        return results
