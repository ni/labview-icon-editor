#!/usr/bin/env python3
"""Check that tests do not access docs via the current working directory.

The script scans Python test files for references like ``Path("docs/...")`` or
``open("docs/..."`` that would resolve relative to the process's current working
directory (CWD). Tests shall instead derive the repository root path via
``Path(__file__).resolve().parents[1]``.

Exit status:
    0 -- no path hygiene violations were found.
    1 -- one or more violations were detected and printed.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Iterable

_BAD = re.compile(
    r"""(Path\(\s*['"]docs/)|(open\(\s*(?:Path\(\s*)?['"]docs/)"""
)


def find_violations(test_dir: Path) -> list[str]:
    """Return violation messages for offending test files under *test_dir*."""

    failures: list[str] = []
    for p in test_dir.rglob("test*.py"):
        text = p.read_text(encoding="utf-8", errors="ignore")
        for i, ln in enumerate(text.splitlines(), 1):
            if _BAD.search(ln):
                failures.append(
                    f"{p}:{i}: avoid 'docs/...' relative to the working directory; derive the repository root path via Path(__file__).resolve().parents[1]"
                )
    return failures


def main(argv: Iterable[str] | None = None) -> int:
    """Run the path hygiene check and return an exit code."""

    args = list(argv) if argv is not None else sys.argv[1:]
    test_dir = Path(args[0]) if args else Path("tests")
    failures = find_violations(test_dir)
    if failures:
        print("Path hygiene violations:\n- " + "\n- ".join(failures))
        return 1
    print("Path hygiene OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
