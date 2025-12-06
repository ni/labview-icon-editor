#!/usr/bin/env python3
"""Augment telemetry/summary.json with human-friendly fields for key metrics.

Adds sibling "*_human" fields for a few high‑value numeric metrics without
altering the original values:
 - "*_seconds" → "*_human" as "<value>s" (1–2 decimals)
 - "*_bytes"   → "*_human" as SI size (kB/MB/GB)

Also specifically sets "duration_human" for top‑level "duration_seconds".

The script is idempotent and safe to re-run. It recurses into nested dicts and
lists to cover common summary layouts (e.g., by_* maps).
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def _fmt_seconds(val: float) -> str:
    return f"{float(val):0.0#}s"


def _fmt_bytes(val: float) -> str:
    # SI (decimal) units for simplicity/readability
    units = ["B", "kB", "MB", "GB", "TB"]
    size = float(val)
    idx = 0
    while size >= 1000.0 and idx < len(units) - 1:
        size /= 1000.0
        idx += 1
    # Keep 1–2 decimals for non-bytes
    if idx == 0:
        return f"{int(size)}{units[idx]}"
    return f"{size:0.0#}{units[idx]}"


def _augment(obj: Any) -> None:
    if isinstance(obj, dict):
        # Collect updates to avoid modifying while iterating
        updates: dict[str, Any] = {}
        for k, v in obj.items():
            # Recurse first
            _augment(v)
            # Seconds → human
            if k.endswith("_seconds") and isinstance(v, (int, float)):
                human_key = k[:-8] + "_human"
                updates[human_key] = _fmt_seconds(float(v))
            # Bytes → human
            if k.endswith("_bytes") and isinstance(v, (int, float)):
                human_key = k[:-6] + "_human"
                updates[human_key] = _fmt_bytes(float(v))
        obj.update(updates)
    elif isinstance(obj, list):
        for item in obj:
            _augment(item)


def main() -> None:
    path = Path("telemetry/summary.json")
    if not path.exists():
        return
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return
    # Recursive pass for *_seconds and *_bytes
    _augment(data)
    # Ensure canonical top-level alias if present
    if isinstance(data.get("duration_seconds"), (int, float)):
        data["duration_human"] = _fmt_seconds(float(data["duration_seconds"]))
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
