#!/usr/bin/env python3
"""Validate design document presence and content."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESIGN = ROOT / "docs" / "Design.md"
TRACE = ROOT / "docs" / "traceability.yaml"
TRACE_SCRIPT = ROOT / "scripts" / "verify-traceability.py"


def main(argv: list[str] | None = None) -> int:
    if not DESIGN.exists():
        print("ERROR: docs/Design.md not found", file=sys.stderr)
        return 1

    text = DESIGN.read_text(encoding="utf-8")

    if re.search(r"TODO|TBD|@@@", text, re.IGNORECASE):
        print("ERROR: docs/Design.md contains TODO/TBD/@@@ marker", file=sys.stderr)
        return 1

    if not re.search(r"Status:\**\s*Approved", text):
        print("ERROR: docs/Design.md missing 'Status: Approved' line", file=sys.stderr)
        return 1

    if TRACE.exists():
        result = subprocess.run([sys.executable, str(TRACE_SCRIPT)], check=False)
        if result.returncode != 0:
            print("ERROR: traceability validation failed", file=sys.stderr)
            return 1
    else:
        print("::warning ::docs/traceability.yaml not found; add before tagging release")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
