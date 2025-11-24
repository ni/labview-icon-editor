#!/usr/bin/env python3
"""
Lint ADRs and agent.yaml for requirements language quality:
- Prefer shall/should/may (flag uses of must/will/etc.)
- Avoid vague terms (user-friendly, as appropriate, TBD, etc.)
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path
from typing import Iterable

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
    files.append(Path("docs/requirements/requirements.csv"))
    files.extend(sorted(Path("docs/adr").glob("ADR-*.md")))
    return files


def lint_file(path: Path) -> list[str]:
    violations: list[str] = []
    if not path.is_file():
        violations.append(f"{path}: file not found")
        return violations

    # Special CSV shape check for requirements.csv
    if path.name == "requirements.csv" and path.parent.name == "requirements":
        violations.extend(lint_requirements_csv(path))
        return violations

    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        violations.extend(lint_line(path, lineno, line))
    return violations


def lint_requirements_csv(path: Path) -> list[str]:
    violations: list[str] = []
    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.reader(fh)
        rows = list(reader)
    if not rows:
        violations.append(f"{path}: file is empty")
        return violations

    header_len = len(rows[0])
    for idx, row in enumerate(rows[1:], start=2):  # line numbers are 1-based; header is line 1
        if len(row) != header_len:
            violations.append(
                f"{path}:{idx}: column count mismatch (expected {header_len}, got {len(row)}); check quoting/commas."
            )
    # Prefix continuity check
    prefixes = []
    for row in rows[1:]:
        if not row:
            continue
        rid = row[0].strip()
        if not rid or rid.lower() == "id":
            continue
        prefix = rid.split("-")[0]
        if not prefixes or prefixes[-1] != prefix:
            prefixes.append(prefix)
    from collections import Counter
    counts = Counter(prefixes)
    non_contiguous = [p for p, c in counts.items() if c > 1]
    for prefix in non_contiguous:
        violations.append(
            f"{path}: requirement IDs with prefix '{prefix}' are split into multiple blocks; group them contiguously to avoid breaking sequences."
        )

    # Language lint per cell
    for row_idx, row in enumerate(rows, start=1):
        for cell in row:
            violations.extend(lint_line(path, row_idx, cell))
    return violations


def lint_line(path: Path, lineno: int, line: str) -> list[str]:
    violations: list[str] = []
    if IGNORE_TOKEN in line:
        return violations
    lower = line.lower()
    for phrase in BANNED_PHRASES:
        if phrase.startswith("etc"):
            if re.search(r"\betc\.?\b", lower):
                violations.append(
                    f"{path}:{lineno}: avoid vague phrase 'etc'; use measurable, testable wording."
                )
        elif phrase in lower:
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
