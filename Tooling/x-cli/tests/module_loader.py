"""Helpers for importing modules listed in ``docs/module-index.md``.

This module parses ``docs/module-index.md`` to build a mapping from module
names to file paths. Results are cached so the index is only read once per
process. Two helpers are exposed:

``load_module(name)``
    Loads a Python module by name using :class:`~importlib.machinery.SourceFileLoader`.

``resolve_path(name)``
    Resolves the full :class:`~pathlib.Path` for a module.
"""

from __future__ import annotations

from importlib.machinery import SourceFileLoader
import importlib.util
from pathlib import Path
from typing import Dict

_MODULE_CACHE: Dict[str, Path] | None = None


def _load_index() -> Dict[str, Path]:
    """Parse ``docs/module-index.md`` and return a mapping of module names to paths."""
    global _MODULE_CACHE
    if _MODULE_CACHE is None:
        index_path = Path(__file__).resolve().parents[1] / "docs" / "module-index.md"
        modules: Dict[str, Path] = {}
        for line in index_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("- `"):
                start = line.find("`") + 1
                end = line.find("`", start)
                rel = line[start:end]
                name = Path(rel).stem
                modules[name] = index_path.parent.parent / rel
        _MODULE_CACHE = modules
    return _MODULE_CACHE


def resolve_path(name: str) -> Path:
    """Return the absolute path for *name* as defined in the module index."""
    modules = _load_index()
    try:
        return modules[name]
    except KeyError as exc:  # pragma: no cover - simple wrapper
        raise KeyError(f"Unknown module {name!r}") from exc


def load_module(name: str):
    """Load and return a module by *name* using :class:`SourceFileLoader`."""
    path = resolve_path(name)
    loader = SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)  # type: ignore[arg-type]
    return module


__all__ = ["load_module", "resolve_path"]

