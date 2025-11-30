#!/usr/bin/env python3
"""
Count SRS pages marked Status: Deprecated and optionally list them.

Outputs:
- default: human-friendly summary to stdout (non-blocking)
- --print-count: print just the integer count
- --list: print one item per line (path, ID, or "ID - Title")

Filters:
- --prefix <P> (deprecated; kept for backward compatibility) — include IDs that start with <P>
- --include-prefixes "P1,P2" — include only IDs whose domain starts with any listed prefix
- --exclude-prefixes "P3,P4" — exclude IDs whose domain starts with any listed prefix

Notes:
- Prefixes are case-insensitive domain portions like CI, QA, DEV, QA-ISO.
- Exit code is always 0 (informational helper).
"""
from __future__ import annotations
from pathlib import Path
import argparse
import re
import json

SRS_DIR = Path("docs/srs")
REQ_ID = re.compile(r"\b[A-Z]{3}-REQ-[A-Z-]+-\d{3}\b")

def section(text: str, header: str) -> str:
    m = re.search(rf"^## {re.escape(header)}\s*(.+?)(?=\n## |\Z)", text, re.S | re.M)
    return (m.group(1) if m else "").strip()

def is_deprecated(path: Path) -> bool:
    try:
        t = path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return False
    attrs = section(t, "Attributes")
    for ln in attrs.splitlines():
        if ":" in ln:
            k, v = ln.split(":", 1)
            if k.strip().lower() == "status":
                return v.strip().lower() == "deprecated"
    return False

def get_req_id(path: Path) -> str:
    """Return requirement ID by scanning file text; fallback to filename stem."""
    try:
        t = path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        t = ""
    m = REQ_ID.search(t)
    if m:
        return m.group(0)
    # Fallback: derive from filename like FGC-REQ-XYZ-123.md
    stem = path.stem
    return stem if REQ_ID.fullmatch(stem) else stem

def get_title(path: Path) -> str:
    """Return the human title from the first H1 heading. Fallback to filename stem."""
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                if line.startswith('# '):
                    h1 = line[2:].strip()
                    # Expected: "FGC-REQ-XYZ-123 - Title text"
                    if ' - ' in h1:
                        return h1.split(' - ', 1)[1].strip()
                    # If ID is present but no ' - ', remove ID prefix
                    m = REQ_ID.search(h1)
                    if m:
                        return h1.replace(m.group(0), '').strip(' -\u2014:') or h1
                    return h1
    except Exception:
        pass
    return path.stem

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--print-count", action="store_true", help="print count only")
    ap.add_argument("--list", action="store_true", help="list deprecated items")
    ap.add_argument("--ids", action="store_true", help="when used with --list, print pure requirement IDs instead of paths")
    ap.add_argument("--titles", action="store_true", help="when used with --list, print 'ID - Title' pairs")
    ap.add_argument("--prefix", type=str, default="", help="[deprecated] single include prefix (e.g., CI, QA, DEV, QA-ISO)")
    ap.add_argument("--include-prefixes", type=str, default="", help="comma-separated include prefixes (e.g., 'CI,QA-ISO')")
    ap.add_argument("--exclude-prefixes", type=str, default="", help="comma-separated exclude prefixes (e.g., 'DEV,SDK')")
    ap.add_argument("--discover-domains", action="store_true", help="print one domain per line discovered in filtered set and exit")
    ap.add_argument("--discover-domains-csv", action="store_true", help="print comma-separated domains discovered in filtered set and exit")
    ap.add_argument("--json", action="store_true", help="print JSON with filters, count, domains, and items (id, title, path, mtime)")
    ap.add_argument("--limit", type=int, default=0, help="limit list outputs to N entries")
    ap.add_argument(
        "--sort",
        type=str,
        default="id",
        help="sort order: 'id' (default), 'mtime'/'lastmodified' (newest first), 'mtime-asc' (oldest first)"
    )
    args = ap.parse_args()

    pages = sorted(SRS_DIR.glob("FGC-REQ-*.md"))
    deprecated = [p for p in pages if is_deprecated(p)]
    items = deprecated

    def canon_list(txt: str) -> list[str]:
        out: list[str] = []
        for part in (txt or "").split(','):
            raw = part.strip()
            if not raw:
                continue
            # Normalize to uppercase domain and add full prefix
            pfx = "FGC-REQ-" + raw.upper()
            if not pfx.endswith("-"):
                pfx += "-"
            out.append(pfx)
        return out

    include = canon_list(args.include_prefixes)
    # Back-compat: --prefix adds to include set
    if args.prefix.strip():
        include.append(canon_list(args.prefix)[0])
    exclude = canon_list(args.exclude_prefixes)

    if include:
        items = [p for p in items if any(get_req_id(p).upper().startswith(pref) for pref in include)]
    if exclude:
        items = [p for p in items if not any(get_req_id(p).upper().startswith(pref) for pref in exclude)]

    # Apply sorting
    sort_mode = (args.sort or "id").strip().lower()
    def _safe_mtime(path: Path) -> float:
        try:
            return path.stat().st_mtime
        except Exception:
            return 0.0
    if sort_mode in ("id",):
        items = sorted(items, key=lambda p: get_req_id(p))
    elif sort_mode in ("mtime", "lastmodified", "mtime-desc"):
        items = sorted(items, key=_safe_mtime, reverse=True)
    elif sort_mode in ("mtime-asc", "lastmodified-asc"):
        items = sorted(items, key=_safe_mtime, reverse=False)
    else:
        # Unknown sort: keep current order
        pass

    # Domain discovery (for CI summary grouping)
    # Discover unique domains in current set
    seen = []
    for p in items:
        rid = get_req_id(p)
        m = re.match(r"^[A-Z]{3}-REQ-([A-Z-]+)-\d{3}$", rid)
        dom = m.group(1) if m else "UNKNOWN"
        if dom not in seen:
            seen.append(dom)

    if args.discover_domains:
        for d in seen:
            print(d)
        return 0
    if args.discover_domains_csv:
        print(",".join(seen))
        return 0
    if args.json:
        payload = {
            "filters": {
                "include_prefixes": include,
                "exclude_prefixes": exclude,
                "sort": sort_mode,
            },
            "count": len(items),
            "domains": seen,
            "items": [
                {
                    "id": get_req_id(p),
                    "title": get_title(p),
                    "path": str(p),
                    "mtime": _safe_mtime(p),
                }
                for p in items
            ],
        }
        print(json.dumps(payload, ensure_ascii=False))
        return 0
    if args.print_count:
        print(len(items))
        return 0

    limit = args.limit if args.limit and args.limit > 0 else None
    def iter_limited(seq):
        if limit is None:
            return seq
        return seq[:limit]

    if args.list:
        if args.titles:
            for p in iter_limited(items):
                rid = get_req_id(p)
                title = get_title(p)
                print(f"{rid} - {title}")
        elif args.ids:
            for p in iter_limited(items):
                print(get_req_id(p))
        else:
            for p in iter_limited(items):
                print(str(p))
        return 0

    print(f"Deprecated SRS pages detected: {len(deprecated)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
