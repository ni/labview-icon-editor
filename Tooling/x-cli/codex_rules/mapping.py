"""Component resolution based on glob patterns.

Component mapping is defined in `.codex/components.yml`.  Each component
specifies a list of globs that match files belonging to that component.  The
mapping also supports retrieving a default pre‑emptive command and owners.
"""
from __future__ import annotations

import fnmatch
import json
from pathlib import Path
from typing import Dict, List, Optional


class ComponentMapping:
    """Resolves file paths to component names based on YAML globs."""

    def __init__(self, mapping_file: str | Path):
        self.components: Dict[str, Dict] = {}
        if Path(mapping_file).exists():
            content = Path(mapping_file).read_text(encoding="utf-8")
            try:
                import yaml  # type: ignore

                data = yaml.safe_load(content)
            except Exception:
                data = json.loads(content)
            self.components = data.get("components", {})

    def component_for_path(self, path: str) -> str:
        """Return the component name for the given file path.

        The first component whose glob matches the path is returned.  If no
        mapping matches, ``unknown`` is returned.
        """
        norm = path.replace("\\", "/")
        for comp, spec in self.components.items():
            for pat in spec.get("globs", []):
                if fnmatch.fnmatch(norm, pat):
                    return comp
        return "unknown"

    def default_command_for(self, component: str) -> Optional[str]:
        """Return the default pre‑emptive command for the component."""
        comp = self.components.get(component)
        if comp:
            return comp.get("default_preempt_command")
        return None
