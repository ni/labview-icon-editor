#!/usr/bin/env python3
"""
ISO/IEC/IEEE 29148 language lint for requirements.csv.
- Fail on banned or ambiguous terms in Requirement Statement.
- Warn when Acceptance Criteria lacks measurable/observable conditions.
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

BANNED_TERMS = [
    "and/or",
    "as appropriate",
    "but not limited to",
    "user friendly",
    "best",
    "always",
    "never",
    "if possible",
    "minimum",
    "as a minimum",
]

COMPARATIVE_PATTERNS = [
    r"\bbetter than\b",
]

PRONOUN_PATTERN = re.compile(r"^(this|that|it)\b", re.IGNORECASE)
PRONOUN_SENTENCE_START = re.compile(r"(?:^|[\\.?!;]\s+)(this|that|it)\s+(shall|should|may|must|will)\b", re.IGNORECASE)


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        return list(reader)


def has_measurable(criteria: str) -> bool:
    lower = criteria.lower()
    if re.search(r"\d", lower):
        return True
    if re.search(r"\b(?:<=?|>=?|less than|greater than|at least|no more than|within|equal(?:s)?|exact(?:ly)?)\b", lower):
        return True
    if re.search(r"\b(?:event|error|failure|retry|timeout|duration|latency|count|code)\b", lower):
        return True
    return False


def lint_requirements(path: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    rows = load_rows(path)
    for idx, row in enumerate(rows, start=2):  # header is line 1
        rid = row.get("ID", f"row {idx}")
        stmt = (row.get("Requirement Statement") or "").strip()
        criteria = (row.get("Acceptance Criteria") or "").strip()
        lower_stmt = stmt.lower()

        for term in BANNED_TERMS:
            if term in lower_stmt:
                errors.append(f"{rid}: Requirement Statement contains banned term '{term}'.")
        for pattern in COMPARATIVE_PATTERNS:
            if re.search(pattern, lower_stmt):
                errors.append(f"{rid}: Requirement Statement uses comparative phrasing ('{pattern}'); rewrite to absolute, testable wording.")
        if PRONOUN_PATTERN.search(lower_stmt) or PRONOUN_SENTENCE_START.search(lower_stmt):
            errors.append(f"{rid}: Requirement Statement starts with/relies on vague pronoun (this/that/it); restate the subject explicitly.")

        if not criteria:
            warnings.append(f"{rid}: Acceptance Criteria is empty; add measurable conditions.")
        elif not has_measurable(criteria):
            warnings.append(f"{rid}: Acceptance Criteria may lack measurable/observable conditions.")

    return errors, warnings


def main() -> None:
    target = Path("docs/requirements/requirements.csv")
    if not target.is_file():
        print(f"{target} not found", file=sys.stderr)
        sys.exit(1)
    errors, warnings = lint_requirements(target)
    for w in warnings:
        print(f"::warning ::{w}")
    if errors:
        print("Requirements language lint failed:")
        for e in errors:
            print(f"- {e}")
        sys.exit(1)
    print("Requirements language lint: OK")


if __name__ == "__main__":
    main()
