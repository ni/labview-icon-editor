#!/usr/bin/env python3
"""Validate SRS IDs from the SRS_IDS environment variable.

Ensures each provided ID maps to a known, unambiguous requirement
(FGC-REQ-DEV-005).
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Allow TEST-REQ-* IDs in tests; production IDs use FGC-REQ-*.
SRS_ID_RE = r"(?:FGC|TEST)[\u2011-]REQ[\u2011-][A-Z]+[\u2011-]\d{3}"
VER_RE = r"\d+(?:\.\d+)*"

def normalize_id(id_: str) -> str:
    return "-".join(part.upper() for part in id_.replace("\u2011", "-").split("-"))

def _load_srs_registry(root: Path) -> dict[str, list[tuple[str, str]]]:
    """Return mapping of IDs to spec locations and versions."""
    specs: dict[str, list[tuple[str, str]]] = {}
    srs_dir = root / "docs" / "srs"
    if srs_dir.exists():
        for path in srs_dir.glob("*.md"):
            text = path.read_text(encoding="utf-8")
            version_match = re.search(r"Version:\s*\*{0,2}\s*(\S+)", text)
            version = version_match.group(1).strip() if version_match else ""
            for id_raw in set(re.findall(SRS_ID_RE, text)):
                id_ = normalize_id(id_raw)
                rel = path.relative_to(root).as_posix()
                specs.setdefault(id_, [])
                if (rel, version) not in specs[id_]:
                    specs[id_].append((rel, version))
    return specs

def main(argv: list[str] | None = None) -> int:
    env_ids = os.getenv("SRS_IDS", "")
    ids = [s.strip() for s in env_ids.split(",") if s.strip()]
    if not ids:
        return 0
    specs = _load_srs_registry(REPO_ROOT)
    errors: list[str] = []
    for raw in ids:
        if "@" in raw:
            id_part, ver = raw.split("@", 1)
        else:
            id_part, ver = raw, ""
        id_ = normalize_id(id_part)
        matches = specs.get(id_, [])
        if not matches:
            errors.append(f"unknown SRS ID {id_}")
            continue
        if len(matches) > 1:
            if ver:
                if not any(v == ver for _, v in matches):
                    locs = ", ".join(f"{p}@{v}" if v else p for p, v in matches)
                    errors.append(
                        f"SRS ID {id_}@{ver} not found; available: {locs}"
                    )
            else:
                locs = ", ".join(f"{p}@{v}" if v else p for p, v in matches)
                errors.append(
                    f"SRS ID {id_} maps to multiple specs: {locs}; specify version"
                )
            continue
        match_ver = matches[0][1]
        if ver and match_ver and ver != match_ver:
            errors.append(
                f"SRS ID {id_}@{ver} version mismatch; spec version {match_ver}"
            )
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
