"""Compliance gate for preventative guidance.

Compares the set of *required* commands (from active guidance for components
touched in a PR) with the set of commands the agent claims it actually ran,
loaded from a manifest file.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


def _norm(cmd: str) -> str:
    return " ".join((cmd or "").strip().lower().split())


def load_manifest(path: str) -> List[str]:
    """Load executed commands from a manifest file.

    Accepted formats:
      - JSON object: {"ran": ["...","..."]} or {"commands": ["..."]}
      - JSON array: ["...","..."]
      - NDJSON: each line is a JSON object containing {"cmd": "..."}
      - Plain text: newline-separated commands; lines starting with '#' ignored
    """
    p = Path(path)
    if not p.exists():
        return []
    text = p.read_text(encoding="utf-8")
    cmds: List[str] = []
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            arr = data.get("ran") or data.get("commands") or []
            if isinstance(arr, list):
                cmds = [str(x) for x in arr]
        elif isinstance(data, list):
            cmds = [str(x) for x in data]
        else:
            cmds = []
    except Exception:
        # Try NDJSON
        for line in text.splitlines():
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and obj.get("cmd"):
                    cmds.append(str(obj["cmd"]))
            except Exception:
                # Treat as plain text
                cmds.append(s)
    # Normalize and de-duplicate while preserving order
    seen = set()
    out: List[str] = []
    for c in cmds:
        n = _norm(c)
        if n and n not in seen:
            seen.add(n)
            out.append(n)
    return out


def check(required_commands: Iterable[str], executed_commands: Iterable[str], mode: str = "all") -> Tuple[bool, List[str]]:
    """Return (compliant, missing) given required and executed command sets.

    Matching rule: a required command is considered satisfied if *any* executed
    command has it as a **prefix** (case-insensitive, whitespace-normalized).

    mode:
      - "all": every required command must be satisfied
      - "any": at least one required command must be satisfied
    """
    req = [_norm(r) for r in required_commands if _norm(r)]
    exe = [_norm(e) for e in executed_commands if _norm(e)]
    if not req:
        return True, []
    def satisfied(r: str) -> bool:
        return any(e.startswith(r) for e in exe)
    missing = [r for r in req if not satisfied(r)]
    if mode == "any":
        return (len(missing) < len(req)), missing
    return (len(missing) == 0), missing
