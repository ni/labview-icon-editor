#!/usr/bin/env python3
"""Sync pre-commit templates into this repo (idempotent).

1) Ensure the standard comment sits above the local hooks list in
   `.pre-commit-config.yaml`.
2) Merge default hook link mappings from the template into
   `scripts/precommit_hook_links.json` without overwriting existing keys.

Safe to run repeatedly; prints a short summary of changes.
Use --dry-run to only report pending changes and exit non-zero if any are needed.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PCFG = ROOT / ".pre-commit-config.yaml"
COMMENT_TPL = (ROOT / "scripts" / "templates" / "precommit_local_comment.txt").read_text(encoding="utf-8").rstrip()
LINKS_PATH = ROOT / "scripts" / "precommit_hook_links.json"
LINKS_TPL_PATH = ROOT / "scripts" / "templates" / "precommit_hook_links.template.json"


def ensure_comment_above_local_hooks(dry_run: bool = False) -> bool:
    if not PCFG.exists():
        return False
    lines = PCFG.read_text(encoding="utf-8").splitlines()
    out = []
    inserted = False
    i = 0
    while i < len(lines):
        out.append(lines[i])
        # Find the "- repo: local" line and the next "hooks:" line
        if lines[i].strip().startswith("- repo:") and "local" in lines[i]:
            # Copy following lines and look for hooks:
            j = i + 1
            while j < len(lines) and not lines[j].strip().startswith("hooks:"):
                out.append(lines[j])
                j += 1
            if j < len(lines) and lines[j].strip().startswith("hooks:"):
                # Before writing hooks:, ensure the comment exists immediately above
                prev_block = "\n".join(out[-3:])
                if COMMENT_TPL not in "\n".join(lines[max(0, j-5):j]):
                    out.append(COMMENT_TPL)
                    inserted = True
                out.append(lines[j])
                i = j + 1
                continue
        i += 1
    if inserted and not dry_run:
        PCFG.write_text("\n".join(out) + "\n", encoding="utf-8")
    return inserted


def merge_hook_links(dry_run: bool = False) -> list[str]:
    try:
        tpl = json.loads(LINKS_TPL_PATH.read_text(encoding="utf-8"))
    except Exception:
        tpl = {}
    existing = {}
    if LINKS_PATH.exists():
        try:
            existing = json.loads(LINKS_PATH.read_text(encoding="utf-8"))
        except Exception:
            existing = {}
    added = []
    merged = dict(existing)
    for k, v in tpl.items():
        if k not in merged:
            merged[k] = v
            added.append(k)
    if (added or not LINKS_PATH.exists()) and not dry_run:
        LINKS_PATH.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return added


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="Report needed changes and exit non-zero if any")
    args = ap.parse_args()

    ins = ensure_comment_above_local_hooks(dry_run=args.dry_run)
    added = merge_hook_links(dry_run=args.dry_run)
    msgs = []
    if ins:
        msgs.append("inserted local hooks comment")
    if added:
        msgs.append("added link(s): " + ", ".join(added))
    if args.dry_run and (ins or added):
        print("pre-commit template sync needed: " + "; ".join(msgs))
        return 1
    print("sync ok" + (" (" + "; ".join(msgs) + ")" if msgs else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
