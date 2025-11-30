#!/usr/bin/env python3
"""Ensure telemetry includes cross-agent feedback block (FGC-REQ-TEL-001)."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PATH = REPO_ROOT / ".codex" / "telemetry.json"
BLOCK_HEADER = "### Cross-Agent Telemetry Recommendation"
SUBSECTIONS = ["#### Effectiveness", "#### Obstacles", "#### Improvements"]


def _validate_entry(entry: dict, index: int) -> list[str]:
    errors: list[str] = []
    feedback = entry.get("agent_feedback")
    if feedback is None:
        return errors
    if BLOCK_HEADER not in feedback:
        errors.append(f"entry {index} missing block header")
    for section in SUBSECTIONS:
        if section not in feedback:
            errors.append(f"entry {index} missing section {section}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check telemetry agent_feedback block"
    )
    parser.add_argument("path", nargs="?", default=DEFAULT_PATH, help="telemetry.json path")
    args = parser.parse_args(argv)
    path = Path(args.path)
    if not path.exists():
        print(f"No telemetry file found at {path}", file=sys.stderr)
        return 1
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = data.get("entries", [])
    found = False
    errors: list[str] = []
    for idx, entry in enumerate(entries):
        if "agent_feedback" in entry:
            found = True
            errors.extend(_validate_entry(entry, idx))
    if not found:
        print("no entries with agent_feedback found", file=sys.stderr)
        return 1
    if errors:
        for err in errors:
            print(err, file=sys.stderr)
        return 1
    print("telemetry agent_feedback block present")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
