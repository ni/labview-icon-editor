"""Utilities for notification helpers (FGC-REQ-NOT-001/002/003/004)."""

from __future__ import annotations

import json

from .channel import NotificationChannel


def provider_name(provider: NotificationChannel) -> str:
    """Return a canonical name for *provider*.

    If the provider defines a ``name`` attribute, it is used directly.
    Otherwise the class name is used with any trailing ``Notifier`` suffix
    removed.
    """

    name = getattr(provider, "name", None)
    if name:
        return name
    cls_name = type(provider).__name__
    if cls_name.endswith("Notifier"):
        cls_name = cls_name[:-8]
    return cls_name


def _log_dry_run(provider: NotificationChannel, payload: object) -> None:
    """Log dry-run payloads in a standardized format."""
    try:
        if hasattr(payload, "as_string"):
            content = payload.as_string()
        else:
            content = json.dumps(payload)
    except Exception:
        content = repr(payload)
    print(f"DRYRUN {provider_name(provider)}: {content}")
