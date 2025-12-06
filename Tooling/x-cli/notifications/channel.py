"""Notification channel interface (FGC-REQ-NOT-001/002/003/004)."""

from __future__ import annotations

from typing import Dict, Optional, Protocol


class NotificationChannel(Protocol):
    """Lightweight interface for notification providers."""
    name: str

    def send_alert(self, message: str, metadata: Optional[Dict] = None) -> bool:
        """Send a notification.

        Returns True on success, False otherwise.
        """
        ...
