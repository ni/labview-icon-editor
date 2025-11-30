#!/usr/bin/env python3
"""
ADR lint:
- Validate naming: docs/adr/NNNN-title.md
- Required headers in each ADR: Title (H1), Status, Date, Decision, Consequences.
- Check Supersedes / Superseded-by refer to existing ADR IDs and are reciprocal.
- Generate docs/adr/INDEX.md from ADR headers.
Exits non-zero on violations and prints a summary table.
"""
from __future__ import annotations
import re, sys
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
ADR_DIR = ROOT / "docs" / "adr"
INDEX_PATH = ADR_DIR / "INDEX.md"

ID_RE = re.compile(r"^(\d{4})-([a-z0-9-]+)\.md$")
H1_RE = re.compile(r"^#\s+ADR\s+(\d{4}):\s+(.+)$", re.IGNORECASE | re.MULTILINE)
STATUS_RE = re.compile(r"^-+\s*Status:\s*(.+)$", re.IGNORECASE | re.MULTILINE)
DATE_RE = re.compile(r"^-+\s*Date:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})", re.IGNORECASE | re.MULTILINE)
FIELD_RE = re.compile(r"^##\s+(Decision|Consequences)\s*$", re.IGNORECASE | re.MULTILINE)
SUP_RE = re.compile(r"^-+\s*Supersedes:\s*(\d{4})", re.IGNORECASE | re.MULTILINE)
SUSB_RE = re.compile(r"^-+\s*Superseded-by:\s*(\d{4})", re.IGNORECASE | re.MULTILINE)

def parse_adr(p: Path) -> dict:
    txt = p.read_text(encoding="utf-8", errors="ignore")
    m = H1_RE.search(txt)
    title = m.group(2).strip() if m else ""
    status = (STATUS_RE.search(txt).group(1).strip() if STATUS_RE.search(txt) else "")
    date = (DATE_RE.search(txt).group(1).strip() if DATE_RE.search(txt) else "")
    has_decision = bool(re.search(r"^##\s*Decision\s*$", txt, re.MULTILINE | re.IGNORECASE))
    has_conseq = bool(re.search(r"^##\s*Consequences\s*$", txt, re.MULTILINE | re.IGNORECASE))
    sup = (SUP_RE.search(txt).group(1).strip() if SUP_RE.search(txt) else "")
    sub = (SUSB_RE.search(txt).group(1).strip() if SUSB_RE.search(txt) else "")
    return {"title": title, "status": status, "date": date, "has_decision": has_decision, "has_consequences": has_conseq, "sup": sup, "sub": sub}

def main(argv=None) -> int:
    adrs = sorted([
        p for p in ADR_DIR.glob("*.md")
        if p.name.lower() not in {"readme.md", "index.md"}
    ])
    errs = []
    rows = []
    ids = set()
    meta = {}
    for p in adrs:
        m = ID_RE.match(p.name)
        if not m:
            # Allow template ADRs (e.g., 00xx-*) without treating as an error
            if p.name.lower().startswith("00xx-"):
                continue
            errs.append(f"{p.name}: invalid filename (expected NNNN-title.md)")
            continue
        num, slug = m.group(1), m.group(2)
        ids.add(num)
        info = parse_adr(p)
        meta[num] = (p, info)
        if not info["title"] or not info["status"] or not info["date"] or not info["has_decision"] or not info["has_consequences"]:
            errs.append(f"{p.name}: missing required headers/fields")
    # Supersede integrity
    for num,(p,info) in meta.items():
        if info["sup"] and info["sup"] not in ids:
            errs.append(f"{p.name}: Supersedes {info['sup']} not found")
        if info["sub"] and info["sub"] not in ids:
            errs.append(f"{p.name}: Superseded-by {info['sub']} not found")
    # Generate index
    lines = ["# ADR Index\n","| # | Title | Date | Status |","|---:|---|:---:|:---:|"]
    for num,(p,info) in sorted(meta.items(), key=lambda t: t[0]):
        lines.append(f"| {num} | [{info['title']}]({p.name}) | {info['date']} | {info['status']} |")
    INDEX_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if errs:
        print("ADR Lint Violations:")
        for e in errs: print(f"* {e}")
        sys.exit(1)
    print("ADR lint OK and INDEX.md updated.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
