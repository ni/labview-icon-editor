#!/usr/bin/env python3
"""Validate the SRS registry.

This script shall ensure each Markdown file under ``docs/srs`` declares a
requirement ID in the first-level heading that matches ``<PREFIX>-REQ-<AREA>-NNN``
and includes a ``Version:`` line. IDs shall be unique across files. Any
deviation shall result in a non-zero exit code.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ID = re.compile(r"^#\s+([A-Z]{3,}-REQ-[A-Z-]+-\d{3})", re.M)
VER = re.compile(r"^Version:\s*\d+\.\d+", re.M)


def main() -> int:
    seen: dict[str, Path] = {}
    errs = []
    for path in Path("docs/srs").rglob("*.md"):
        # skip templates and non-requirement stubs
        if path.name.startswith("_") or path.name == "core.md":
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        m_id = ID.search(text)
        m_ver = VER.search(text)
        if not m_id:
            errs.append(f"{path}: missing requirement ID in H1")
        if not m_ver:
            if "Version:" in text:
                errs.append(f"{path}: invalid Version line")
            else:
                errs.append(f"{path}: missing Version line")
        if m_id:
            rid = m_id.group(1)
            if rid in seen:
                errs.append(f"duplicate ID {rid}: {seen[rid]} and {path}")
            seen[rid] = path
    if errs:
        print("SRS registry check failed:\n- " + "\n- ".join(errs))
        return 1
    print("SRS registry check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
