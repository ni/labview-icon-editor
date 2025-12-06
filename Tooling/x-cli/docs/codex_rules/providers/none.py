"""No‑op provider.

When provider.type == 'none' in the configuration, the rules engine will not
attempt to post comments or interact with any external service.
"""
from __future__ import annotations


def post_comment(*args, **kwargs) -> None:
    """Stub implementation that does nothing."""
    return None
