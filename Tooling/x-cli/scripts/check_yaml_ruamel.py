#!/usr/bin/env python3
"""Parse YAML files with ruamel.yaml to catch syntax errors.

Usage (pre-commit passes filenames):
    python scripts/check_yaml_ruamel.py <file1> <file2> ...

Exits non-zero on the first parse error and prints a concise message.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from ruamel.yaml import YAML
except Exception as exc:  # pragma: no cover
    print(f"ERROR: ruamel.yaml is required: {exc}", file=sys.stderr)
    sys.exit(2)


def main(argv: list[str] | None = None) -> int:
    files = [Path(p) for p in (argv or sys.argv[1:])]
    yaml = YAML(typ="safe")
    had_error = False
    for p in files:
        if not p.exists():
            # Pre-commit can pass deleted files; skip gracefully
            continue
        if p.suffix.lower() not in {".yml", ".yaml"}:
            continue
        try:
            yaml.load(p.read_text(encoding="utf-8", errors="ignore"))
        except Exception as e:
            print(f"{p.as_posix()}: YAML parse error: {e}", file=sys.stderr)
            had_error = True
    return 1 if had_error else 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

