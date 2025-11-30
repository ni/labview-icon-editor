#!/usr/bin/env python3
"""Ensure PR description includes agent feedback block (FGC-REQ-DEV-004)."""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

BLOCK_HEADER = "### Cross-Agent Telemetry Recommendation"
SUBSECTIONS = ["#### Effectiveness", "#### Obstacles", "#### Improvements"]
DEFAULT_PATH = Path("PR_DESCRIPTION.md")

def _load_text(path: Path | None) -> str:
    if path:
        if path.exists():
            return path.read_text(encoding="utf-8")
        return ""
    if DEFAULT_PATH.exists():
        return DEFAULT_PATH.read_text(encoding="utf-8")
    return os.environ.get("PR_BODY", "")

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check PR description for agent feedback block"
    )
    parser.add_argument("path", nargs="?", help="file containing PR description")
    args = parser.parse_args(argv)

    text = _load_text(Path(args.path) if args.path else None)
    if not text:
        print("no PR description text found", file=sys.stderr)
        return 1
    if BLOCK_HEADER not in text:
        print("missing block header", file=sys.stderr)
        return 1
    block = text.split(BLOCK_HEADER, 1)[1]
    missing = [s for s in SUBSECTIONS if s not in block]
    if missing:
        for sec in missing:
            print(f"missing section {sec}", file=sys.stderr)
        return 1
    print("agent feedback block present")
    return 0

if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
