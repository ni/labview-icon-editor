#!/usr/bin/env python3
"""Parse pre-commit stdout/stderr into a small JSON summary.

Emits: {
  "failed_hooks": ["hook-id", ...],
  "lines": ["raw line", ...]
}
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def parse_lines(lines: list[str]) -> dict:
    failed: set[str] = set()
    header_re = re.compile(r"^(.+?)\.+(Failed|Passed|Skipped)$")
    id_re = re.compile(r"^\s*-\s*hook id:\s*([A-Za-z0-9_.-]+)\s*$")
    in_failed = False
    for ln in lines:
        m = header_re.match(ln.strip())
        if m:
            in_failed = (m.group(2) == "Failed")
            continue
        m2 = id_re.match(ln)
        if m2 and in_failed:
            failed.add(m2.group(1))
    return {"failed_hooks": sorted(failed), "lines": lines}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True, help="Path to pre-commit log file")
    ap.add_argument("--out", required=True, help="Output JSON path")
    args = ap.parse_args(argv)

    log_path = Path(args.log)
    out_path = Path(args.out)
    if not log_path.exists():
        print(f"log not found: {log_path}")
        return 1
    lines = [ln.rstrip("\n") for ln in log_path.read_text(encoding="utf-8", errors="ignore").splitlines()]
    data = parse_lines(lines)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

