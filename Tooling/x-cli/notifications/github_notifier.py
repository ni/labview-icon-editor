"""GitHub issue comment notifier (FGC-REQ-NOT-001)."""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
from typing import Dict, Optional

from .channel import NotificationChannel
from .utils import _log_dry_run


class GitHubNotifier(NotificationChannel):
    """Send alerts by posting comments to GitHub issues or pull requests."""

    name = "github"

    def __init__(
        self,
        repo: Optional[str] = None,
        issue: Optional[int] = None,
        token: Optional[str] = None,
        timeout: float = 5,
    ) -> None:
        env_issue = os.getenv("GITHUB_ISSUE") if issue is None else issue
        self.repo = repo or os.getenv("GITHUB_REPO")
        self.issue = int(env_issue) if env_issue is not None else None
        self.token = token or os.getenv("ADMIN_TOKEN") or os.getenv("GITHUB_TOKEN")
        self.timeout = timeout
        self._last_payload: Optional[dict] = None
        self._configured = bool(self.repo and self.issue is not None and self.token)
        self._warned = False

    def send_alert(
        self, message: str, metadata: Optional[Dict] = None
    ) -> bool:
        if not self._configured:
            if not self._warned:
                print(
                    "GitHubNotifier: configuration incomplete, notification skipped.",
                    file=sys.stderr,
                )
                self._warned = True
            return False

        payload = {"body": message}
        if metadata:
            url = metadata.get("dashboard_url")
            if url:
                payload["body"] = f"{payload['body']}\n\nDashboard: {url}"
        self._last_payload = payload

        dry_run = os.getenv("NOTIFICATIONS_DRY_RUN", "false").lower() in {"true", "1"}
        enable_live = os.getenv("ENABLE_GITHUB_LIVE", "false").lower() in {"true", "1"}
        if dry_run and not enable_live:
            _log_dry_run(self, payload)
            return True

        url = f"https://api.github.com/repos/{self.repo}/issues/{self.issue}/comments"
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"token {self.token}",
                "Accept": "application/vnd.github+json",
                "User-Agent": "x-cli-notifier",
            },
        )
        last_error: Optional[str] = None
        for attempt in range(2):
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    code = resp.getcode()
                    if code == 201:
                        resp.read()
                        return True
                    last_error = f"HTTP {code}"
            except Exception as e:
                last_error = f"{e.__class__.__name__}: {e}"
            if attempt == 0:
                time.sleep(1)
            else:
                if last_error:
                    print(f"GitHubNotifier: {last_error}", file=sys.stderr)
                return False
        return False
