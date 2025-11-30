#!/usr/bin/env python3
"""Lint to prevent new runtime dependencies on codex_rules in scripts/.

Rules:
- No 'import codex_rules' from files under scripts/ (except scripts/lib and tests).
- Forbid 'pip install -e' usage in repo scripts.

Rationale: codex_rules is an internal helper library; avoid packaging/PATH drift
by importing from scripts/lib instead.
"""
from __future__ import annotations

import ast
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def scan_codex_imports() -> list[str]:
    errors: list[str] = []
    for path in (REPO / "scripts").rglob("*.py"):
        # allow internal libs and tests to import freely
        rel = path.relative_to(REPO).as_posix()
        if rel.startswith("scripts/lib/") or rel.startswith("scripts/tests/"):
            continue
        # No exceptions: codex_rules must not be imported from scripts/
        try:
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    if alias.name.split(".")[0] == "codex_rules":
                        errors.append(rel)
                        break
            elif isinstance(node, ast.ImportFrom):
                if (node.module or "").split(".")[0] == "codex_rules":
                    errors.append(rel)
                    break
    return sorted(set(errors))


def scan_editable_installs() -> list[str]:
    offenders: list[str] = []
    pattern = re.compile(r"pip\s+install\s+-e\b")
    for path in REPO.rglob("*.sh"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        if pattern.search(text):
            offenders.append(path.relative_to(REPO).as_posix())
    for path in REPO.rglob("*.ps1"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        if pattern.search(text):
            offenders.append(path.relative_to(REPO).as_posix())
    return sorted(set(offenders))


def main() -> int:
    errors = scan_codex_imports()
    installs = scan_editable_installs()
    rc = 0
    if errors:
        print("codex_rules imports are not allowed from scripts/:", file=sys.stderr)
        for e in errors:
            print(f" - {e}", file=sys.stderr)
        rc = 1
    if installs:
        print("'pip install -e' usage is forbidden (avoid PATH drift):", file=sys.stderr)
        for p in installs:
            print(f" - {p}", file=sys.stderr)
        rc = 1
    if rc == 0:
        print("codex_rules usage lint: OK")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
