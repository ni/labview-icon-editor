#!/usr/bin/env python3
"""
Set-quality guardrails for requirements.csv:
- Fail on TBD/TBR placeholders (indicates incompleteness).
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path


def main() -> None:
    target = Path("docs/requirements/requirements.csv")
    if not target.is_file():
        print(f"{target} not found", file=sys.stderr)
        sys.exit(1)

    with target.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.reader(fh))
    if not rows:
        print(f"{target} is empty", file=sys.stderr)
        sys.exit(1)

    header = rows[0]
    problems: list[str] = []
    for idx, row in enumerate(rows[1:], start=2):
        if not row:
            continue
        rid = row[0].strip() or f"row {idx}"
        for col_idx, cell in enumerate(row):
            value = (cell or "").lower()
            if "tbd" in value or "tbr" in value:
                col_name = header[col_idx] if col_idx < len(header) else f"col{col_idx}"
                problems.append(f"{target}:{idx} ({rid}) contains placeholder in column '{col_name}'.")

    if problems:
        print("Set quality check failed (remove TBD/TBR placeholders):")
        for p in problems:
            print(f"- {p}")
        sys.exit(1)

    print("Set quality check: OK (no TBD/TBR placeholders).")


if __name__ == "__main__":
    main()
