from __future__ import annotations

"""Lightweight configuration loader for repo scripts.

Reads `.codex/rules.yml` (or JSON) when present and merges with sensible
defaults. This mirrors the minimal shape expected by internal tools:
 - docs.section_title (str)
 - storage.sqlite_path (str)

YAML parsing prefers ruamel.yaml when available; otherwise falls back to PyYAML
if present, and finally JSON parsing. Missing or invalid files yield defaults.
"""

from pathlib import Path
from typing import Dict
import json


def load_config(path: str | None = None) -> Dict:
    default: Dict = {
        "docs": {"section_title": "Preventative Measures"},
        "storage": {"sqlite_path": ".codex/cache/rules_engine.sqlite"},
    }
    cfg_path = Path(path or ".codex/rules.yml")
    if not cfg_path.exists():
        # Try json variant as a convenience
        cfg_path_json = cfg_path.with_suffix(".json")
        if not cfg_path_json.exists():
            return default
        cfg_path = cfg_path_json
    try:
        text = cfg_path.read_text(encoding="utf-8")
    except Exception:
        return default

    # JSON explicit
    if cfg_path.suffix.lower() == ".json":
        try:
            data = json.loads(text) or {}
            merged = default.copy()
            merged.update(data)
            return merged
        except Exception:
            return default

    # YAML via ruamel.yaml → PyYAML → JSON
    try:
        from ruamel.yaml import YAML  # type: ignore

        y = YAML(typ="safe")
        data = y.load(text) or {}
        merged = default.copy()
        merged.update(data)
        return merged
    except Exception:
        try:
            import yaml  # type: ignore

            data = yaml.safe_load(text) or {}
            merged = default.copy()
            merged.update(data)
            return merged
        except Exception:
            try:
                data = json.loads(text) or {}
                merged = default.copy()
                merged.update(data)
                return merged
            except Exception:
                return default

