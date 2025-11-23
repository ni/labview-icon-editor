#!/usr/bin/env python3
"""
Lint ADRs and agent.yaml for requirements language quality:
- Prefer shall/should/may (flag uses of must/will/etc.)
- Avoid vague terms (user-friendly, as appropriate, TBD, etc.)
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

BANNED_PHRASES = [
    "user friendly",
    "user-friendly",
    "as appropriate",
    "as needed",
    "if possible",
    "where possible",
    "where appropriate",
    "best effort",
    "tbd",
    "to be determined",
    "etc.",
    "etc",
    "intuitive",
]

FORBIDDEN_MODALS = [
    r"\bmust\b",
    r"\bwill\b",
    r"\bneeds? to\b",
]

IGNORE_TOKEN = "lint-disable: requirements-language"


def iter_target_files(args: argparse.Namespace) -> list[Path]:
    files: list[Path] = []
    if args.files:
        for path_str in args.files:
            files.append(Path(path_str))
        return files

    files.append(Path("agent.yaml"))
    files.extend(sorted(Path("docs/adr").glob("ADR-*.md")))
    return files


def lint_file(path: Path) -> list[str]:
    violations: list[str] = []
    if not path.is_file():
        violations.append(f"{path}: file not found")
        return violations

    for lineno, line in enumerate(path.read_text().splitlines(), start=1):
        if IGNORE_TOKEN in line:
            continue
        lower = line.lower()
        for phrase in BANNED_PHRASES:
            if phrase in lower:
                violations.append(
                    f"{path}:{lineno}: avoid vague phrase '{phrase}'; use measurable, testable wording."
                )
        for pattern in FORBIDDEN_MODALS:
            match = re.search(pattern, lower)
            if match:
                violations.append(
                    f"{path}:{lineno}: prefer shall/should/may instead of '{match.group(0)}' (line: {line.strip()})"
                )
    return violations


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Lint ADRs and agent.yaml for requirements language (shall/should/may + avoid vague terms)."
    )
    parser.add_argument("files", nargs="*", help="Optional explicit files to lint")
    args = parser.parse_args()

    all_violations: list[str] = []
    for path in iter_target_files(args):
        all_violations.extend(lint_file(path))

    if all_violations:
        print("Requirements language lint failed:")
        for v in all_violations:
            print(f"- {v}")
        sys.exit(1)

    print("Requirements language lint: OK")


if __name__ == "__main__":
    main()
