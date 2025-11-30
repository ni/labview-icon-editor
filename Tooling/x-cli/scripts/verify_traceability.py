#!/usr/bin/env python3
"""Validate requirement traceability mappings.

Requires ruamel.yaml. This script shall ensure each SRS requirement is mapped in
``docs/traceability.yaml``. The mapping file shall parse as valid YAML. Each
entry shall declare an ``id`` matching ``[A-Z]{3,}-REQ-[A-Z]+-\d{3}`` and a
``source`` field. Optional ``code`` and ``tests`` lists may appear; declared
tests shall exist. Unmapped SRS files, missing artifacts, or parse errors shall
result in a non-zero exit code.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:  # pragma: no cover - import error is handled gracefully
    from ruamel.yaml import YAML
    _yaml = YAML(typ="safe")
except ModuleNotFoundError:  # pragma: no cover - exercised in production only
    print("ruamel.yaml is required for traceability checks; install with 'pip install ruamel.yaml'.")
    sys.exit(1)

TRACE_FILE = Path("docs/traceability.yaml")
SRS_DIR = Path("docs/srs")
ID = re.compile(r"^#\s+([A-Z]{3,}-REQ-[A-Z]+-\d{3})", re.M)
ID_PATTERN = re.compile(r"[A-Z]{3,}-REQ-[A-Z]+-\d{3}")


def main() -> int:
    if not TRACE_FILE.exists():
        print("Traceability check failed: docs/traceability.yaml not found")
        return 1

    try:
        data = _yaml.load(TRACE_FILE.read_text(encoding="utf-8")) or {}
    except Exception as exc:
        print(f"Traceability check failed: failed to parse docs/traceability.yaml: {exc}")
        return 1
    errs = []
    mapped_ids: set[str] = set()

    for entry in data.get("requirements") or []:
        rid = entry.get("id")
        src = entry.get("source")
        if not rid or not src:
            errs.append("entry missing required 'id' or 'source' field")
            continue
        if not ID_PATTERN.fullmatch(rid):
            errs.append(f"invalid requirement ID format: {rid}")
        mapped_ids.add(rid)
        if not Path(src).exists():
            errs.append(f"source file not found for {rid}: {src}")
        for test_path in entry.get("tests") or []:
            if not Path(test_path).exists():
                errs.append(f"test path not found for {rid}: {test_path}")

    for srs_file in SRS_DIR.rglob("*.md"):
        text = srs_file.read_text(encoding="utf-8", errors="ignore")
        match = ID.search(text)
        if match and match.group(1) not in mapped_ids:
            errs.append(f"unmapped requirement {match.group(1)} in {srs_file}")

    if errs:
        print("Traceability check failed:\n- " + "\n- ".join(errs))
        return 1
    print("Traceability check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
