#!/usr/bin/env python3
"""Fail if SRS docs lack measurable acceptance criteria.

Checks that each `docs/srs/FGC-REQ-*.md` file contains an "Acceptance Criteria"
section with at least one `AC` bullet (FGC-REQ-SPEC-001).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SRS_DIR = REPO_ROOT / "docs" / "srs"
AC_BULLET = re.compile(r"^- AC\d+\. ", re.MULTILINE)


def scan() -> list[str]:
    errors: list[str] = []
    for path in sorted(SRS_DIR.glob("FGC-REQ-*.md")):
        text = path.read_text(encoding="utf-8")
        if "Acceptance Criteria:" not in text:
            rel = path.relative_to(REPO_ROOT).as_posix()
            errors.append(f"{rel}: missing Acceptance Criteria section")
            continue
        if not AC_BULLET.search(text):
            rel = path.relative_to(REPO_ROOT).as_posix()
            errors.append(f"{rel}: missing AC bullet")
    return errors


def main(argv: list[str] | None = None) -> int:
    errors = scan()
    if errors:
        for err in errors:
            print(err, file=sys.stderr)
        print(f"{len(errors)} file(s) missing acceptance criteria", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
