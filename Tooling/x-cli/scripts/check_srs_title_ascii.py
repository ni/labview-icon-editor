#!/usr/bin/env python3
"""CI lint and optional fixer: enforce ASCII-only H1 titles for SRS files.

Rationale: Prevent Unicode (e.g., en/em dashes, smart quotes) in SRS H1 titles
to avoid encoding drift across platforms.

Modes:
- Lint (default): scan target files and fail if any non-ASCII is present in H1.
- Fix ("--fix"): rewrite only the H1 line by normalizing Unicode punctuation
  to ASCII equivalents.

Targets:
- If filenames are passed as args, restrict checks to those files.
- Otherwise, scan all Markdown files under docs/srs/ (excluding templates).

Exit codes: 0 OK, 1 violations, 2 usage error.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
SRS_DIR = ROOT / "docs" / "srs"

H1_RE = re.compile(r"^#\s+(.+)$", re.M)


MAP = {
    "\u2013": "-",   # en dash –
    "\u2014": "-",   # em dash —
    "\u2018": "'",  # left single quote ‘
    "\u2019": "'",  # right single quote ’
    "\u201C": '"',  # left double quote “
    "\u201D": '"',  # right double quote ”
    "\u2026": "...",  # ellipsis …
    "\u00A0": " ",   # nbsp
    "\u2194": "<->", # left-right arrow ↔
    "\u2192": "->",  # right arrow →
    "\u2190": "<-",  # left arrow ←
}


def all_srs_md() -> list[Path]:
    return sorted(SRS_DIR.rglob("*.md"))


def normalize_title_ascii(title: str) -> str:
    out = title
    for k, v in MAP.items():
        out = out.replace(k, v)
    # Best-effort strip remaining non-ASCII by replacing with '?'
    try:
        out.encode("ascii")
    except UnicodeEncodeError:
        out = out.encode("ascii", errors="replace").decode("ascii")
    # Collapse double spaces introduced by nbsp mapping
    out = re.sub(r"\s{2,}", " ", out).strip()
    return out


def is_ascii(s: str) -> bool:
    try:
        s.encode("ascii")
        return True
    except UnicodeEncodeError:
        return False


def pick_targets(argv: list[str]) -> list[Path]:
    files: list[Path] = []
    for a in argv:
        if a == "--fix":
            continue
        p = (ROOT / a) if not a.startswith("/") else Path(a)
        if p.is_file() and str(p).replace("\\", "/").startswith(str(SRS_DIR).replace("\\", "/")) and p.suffix.lower() == ".md":
            if p.name not in {"_template.md"}:
                files.append(p)
    if files:
        return sorted(set(files))
    return [p for p in all_srs_md() if p.name not in {"_template.md"}]


def main() -> int:
    argv = sys.argv[1:]
    fix = "--fix" in argv
    in_scope = pick_targets(argv)

    errs: list[str] = []
    changed: list[Path] = []
    for path in sorted(in_scope):
        text = path.read_text(encoding="utf-8", errors="ignore")
        m = H1_RE.search(text)
        if not m:
            continue  # let other linters handle missing H1
        title = m.group(1).strip()
        if not is_ascii(title):
            if fix:
                new = normalize_title_ascii(title)
                if new != title:
                    # Replace only the H1 line
                    start, end = m.span(1)
                    new_text = text[:start] + new + text[end:]
                    path.write_text(new_text, encoding="utf-8")
                    changed.append(path)
            else:
                errs.append(f"{path}: non-ASCII character(s) in H1 title -> {title!r}")

    if errs:
        print("SRS title ASCII check failed:\n- " + "\n- ".join(errs))
        # Bot suggestion for CI and local runs
        suggestion = "pre-commit run srs-title-ascii-fix --all-files"
        print("\nTo auto-fix SRS titles locally, run:\n  " + suggestion)
        if os.getenv("GITHUB_ACTIONS"):
            # GitHub Actions annotation (shows in logs as a notice)
            print(f"::notice title=Auto-fix SRS H1 titles::{suggestion}")
        return 1
    if fix and changed:
        for p in changed:
            print(f"fixed: {p}")
    print("SRS title ASCII check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
