import json
import os
from pathlib import Path
from typing import Any, Dict, Iterable, Optional


def _repo_root() -> Path:
    here = Path(__file__).resolve()
    # scripts/lib/telemetry.py -> scripts/lib -> scripts -> repo
    return here.parent.parent.parent


def _ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def record_telemetry_entry(
    payload: Dict[str, Any],
    *,
    command: Optional[Iterable[str]] = None,
    exit_status: Optional[int] = None,
    srs_ids: Optional[Iterable[str]] = None,
    **extras: Any,
) -> None:
    """Append a line-JSON telemetry entry to artifacts/qa-telemetry.jsonl.

    The function is resilient: it ignores all errors so callers are never blocked
    by telemetry persistence issues.
    """
    try:
        root = _repo_root()
        out_path = root / "artifacts" / "qa-telemetry.jsonl"
        _ensure_parent(out_path)

        entry: Dict[str, Any] = dict(payload or {})
        if command is not None:
            entry.setdefault("command", list(command))
        if exit_status is not None:
            entry.setdefault("exit_status", int(exit_status))
        if srs_ids is not None:
            entry.setdefault("srs_ids", list(srs_ids))
        if extras:
            for k, v in extras.items():
                if k not in entry:
                    entry[k] = v

        with out_path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        # Best-effort; never raise
        return

