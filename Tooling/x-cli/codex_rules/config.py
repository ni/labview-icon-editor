"""Configuration loading for the codex rules engine.

This module reads the engine’s YAML or JSON configuration from the `.codex`
directory.  If the file or YAML library is missing, it falls back to sensible
defaults.  A small number of settings can be overridden via the CLI.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict


def load_config(path: str | None = None) -> Dict:
    """Load configuration from the given path or from `.codex/rules.yml`.

    Configuration files may be in YAML or JSON format. YAML support
    prefers ruamel.yaml (falls back to PyYAML if available); otherwise the
    loader will attempt to parse JSON.
    When no config file exists, a default configuration is returned.
    """
    default = {
        "window_days": 30,
        "min_occurrences": 3,
        "min_confidence": 0.25,
        "min_lift": 3.0,
        "alpha": 0.01,
        "flaky_threshold": 0.04,
        "min_lift_for_flaky": 3.0,
        "docs": {
            "file": "AGENTS.md",
            "section_title": "Preventative Measures",
            "open_pr": False,
            "bot_name": "codex-rules-bot",
            "bot_email": "codex-bot@example.com",
        },
        "provider": {"type": "none"},
        "storage": {"sqlite_path": ".codex/cache/rules_engine.sqlite"},
        "components_file": ".codex/components.yml",
        "templates_file": ".codex/guidance_templates.yml",
    }
    cfg_path = Path(path or ".codex/rules.yml")
    if not cfg_path.exists():
        return default
    text = cfg_path.read_text(encoding="utf-8")
    if cfg_path.suffix.lower() == ".json":
        return {**default, **json.loads(text)}
    # Try YAML via ruamel.yaml first; fallback to PyYAML if present; else JSON
    # ruamel.yaml path
    try:
        from ruamel.yaml import YAML  # type: ignore

        y = YAML(typ="safe")
        data = y.load(text) or {}
        merged = default.copy()
        merged.update(data)
        return merged
    except Exception:
        # Try legacy PyYAML if available
        try:
            import yaml  # type: ignore

            data = yaml.safe_load(text) or {}
            merged = default.copy()
            merged.update(data)
            return merged
        except Exception:
            # Fallback to JSON
            try:
                data = json.loads(text)
                merged = default.copy()
                merged.update(data)
                return merged
            except Exception:
                return default
