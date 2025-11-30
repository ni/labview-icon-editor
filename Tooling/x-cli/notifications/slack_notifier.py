"""Slack notification provider (FGC-REQ-NOT-002)."""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
from typing import Dict, Optional

from .channel import NotificationChannel
from .utils import _log_dry_run


class SlackNotifier(NotificationChannel):
    """Send notifications to Slack via incoming webhook."""
    name = "slack"

    def __init__(self, webhook_url: Optional[str] = None):
        self.webhook_url = webhook_url or os.getenv("SLACK_WEBHOOK_URL")
        self._last_payload: Optional[dict] = None

    def _build_payload(self, message: str, signature: Optional[str] = None) -> dict:
        """Construct the JSON payload for Slack."""
        text = f"{message} -- {signature}" if signature else message
        return {"text": text}

    def send_alert(
        self,
        message: str,
        metadata: Optional[Dict] = None,
        signature: Optional[str] = None,
    ) -> bool:
        if not self.webhook_url:
            return False

        payload = self._build_payload(message, signature)
        if metadata:
            url = metadata.get("dashboard_url")
            if url:
                payload["text"] = f"{payload['text']}\n\nDashboard: {url}"
        self._last_payload = payload

        dry_run = os.getenv("NOTIFICATIONS_DRY_RUN", "false").lower() in {"true", "1"}
        enable_live = os.getenv("ENABLE_SLACK_LIVE", "false").lower() in {"true", "1"}
        if dry_run and not enable_live:
            _log_dry_run(self, payload)
            return True

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            self.webhook_url,
            data=data,
            headers={"Content-Type": "application/json"},
        )
        for attempt in range(2):
            try:
                with urllib.request.urlopen(req, timeout=5):
                    pass
                return True
            except Exception as e:
                if attempt == 0:
                    time.sleep(1)
                else:
                    print(
                        f"SlackNotifier: {e.__class__.__name__}: {e}",
                        file=sys.stderr,
                    )
                    return False
        return False
