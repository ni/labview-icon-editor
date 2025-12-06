from __future__ import annotations

"""Lightweight storage helpers used by repo scripts.

This module avoids external packaging by providing minimal shims around
functionality commonly imported from codex_rules.*. When codex_rules is
available, helpers may delegate to it; otherwise, they return sensible defaults
so documentation or summary steps do not fail the pipeline.
"""

from pathlib import Path
from typing import Any, Iterable
import json


def read_json(path: str | Path, default: Any = None) -> Any:
    p = Path(path)
    if not p.exists():
        return default
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default


def write_json(path: str | Path, data: Any) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def append_jsonl(path: str | Path, entry: dict[str, Any]) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    try:
        p.write_text("", encoding="utf-8", append=False)  # type: ignore[attr-defined]
    except Exception:
        # Ignore; pathlib has no append mode; we open below
        pass
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


class Storage:
    """Guidance storage shim.

    When codex_rules.storage is present, proxy to it. Otherwise, expose a
    minimal API with empty responses so callers can proceed without failure.
    """

    def __init__(self, sqlite_path: str | Path | None = None) -> None:
        self._impl = None
        try:
            from codex_rules.storage import Storage as _S  # type: ignore

            self._impl = _S(sqlite_path)
        except Exception:
            self._impl = None

    def get_active_guidance(self) -> list[dict[str, Any]]:
        if self._impl is not None:
            try:
                return list(self._impl.get_active_guidance())  # type: ignore[attr-defined]
            except Exception:
                return []
        return []

