#!/usr/bin/env python3
"""Verify that each workflow declares a known SRS ID."""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Allow TEST-REQ-* IDs in tests; production IDs use FGC-REQ-*.
ID_RE = r"(?:FGC|TEST)-REQ-[A-Z]+-\d{3}"


def load_known_ids(root: Path) -> set[str]:
    trace = root / "docs" / "traceability.yaml"
    text = trace.read_text(encoding="utf-8")
    return set(re.findall(rf"^\s*- id:\s*({ID_RE})", text, flags=re.MULTILINE))


def main(argv: list[str] | None = None) -> int:
    root = Path(__file__).resolve().parent.parent
    known = load_known_ids(root)
    workflows = sorted((root / ".github" / "workflows").glob("*.yml"))
    errors: list[str] = []
    for wf in workflows:
        ids: list[str] = []
        for line in wf.read_text(encoding="utf-8").splitlines():
            m = re.search(rf"#\s*SRS:\s*({ID_RE})", line)
            if m:
                ids.append(m.group(1))
        if not ids:
            errors.append(f"{wf}: missing '# SRS:' annotation")
            continue
        for req_id in ids:
            if req_id not in known:
                errors.append(f"{wf}: unknown SRS ID {req_id}")
    if errors:
        for err in errors:
            print("ERROR:", err, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
