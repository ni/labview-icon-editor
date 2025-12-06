"""Discord notification provider (FGC-REQ-NOT-004)."""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
import urllib.error
from typing import Dict, Optional

from .channel import NotificationChannel
from .utils import _log_dry_run


class DiscordNotifier(NotificationChannel):
    """Send notifications to Discord via webhook."""
    name = "discord"

    def __init__(self, webhook_url: Optional[str] = None):
        self.webhook_url = webhook_url or os.getenv("DISCORD_WEBHOOK_URL")
        self._last_payload: Optional[dict] = None

    def send_alert(self, message: str, metadata: Optional[Dict] = None) -> bool:
        if not self.webhook_url:
            return False

        content = message
        dashboard_url = (metadata or {}).get("dashboard_url")
        if dashboard_url:
            content += f"\n\nDashboard: {dashboard_url}"
        payload = {"content": content}
        self._last_payload = payload

        dry_run = os.getenv("NOTIFICATIONS_DRY_RUN", "false").lower() in {"true", "1"}
        enable_live = os.getenv("ENABLE_DISCORD_LIVE", "false").lower() in {"true", "1"}
        if dry_run and not enable_live:
            _log_dry_run(self, payload)
            return True

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            self.webhook_url,
            data=data,
            headers={"Content-Type": "application/json"},
        )
        exc: Optional[Exception] = None
        for attempt in range(2):
            try:
                with urllib.request.urlopen(req, timeout=5):
                    pass
                return True
            except Exception as e:
                exc = e
                if attempt == 0:
                    time.sleep(1)
                else:
                    if isinstance(e, urllib.error.HTTPError):
                        body = e.read().decode("utf-8", errors="replace")
                        print(
                            f"DiscordNotifier: HTTPError {e.code}: {body}",
                            file=sys.stderr,
                        )
                    else:
                        print(
                            f"DiscordNotifier: {e.__class__.__name__}: {e}",
                            file=sys.stderr,
                        )
                    return False
        if exc is not None:
            print(
                f"DiscordNotifier: {exc.__class__.__name__}: {exc}", file=sys.stderr
            )
        return False
