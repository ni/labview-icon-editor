#!/usr/bin/env python3
"""Verify changed SRS IDs are mapped in traceability and module maps.

Scope: Only SRS files changed in the current diff (PR or last commit).

Checks:
 - Each changed docs/srs/*.md exposes a requirement ID in H1 (# <ID> ...).
 - That ID appears under requirements[].id in docs/traceability.yaml.
 - That ID appears in at least one list within docs/module-srs-map.yaml.

Exit codes: 0 OK, 1 failures, 2 config error.
"""
from __future__ import annotations

import os
import re
import sys
import subprocess
from pathlib import Path

try:
    from ruamel.yaml import YAML  # type: ignore
except Exception as exc:  # pragma: no cover
    print("ruamel.yaml is required (pip install ruamel.yaml)")
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
SRS_DIR = ROOT / "docs" / "srs"
TRACE = ROOT / "docs" / "traceability.yaml"
MODMAP = ROOT / "docs" / "module-srs-map.yaml"

H1_ID = re.compile(r"^#\s+([A-Z]{3,}-REQ-[A-Z-]+-\d{3})\b", re.M)


def git_changed_srs() -> list[Path]:
    base = os.getenv("GITHUB_BASE_REF")
    try:
        if base:
            subprocess.run(["git", "fetch", "origin", base], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=ROOT)
            cmd = ["git", "diff", "--name-only", f"origin/{base}...HEAD"]
        else:
            cmd = ["git", "diff", "--name-only", "HEAD~1", "HEAD"]
        out = subprocess.check_output(cmd, text=True, cwd=ROOT).strip().splitlines()
        files = [ROOT / p for p in out if p.startswith("docs/srs/") and p.endswith(".md")]
        # Skip templates and umbrella docs
        return [p for p in files if p.name not in {"core.md", "_template.md"}]
    except Exception:
        # Fallback: treat all as changed
        return [p for p in SRS_DIR.glob("FGC-REQ-*.md")]


def main() -> int:
    yaml = YAML(typ="safe")
    changed = git_changed_srs()
    if not changed:
        print("New SRS mapping check: no changed SRS files; OK")
        return 0

    if not TRACE.exists() or not MODMAP.exists():
        print("New SRS mapping check: required files missing: traceability/module map")
        return 2

    trace = yaml.load(TRACE.read_text(encoding="utf-8")) or {}
    modmap = yaml.load(MODMAP.read_text(encoding="utf-8")) or {}
    trace_ids = {str(ent.get("id")).strip() for ent in (trace.get("requirements") or []) if ent.get("id")}
    mod_ids: set[str] = set()
    for _, ids in (modmap or {}).items():
        if isinstance(ids, list):
            mod_ids.update([str(x) for x in ids])
        elif isinstance(ids, dict):
            # nested path maps
            for _, v in ids.items():
                if isinstance(v, list):
                    mod_ids.update([str(x) for x in v])

    errs: list[str] = []
    for path in sorted(changed):
        text = path.read_text(encoding="utf-8", errors="ignore")
        m = H1_ID.search(text)
        if not m:
            errs.append(f"{path}: missing requirement ID in H1")
            continue
        rid = m.group(1)
        # Focus on project-tracked FGC-REQ-*; ignore AGENT-REQ-* for modmap
        if rid.startswith("FGC-REQ-"):
            if rid not in trace_ids:
                errs.append(f"{rid}: not present in docs/traceability.yaml")
            if rid not in mod_ids:
                errs.append(f"{rid}: not present in docs/module-srs-map.yaml")

    if errs:
        print("New SRS mapping check failed:\n- " + "\n- ".join(errs))
        return 1

    print("New SRS mapping check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

