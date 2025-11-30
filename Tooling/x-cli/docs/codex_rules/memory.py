"""Simple in-repo persistent memory layer for codex agents.

This module reads and writes a memory file located at `.codex/memory.json`
within the repository root. The file holds a list of entries. Each entry is
a dictionary with at least a `timestamp` and a `summary` key, and optionally
`author` or arbitrary data fields.
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from subprocess import CalledProcessError, check_output
from typing import Any, Dict, List


def _detect_repo_root() -> Path:
    """Return the repository root directory.

    The function first attempts to query `git` for the top-level directory.
    If that fails (e.g., `git` is unavailable), it falls back to searching
    parent directories for a `.git` marker. As a last resort, the current
    working directory is returned.
    """

    try:
        return Path(check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    except (CalledProcessError, FileNotFoundError):
        path = Path(__file__).resolve()
        for parent in [path, *path.parents]:
            if (parent / ".git").exists():
                return parent
        return Path.cwd()


REPO_ROOT = _detect_repo_root()
MEMORY_PATH = REPO_ROOT / ".codex" / "memory.json"


def load_memory() -> List[Dict[str, Any]]:
    """Return the list of memory entries (empty list if file missing)."""
    if not MEMORY_PATH.exists():
        return []
    try:
        data = json.loads(MEMORY_PATH.read_text(encoding="utf-8"))
    except Exception:
        return []
    entries = data.get("entries", [])
    if isinstance(entries, list):
        return entries
    return []


def append_entry(entry: Dict[str, Any]) -> None:
    """Append an entry to the memory file.

    The entry should already contain a `summary` and may include an
    `author` or additional keys. A `timestamp` will be added if missing.
    """
    memory = load_memory()
    if "timestamp" not in entry:
        entry["timestamp"] = datetime.utcnow().isoformat() + "Z"
    memory.append(entry)
    MEMORY_PATH.parent.mkdir(parents=True, exist_ok=True)
    with MEMORY_PATH.open("w", encoding="utf-8") as f:
        json.dump({"entries": memory}, f, indent=2)
