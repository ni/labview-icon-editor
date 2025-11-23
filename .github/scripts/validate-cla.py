#!/usr/bin/env python3
"""
Validate docs/cla/manifest.json for required structure.
"""

import json
import re
import sys
from pathlib import Path

def main() -> int:
    path = Path("docs/cla/manifest.json")
    if not path.is_file():
        print(f"Missing {path}", file=sys.stderr)
        return 1

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover - runtime guard
        print(f"Failed to parse {path}: {exc}", file=sys.stderr)
        return 1

    errors = []
    contributors = data.get("contributors")
    if not isinstance(contributors, list) or not contributors:
        errors.append("contributors must be a non-empty array")

    seen = set()
    date_re = re.compile(r"^\d{4}-\d{2}-\d{2}$")
    valid_types = {"individual", "corporate"}

    def required(entry: dict, key: str) -> str:
        val = entry.get(key)
        if not val or not isinstance(val, str):
            errors.append(f"entry for {entry.get('github', '<missing github>')}: missing/invalid '{key}'")
        return val

    if isinstance(contributors, list):
        for entry in contributors:
            if not isinstance(entry, dict):
                errors.append("each contributor entry must be an object")
                continue
            gh = required(entry, "github")
            cla_type = required(entry, "cla_type")
            cla_version = required(entry, "cla_version")
            signed_on = required(entry, "signed_on")
            evidence = required(entry, "evidence")
            # Optional but typed
            email = entry.get("email")
            if email is not None and not isinstance(email, str):
                errors.append(f"entry for {gh}: email must be a string if present")

            if gh:
                if gh in seen:
                    errors.append(f"duplicate github handle: {gh}")
                seen.add(gh)
            if cla_type and cla_type not in valid_types:
                errors.append(f"entry for {gh}: cla_type must be one of {sorted(valid_types)}")
            if signed_on and not date_re.match(signed_on):
                errors.append(f"entry for {gh}: signed_on must be YYYY-MM-DD")
            if evidence and evidence.strip() == "":
                errors.append(f"entry for {gh}: evidence must not be empty")

    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    print(f"{path} passed validation for {len(contributors)} contributor(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
