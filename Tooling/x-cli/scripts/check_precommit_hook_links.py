#!/usr/bin/env python3
"""Verify pre-commit hook IDs have docs links.

Reads `.pre-commit-config.yaml` to collect hook IDs (excluding manual-only and
commit-msg hooks) and ensures each is mapped in `scripts/precommit_hook_links.json`.

Fails with a helpful message listing missing IDs.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from ruamel.yaml import YAML  # type: ignore
except Exception:  # pragma: no cover
    print("ruamel.yaml is required (pip install ruamel.yaml)")
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
PCFG = ROOT / ".pre-commit-config.yaml"
LINKS = ROOT / "scripts" / "precommit_hook_links.json"


def main() -> int:
    if not PCFG.exists():
        print(".pre-commit-config.yaml not found")
        return 1
    y = YAML(typ="safe")
    cfg = y.load(PCFG.read_text(encoding="utf-8")) or {}
    repos = cfg.get("repos") or []
    ids: set[str] = set()
    for r in repos:
        for h in (r.get("hooks") or []):
            hid = str(h.get("id") or "").strip()
            if not hid:
                continue
            stages = set(h.get("stages") or [])
            # Skip manual-only and commit-msg hooks
            if stages == {"manual"} or stages == ["manual"]:
                continue
            if "commit-msg" in stages:
                continue
            ids.add(hid)
    # Load mapping
    try:
        import json
        links = json.loads(LINKS.read_text(encoding="utf-8")) if LINKS.exists() else {}
    except Exception:
        links = {}
    mapped = set(links.keys())

    missing = sorted(id for id in ids if id not in mapped)
    if missing:
        print("Missing hook link mappings in scripts/precommit_hook_links.json:")
        for hid in missing:
            print(f"- {hid}: add a docs URL or script path")
        return 1
    print("Pre-commit hook link mappings: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

