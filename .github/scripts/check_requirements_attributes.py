#!/usr/bin/env python3
"""
Requirements attribute completeness and verification readiness checks (ISO/IEC/IEEE 29148).
- Ensure mandatory fields are present.
- Enforce allowed vocabularies (Type, Priority, Verification Level).
- Validate verification detail per primary method.
- Ensure Version & Change Notes hash matches Requirement Statement (bump version/hash when statement changes).
"""

from __future__ import annotations

import csv
import hashlib
import re
import sys
from pathlib import Path

REQUIRED_NONEMPTY = [
    "Rationale",
    "Verification Methods (from SRS)",
    "Primary Method (select)",
    "Owner/Role",
    "Upstream Trace",
    "Downstream Trace",
    "Verification Level",
]

ALLOWED_TYPES = {
    "Functional/Performance",
    "Interface",
    "Process",
    "Quality (non-functional)",
    "Usability/Quality-in-Use",
}

ALLOWED_PRIORITY = {"High", "Medium", "Low"}
ALLOWED_VERIFICATION_LEVEL = {"Unit", "Integration", "System", "Acceptance"}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        return list(reader)


def short_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def ensure_required(row: dict[str, str], rid: str, errors: list[str]) -> None:
    for col in REQUIRED_NONEMPTY:
        if not (row.get(col) or "").strip():
            errors.append(f"{rid}: {col} is required.")


def check_vocab(row: dict[str, str], rid: str, errors: list[str], warnings: list[str]) -> None:
    t = (row.get("Type") or "").strip()
    if t and t not in ALLOWED_TYPES:
        errors.append(f"{rid}: Type '{t}' not in allowed set {sorted(ALLOWED_TYPES)}.")
    p = (row.get("Priority") or "").strip()
    if p and p not in ALLOWED_PRIORITY:
        errors.append(f"{rid}: Priority '{p}' not in allowed set {sorted(ALLOWED_PRIORITY)}.")
    level = (row.get("Verification Level") or "").strip()
    if level and level not in ALLOWED_VERIFICATION_LEVEL:
        errors.append(f"{rid}: Verification Level '{level}' must be one of {sorted(ALLOWED_VERIFICATION_LEVEL)}.")


def check_verification_detail(row: dict[str, str], rid: str, errors: list[str], warnings: list[str]) -> None:
    primary = (row.get("Primary Method (select)") or "").lower()
    detail = (row.get("Verification Detail") or "").lower()
    if "analysis" in primary or "simulation" in primary:
        if not re.search(r"(tool|model|analysis|simulation|method)", detail):
            errors.append(f"{rid}: Verification Detail must include tool/method for Analysis/Simulation.")
    elif "inspection" in primary:
        if not re.search(r"(inspect|compare|reference|doc|file|path|snippet)", detail):
            errors.append(f"{rid}: Verification Detail must cite reference document/path for Inspection.")
    elif "test" in primary or "demo" in primary or "demonstration" in primary:
        if not re.search(r"(witness|facility|equipment|environment|data|capture|pass/fail|passfail)", detail):
            errors.append(f"{rid}: Verification Detail must include witnesses/facility/equipment for Demonstration/Test.")
    else:
        warnings.append(f"{rid}: Primary Method '{primary}' not recognized for detail check.")


def check_version_hash(row: dict[str, str], rid: str, errors: list[str]) -> None:
    stmt = (row.get("Requirement Statement") or "").replace("\r", "")
    computed = short_hash(stmt)
    version_field = (row.get("Version & Change Notes") or "").strip()
    if not version_field:
        errors.append(f"{rid}: Version & Change Notes is required and must include version + hash=.")
        return
    version_match = re.search(r"^\s*v?(\d+)", version_field)
    if not version_match:
        errors.append(f"{rid}: Version & Change Notes must start with a numeric version (e.g., '2 | hash=...').")
    hash_match = re.search(r"hash=([0-9a-fA-F]+)", version_field)
    if not hash_match:
        errors.append(f"{rid}: Version & Change Notes must record hash=<sha> matching Requirement Statement.")
        return
    stored_hash = hash_match.group(1).lower()
    if computed != stored_hash[: len(computed)] and computed != stored_hash:
        errors.append(
            f"{rid}: Requirement Statement changed (hash {computed}); bump version and update Version & Change Notes (currently '{version_field}')."
        )


def main() -> None:
    target = Path("docs/requirements/requirements.csv")
    if not target.is_file():
        print(f"{target} not found", file=sys.stderr)
        sys.exit(1)

    errors: list[str] = []
    warnings: list[str] = []
    for idx, row in enumerate(read_csv(target), start=2):
        rid = row.get("ID", f"row {idx}")
        ensure_required(row, rid, errors)
        check_vocab(row, rid, errors, warnings)
        check_verification_detail(row, rid, errors, warnings)
        check_version_hash(row, rid, errors)

    for w in warnings:
        print(f"::warning ::{w}")
    if errors:
        print("Requirement attribute checks failed:")
        for e in errors:
            print(f"- {e}")
        sys.exit(1)
    print("Requirement attribute checks: OK")


if __name__ == "__main__":
    main()
