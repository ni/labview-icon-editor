"""Real‑time preventative guidance warnings.

This module produces warning messages that remind developers to run
component‑specific tests when touching components with active guidance rules.
"""
from __future__ import annotations

from typing import Dict, Iterable, List


def build_warnings(components: Iterable[str], guidance: List[Dict]) -> List[str]:
    """Return a list of warning strings for the touched components."""
    warnings: List[str] = []
    for comp in components:
        for rule in guidance:
            if rule["component"] == comp:
                warnings.append(
                    f"[codex-rules] Component '{comp}' touched. "
                    f"Run: {rule['command']}  (to prevent {rule['test_id']} failures)"
                )
    return warnings
