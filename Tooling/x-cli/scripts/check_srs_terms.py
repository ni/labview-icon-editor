#!/usr/bin/env python3
"""Fail if SRS docs use non-normative wording.

Searches for "should", "must", or "will" in `docs/srs/` and exits
non-zero when found (FGC-REQ-SPEC-001).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SRS_DIR = REPO_ROOT / "docs" / "srs"
PROHIBITED = re.compile(r"\b(should|must|will)\b", re.IGNORECASE)


def scan() -> list[str]:
    errors: list[str] = []
    for path in sorted(SRS_DIR.glob("*.md")):
        text = path.read_text(encoding="utf-8").splitlines()
        for idx, line in enumerate(text, 1):
            match = PROHIBITED.search(line)
            if match:
                rel = path.relative_to(REPO_ROOT).as_posix()
                errors.append(
                    f"{rel}:{idx}: contains prohibited term '{match.group(0)}'"
                )
    return errors


def main(argv: list[str] | None = None) -> int:
    errors = scan()
    if errors:
        for err in errors:
            print(err, file=sys.stderr)
        print(f"{len(errors)} file(s) contain prohibited terms", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
