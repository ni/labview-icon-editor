#!/usr/bin/env python3
"""Verify that requirements in traceability.yaml map to existing SRS docs."""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Allow TEST-REQ-* IDs in tests; production IDs use FGC-REQ-*.
ID_RE = r"(?:FGC|TEST)-REQ-[A-Z]+-\d{3}"


def _load_entries(trace: Path) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    current_id: str | None = None
    for line in trace.read_text(encoding="utf-8").splitlines():
        m_id = re.match(rf"\s*- id:\s*({ID_RE})", line)
        if m_id:
            current_id = m_id.group(1)
            continue
        m_src = re.match(r"\s*source:\s*(\S+)", line)
        if m_src and current_id:
            entries.append((current_id, m_src.group(1)))
            current_id = None
    return entries


def main(argv: list[str] | None = None) -> int:
    root = Path(__file__).resolve().parent.parent
    trace = root / "docs" / "traceability.yaml"
    entries = _load_entries(trace)
    errors: list[str] = []
    for req_id, rel in entries:
        path = root / rel
        if not path.exists():
            errors.append(f"{req_id}: source file not found: {rel}")
            continue
        text = path.read_text(encoding="utf-8")
        pattern = req_id.replace("-", "[-\u2011]")
        if not re.search(pattern, text):
            errors.append(f"{req_id}: ID not found in {rel}")
    if errors:
        for err in errors:
            print("ERROR:", err, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
