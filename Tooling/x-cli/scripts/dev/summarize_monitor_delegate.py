#!/usr/bin/env python3
"""
Summarize monitor-delegate history (JSONL) into JSON or Markdown.

History entries (per monitor-delegate.ps1) contain fields like:
  - timestamp, branch, xcli_ref, pr, merged_at
  - delegator: { id, url, status, conclusion } | null
  - orchestrator: { mode, status, ref, steps:[{name,status,data?}] } | null

Usage examples:
  - JSON: python scripts/dev/summarize_monitor_delegate.py --json
  - Markdown file:
      python scripts/dev/summarize_monitor_delegate.py \
        --out artifacts/monitor-delegate.summary.md
"""
from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


def load_history(path: Path) -> list[dict[str, Any]]:
    """Load history supporting both JSONL (one object per line) and multi-line JSON objects."""
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    items: list[dict[str, Any]] = []
    # First try strict JSONL
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        try:
            obj = json.loads(s)
        except Exception:
            obj = None
        if isinstance(obj, dict):
            items.append(obj)
    if items:
        return items

    # Fallback: multi-line objects concatenated
    buf: list[str] = []
    depth = 0
    in_str = False
    esc = False
    def flush_buf():
        nonlocal buf
        raw = "".join(buf).strip()
        if raw:
            try:
                obj2 = json.loads(raw)
                if isinstance(obj2, dict):
                    items.append(obj2)
            except Exception:
                pass
        buf = []

    for ch in text:
        buf.append(ch)
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    flush_buf()
    # Any trailing buffer
    flush_buf()
    return items


def aggregate(items: list[dict[str, Any]]) -> dict[str, Any]:
    delegator_counts: Counter[str] = Counter()
    orchestrator_counts: Counter[str] = Counter()
    step_counts: dict[str, Counter[str]] = defaultdict(Counter)

    for e in items:
        d = e.get("delegator")
        if isinstance(d, dict):
            conclusion = str(d.get("conclusion", "unknown")).lower()
            delegator_counts[conclusion] += 1
        else:
            delegator_counts["none"] += 1

        o = e.get("orchestrator")
        if isinstance(o, dict):
            status = str(o.get("status", "unknown")).lower()
            orchestrator_counts[status] += 1
            steps = o.get("steps")
            if isinstance(steps, list):
                for s in steps:
                    if not isinstance(s, dict):
                        continue
                    name = str(s.get("name", "(step)"))
                    st = str(s.get("status", "unknown")).lower()
                    step_counts[name][st] += 1
        else:
            orchestrator_counts["none"] += 1

    step_agg = [
        {
            "name": name,
            "statuses": [{"status": k, "count": v} for k, v in sorted(cnt.items(), key=lambda kv: kv[0])],
        }
        for name, cnt in sorted(step_counts.items(), key=lambda kv: kv[0])
    ]

    return {
        "delegator": [{"conclusion": k, "count": v} for k, v in sorted(delegator_counts.items(), key=lambda kv: kv[0])],
        "orchestrator": [{"status": k, "count": v} for k, v in sorted(orchestrator_counts.items(), key=lambda kv: kv[0])],
        "steps": step_agg,
    }


def _find_last_fallback(items: list[dict[str, Any]]) -> dict[str, Any] | None:
    for e in reversed(items):
        o = e.get("orchestrator") or {}
        if not isinstance(o, dict):
            continue
        steps = o.get("steps") or []
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
                        "timestamp": e.get("timestamp"),
                        "requested": data.get("xsdk_ref_requested"),
                        "effective": data.get("xsdk_ref_effective"),
                        "attempts": at_slim,
                    }
    return None


def to_json_summary(items: list[dict[str, Any]], path: Path, count: int) -> dict[str, Any]:
    recent = items[-count:] if count > 0 else items[:]
    agg = aggregate(items)
    last = items[-1] if items else {}
    return {
        "path": str(path),
        "total": len(items),
        "last_pr": last.get("pr"),
        "last_timestamp": last.get("timestamp"),
        "aggregate": agg,
        "recent": recent,
        "fallback_last": _find_last_fallback(items),
    }


def to_markdown(items: list[dict[str, Any]], path: Path, count: int) -> str:
    recent = items[-count:] if count > 0 else items[:]
    agg = aggregate(items)
    lines: list[str] = []
    lines.append("# Monitor Delegate Summary")
    lines.append("")
    lines.append(f"Source: `{path}`")
    lines.append("")

    # Delegator aggregate
    lines.append("## Delegator Aggregate")
    for entry in agg["delegator"]:
        lines.append(f"- {entry['conclusion']}: {entry['count']}")
    lines.append("")

    # Orchestrator aggregate
    lines.append("## Orchestrator Aggregate")
    for entry in agg["orchestrator"]:
        lines.append(f"- {entry['status']}: {entry['count']}")
    lines.append("")

    # Step aggregates
    if agg["steps"]:
        lines.append("## Orchestrator Steps (aggregate)")
        for s in agg["steps"]:
            lines.append(f"- {s['name']}")
            for kv in s["statuses"]:
                lines.append(f"  - {kv['status']}: {kv['count']}")
        lines.append("")

    # Recent
    lines.append(f"## Recent ({len(recent)})")
    for e in recent:
        ts = e.get("timestamp", "(n/a)")
        pr = e.get("pr")
        d = e.get("delegator") or {}
        d_conc = d.get("conclusion") or "none"
        o = e.get("orchestrator") or {}
        o_status = o.get("status") or "none"
        lines.append(f"- {ts} | PR {pr} | delegator: {d_conc} | orchestrator: {o_status}")
        steps = o.get("steps") or []
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
                        exits: list[str] = []
                        if isinstance(attempts, list):
                            for a in attempts:
                                if isinstance(a, dict):
                                    exits.append(f"{a.get('ref','?')}={a.get('exit','?')}")
                        exits_str = ', '.join(exits) if exits else 'n/a'
                        lines.append(f"    note: fallback {req} -> {eff}; attempts: {exits_str}")

    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--history", type=Path, default=Path("artifacts/monitor-delegate.history.jsonl"))
    ap.add_argument("--count", type=int, default=10)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    items = load_history(args.history)
    if args.json:
        print(json.dumps(to_json_summary(items, args.history, args.count), indent=2))
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
