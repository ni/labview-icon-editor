"""Email notification provider (FGC-REQ-NOT-003)."""

from __future__ import annotations

import os
import re
import smtplib
import socket
import ssl
import sys
from email.mime.text import MIMEText
from typing import Dict, List, Optional

from .channel import NotificationChannel
from .utils import _log_dry_run


class EmailNotifier(NotificationChannel):
    """Prepare email alerts without sending them."""
    name = "email"

    def __init__(
        self,
        recipients: Optional[List[str]] = None,
        host: Optional[str] = None,
        port: Optional[int] = None,
        use_starttls: Optional[bool] = None,
        use_ssl: Optional[bool] = None,
        username: Optional[str] = None,
        password: Optional[str] = None,
        timeout: Optional[int] = None,
        sender: Optional[str] = None,
    ):
        env = os.getenv
        self.recipients = recipients or [
            r.strip()
            for r in re.split(r"[;,]", env("ALERT_EMAIL", ""))
            if r.strip()
        ]
        self.host = host or env("SMTP_HOST", "127.0.0.1")
        self.port = int(port or env("SMTP_PORT", "25"))
        self.use_starttls = (
            use_starttls
            if use_starttls is not None
            else env("SMTP_STARTTLS", "false").lower() == "true"
        )
        self.use_ssl = (
            use_ssl
            if use_ssl is not None
            else env("SMTP_SSL", "false").lower() == "true"
        )
        self.username = username or env("SMTP_USERNAME")
        self.password = password or env("SMTP_PASSWORD")
        self.timeout = int(timeout or env("SMTP_TIMEOUT_SEC", "5"))
        self.sender = sender or env("EMAIL_FROM", "ci@x-cli.local")
        self._last_mime: Optional[MIMEText] = None

    def send_alert(self, message: str, metadata: Optional[Dict] = None) -> bool:
        dry_run = os.getenv("NOTIFICATIONS_DRY_RUN", "false").lower() in {"true", "1"}
        enable_live = os.getenv("ENABLE_EMAIL_LIVE", "false").lower() in {"true", "1"}
        if not self.recipients:
            return False
        if self.use_starttls and self.use_ssl:
            print(
                "EmailNotifier: both SMTP_SSL and SMTP_STARTTLS enabled",
                file=sys.stderr,
            )
            return False

        body = message
        if metadata:
            url = metadata.get("dashboard_url")
            if url:
                body = f"{body}\n\nDashboard: {url}"
        mime = MIMEText(body, "plain", "utf-8")
        mime["Subject"] = "Telemetry Regression"
        mime["From"] = self.sender
        mime["To"] = ", ".join(self.recipients)
        self._last_mime = mime

        if dry_run and not enable_live:
            _log_dry_run(self, mime)
            return True

        context = ssl.create_default_context()
        try:
            if self.use_ssl:
                with smtplib.SMTP_SSL(
                    self.host,
                    self.port,
                    timeout=self.timeout,
                    context=context,
                ) as client:
                    if self.username and self.password:
                        client.login(self.username, self.password)
                    client.sendmail(self.sender, self.recipients, mime.as_string())
            else:
                with smtplib.SMTP(self.host, self.port, timeout=self.timeout) as client:
                    if self.use_starttls:
                        client.starttls(context=context)
                    if self.username and self.password:
                        client.login(self.username, self.password)
                    client.sendmail(self.sender, self.recipients, mime.as_string())
            return True
        except (smtplib.SMTPException, OSError, socket.timeout) as e:
            print(f"EmailNotifier: {e.__class__.__name__}: {e}", file=sys.stderr)
            return False
