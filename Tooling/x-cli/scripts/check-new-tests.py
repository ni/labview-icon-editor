#!/usr/bin/env python3
"""Fail if C# test files aren't listed in traceability metadata."""

from __future__ import annotations

import re
import sys
from pathlib import Path

EXCLUDED_DIRS = {
    "Unit",
    "Analyzers",
    "Utilities",
    "TestInfra",
    "TestUtil",
    "LockHolder",
    "SrsApi.Tests",
}

EXCLUDED_FILES = {
    "tests/XCli.Tests/SrsRegistryTests.cs",
}

def load_tracked_tests(trace_path: Path) -> set[str]:
    """Collect test file paths referenced in docs/traceability.yaml."""

    test_re = re.compile(r"\s*- (tests/.*\.cs)")
    tracked: set[str] = set()
    for line in trace_path.read_text(encoding="utf-8").splitlines():
        match = test_re.match(line)
        if match:
            tracked.add(match.group(1))
    return tracked

def find_repo_tests(tests_dir: Path, root: Path) -> set[str]:
    """Locate C# test files in the repository excluding utilities."""

    found: set[str] = set()
    for path in tests_dir.rglob("*.cs"):
        rel = path.relative_to(root)
        if any(part in EXCLUDED_DIRS for part in rel.parts):
            continue
        if not path.name.endswith("Tests.cs"):
            continue
        rel_path = str(rel).replace("\\", "/")
        if rel_path in EXCLUDED_FILES:
            continue
        found.add(rel_path)
    return found

def main() -> int:
    root = Path(__file__).resolve().parent.parent
    trace_file = root / "docs" / "traceability.yaml"
    tests_dir = root / "tests"

    tracked = load_tracked_tests(trace_file)
    present = find_repo_tests(tests_dir, root)

    missing = sorted(present - tracked)
    if missing:
        print("Error: untracked test files detected:")
        for path in missing:
            print(f" - {path}")
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
