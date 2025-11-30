#!/usr/bin/env python3
"""
Summarize multi-repo orchestration history (JSONL) into JSON or Markdown.

Usage examples:
  - JSON to stdout (default recent=10):
      python scripts/dev/summarize_multi_repo.py --json \
        --history artifacts/multi-repo-run.history.jsonl

  - Markdown summary file:
      python scripts/dev/summarize_multi_repo.py \
        --history artifacts/multi-repo-run.history.jsonl \
        --out artifacts/multi-repo-run.summary.md
"""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


def load_history(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    items: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        if isinstance(obj, dict):
            items.append(obj)
    return items


def _find_last_fallback(items: list[dict[str, Any]]) -> dict[str, Any] | None:
    for e in reversed(items):
        steps = e.get("steps") or []
        if not isinstance(steps, list):
            continue
        for s in steps:
            if not isinstance(s, dict):
                continue
            if s.get("name") == "x-sdk/delegator":
                data = s.get("data") or {}
                if isinstance(data, dict) and data.get("fallback_used"):
                    attempts = data.get("attempts") if isinstance(data.get("attempts"), list) else []
                    at_slim: list[dict[str, Any]] = []
                    for a in attempts:
                        if isinstance(a, dict):
                            at_slim.append({"ref": a.get("ref"), "exit": a.get("exit")})
                    return {
                        "timestamp": e.get("ended") or e.get("started"),
                        "requested": data.get("xsdk_ref_requested"),
                        "effective": data.get("xsdk_ref_effective"),
                        "attempts": at_slim,
                    }
    return None


def to_json_summary(items: list[dict[str, Any]], path: Path, count: int) -> dict[str, Any]:
    recent = items[-count:] if count > 0 else items[:]
    status_counts = Counter((str(i.get("status", "unknown")).lower() for i in items))
    aggregate = [
        {"status": k, "count": v} for k, v in sorted(status_counts.items(), key=lambda kv: kv[0])
    ]
    return {
        "path": str(path),
        "total": len(items),
        "aggregate": aggregate,
        "recent": recent,
        "fallback_last": _find_last_fallback(items),
    }


def to_markdown(items: list[dict[str, Any]], path: Path, count: int) -> str:
    recent = items[-count:] if count > 0 else items[:]
    status_counts = Counter((str(i.get("status", "unknown")).lower() for i in items))
    lines: list[str] = []
    lines.append("# Multi-Repo Orchestration Summary")
    lines.append("")
    lines.append(f"Source: `{path}`")
    lines.append("")
    if status_counts:
        lines.append("## Aggregate Status")
        for k in sorted(status_counts):
            lines.append(f"- {k}: {status_counts[k]}")
        lines.append("")
    lines.append(f"## Recent ({len(recent)})")
    for e in recent:
        ts = e.get("ended") or e.get("started") or "(n/a)"
        status = e.get("status", "unknown")
        mode = e.get("mode", "n/a")
        duration = e.get("duration_seconds")
        dur = f"{duration:.2f}s" if isinstance(duration, (int, float)) else "n/a"
        lines.append(f"- {ts} | status: {status} | mode: {mode} | duration: {dur}")
        steps = e.get("steps") or []
        if isinstance(steps, list):
            for s in steps:
                if not isinstance(s, dict):
                    continue
                name = s.get('name', '(step)')
                status = s.get('status', 'unknown')
                lines.append(f"  - {name}: {status}")
                if name == 'x-sdk/delegator':
                    data = s.get('data') or {}
                    if isinstance(data, dict) and data.get('fallback_used'):
                        req = data.get('xsdk_ref_requested', '?')
                        eff = data.get('xsdk_ref_effective', '?')
                        attempts = data.get('attempts') or []
                        exits = []
                        if isinstance(attempts, list):
                            for a in attempts:
                                if isinstance(a, dict):
                                    exits.append(str(a.get('ref', '?')) + '=' + str(a.get('exit', '?')))
                        exits_str = ', '.join(exits) if exits else 'n/a'
                        lines.append(f"    note: fallback {req} -> {eff}; attempts: {exits_str}")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--history", type=Path, default=Path("artifacts/multi-repo-run.history.jsonl"))
    ap.add_argument("--count", type=int, default=10)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    items = load_history(args.history)
    if args.json:
        out_obj = to_json_summary(items, args.history, args.count)
        print(json.dumps(out_obj, indent=2))
        return 0

    md = to_markdown(items, args.history, args.count)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(md, encoding="utf-8")
        print(f"Wrote Markdown summary: {args.out}")
    else:
        print(md)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
