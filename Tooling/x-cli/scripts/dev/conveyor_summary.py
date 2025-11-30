#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any
import sys


def _import_helpers() -> tuple[Any, Any]:
    here = Path(__file__).resolve().parent
    sys.path.insert(0, str(here))
    import summarize_multi_repo as sm
    import summarize_monitor_delegate as sd

    return sm, sd


def _parse_ts(s: str | None):
    if not s or not isinstance(s, str):
        return None
    try:
        from datetime import datetime
        ss = s.replace("Z", "+00:00")
        return datetime.fromisoformat(ss)
    except Exception:
        return None


def _pick_overall_fallback(multi: dict[str, Any], monitor: dict[str, Any]) -> dict[str, Any] | None:
    m = multi.get("fallback_last") if isinstance(multi, dict) else None
    d = monitor.get("fallback_last") if isinstance(monitor, dict) else None
    if not m and not d:
        return None
    tm = _parse_ts(m.get("timestamp")) if isinstance(m, dict) else None
    td = _parse_ts(d.get("timestamp")) if isinstance(d, dict) else None
    pick = None
    src = None
    if tm and td:
        if tm >= td:
            pick = m; src = "multi"
        else:
            pick = d; src = "monitor"
    elif tm:
        pick = m; src = "multi"
    else:
        pick = d; src = "monitor"
    if not isinstance(pick, dict):
        return None
    out = {
        "source": src,
        "timestamp": pick.get("timestamp"),
        "requested": pick.get("requested"),
        "effective": pick.get("effective"),
        "attempts": pick.get("attempts"),
    }
    return out


def build_json(multi_path: Path, monitor_path: Path, count: int) -> dict[str, Any]:
    sm, sd = _import_helpers()
    multi_items = sm.load_history(multi_path)
    monitor_items = sd.load_history(monitor_path)
    multi = sm.to_json_summary(multi_items, multi_path, count)
    monitor = sd.to_json_summary(monitor_items, monitor_path, count)
    overall = _pick_overall_fallback(multi, monitor)
    return {
        "multi": multi,
        "monitor": monitor,
        "fallback_last_overall": overall,
    }


from datetime import datetime, timezone


def _fmt_relative(delta_seconds: float) -> str:
    if delta_seconds < 0:
        delta_seconds = 0
    secs = int(delta_seconds)
    if secs < 60:
        return f"{secs}s ago"
    mins = secs // 60
    if mins < 60:
        return f"{mins}m ago"
    hrs = mins // 60
    if hrs < 24:
        return f"{hrs}h ago"
    days = hrs // 24
    return f"{days}d ago"


def _format_ts(ts: str | None, mode: str) -> str:
    dt = _parse_ts(ts)
    if not dt:
        return ts or "?"
    if mode == "utc":
        return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if mode == "relative":
        now = datetime.now(timezone.utc)
        dt_utc = dt.astimezone(timezone.utc)
        return _fmt_relative((now - dt_utc).total_seconds())
    # local/default
    try:
        local = dt.astimezone()
    except Exception:
        local = dt
    return local.strftime("%Y-%m-%d %H:%M:%S")


def build_markdown(multi_path: Path, monitor_path: Path, count: int, timefmt: str = "local") -> str:
    sm, sd = _import_helpers()
    multi_items = sm.load_history(multi_path)
    monitor_items = sd.load_history(monitor_path)
    multi_md = sm.to_markdown(multi_items, multi_path, count)
    monitor_md = sd.to_markdown(monitor_items, monitor_path, count)
    multi = sm.to_json_summary(multi_items, multi_path, count)
    monitor = sd.to_json_summary(monitor_items, monitor_path, count)
    overall = _pick_overall_fallback(multi, monitor)

    lines: list[str] = []
    lines.append("# Conveyor Summary")
    lines.append("")
    if overall:
        lines.append("## Fallback (Overall)")
        req = overall.get("requested", "?")
        eff = overall.get("effective", "?")
        src = overall.get("source", "?")
        ts = _format_ts(overall.get("timestamp"), timefmt)
        at = overall.get("attempts") or []
        exits = ", ".join(f"{a.get('ref','?')}={a.get('exit','?')}" for a in at if isinstance(a, dict)) or "n/a"
        lines.append("")
        lines.append(f"- {ts} | requested: {req} -> effective: {eff} (source: {src}; attempts: {exits})")
        lines.append("")

    lines.append("## Multi-Repo Orchestration")
    mfl = multi.get("fallback_last") if isinstance(multi, dict) else None
    if mfl:
        at = mfl.get("attempts") or []
        exits = ", ".join(f"{a.get('ref','?')}={a.get('exit','?')}" for a in at if isinstance(a, dict)) or "n/a"
        ts = _format_ts(mfl.get("timestamp"), timefmt)
        lines.append(f"- {ts} | last fallback: {mfl.get('requested','?')} -> {mfl.get('effective','?')} (attempts: {exits})")
        lines.append("")
    lines.append(multi_md.rstrip())
    lines.append("")
    lines.append("## Monitor Delegate")
    dfl = monitor.get("fallback_last") if isinstance(monitor, dict) else None
    if dfl:
        at2 = dfl.get("attempts") or []
        exits2 = ", ".join(f"{a.get('ref','?')}={a.get('exit','?')}" for a in at2 if isinstance(a, dict)) or "n/a"
        ts2 = _format_ts(dfl.get("timestamp"), timefmt)
        lines.append(f"- {ts2} | last fallback: {dfl.get('requested','?')} -> {dfl.get('effective','?')} (attempts: {exits2})")
        lines.append("")
    # Guard status (last triggered)
    guard_last = None
    for e in reversed(monitor_items):
        g = e.get('guard') if isinstance(e, dict) else None
        if isinstance(g, dict) and g.get('triggered'):
            guard_last = {
                'timestamp': e.get('timestamp'),
                'level': g.get('level'),
                'message': g.get('message')
            }
            break
    if guard_last:
        ts3 = _format_ts(guard_last.get('timestamp'), timefmt)
        lines.append(f"- {ts3} | guard: {guard_last.get('level','?')} — {guard_last.get('message','?')}")
        lines.append("")
    lines.append(monitor_md.rstrip())
    lines.append("")
    # Latest Smoke (if last orchestrator snapshot exists)
    try:
        last_orch = Path("artifacts/last-orchestrator.json")
        if last_orch.exists():
            data = json.loads(last_orch.read_text(encoding="utf-8"))
            ts = _format_ts(data.get("ended") or data.get("started"), timefmt)
            status = data.get("status","unknown")
            ref = data.get("ref","?")
            xsdk_ref = data.get("xsdk_ref","?")
            delegator_url = None
            for s in data.get("steps",[]) or []:
                if isinstance(s, dict) and s.get("name") == "x-sdk/delegator":
                    dd = s.get("data") or {}
                    delegator_url = dd.get("url")
                    break
            lines.append("## Latest Smoke")
            lines.append("")
            bullet = f"- {ts} | status: {status} | xcli_ref: {ref} | xsdk_ref: {xsdk_ref}"
            if delegator_url:
                bullet += f" | delegator: {delegator_url}"
            lines.append(bullet)
            lines.append("")
    except Exception:
        pass
    # Footer with generation timestamp, timefmt mode, and entry counts
    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        now_fmt = _format_ts(now_iso, timefmt)
    except Exception:
        now_fmt = "?"
    lines.append("---")
    multi_total = len(multi_items)
    mon_total = len(monitor_items)
    recent_multi = min(count, multi_total) if count > 0 else multi_total
    recent_mon = min(count, mon_total) if count > 0 else mon_total
    lines.append(
        f"Generated at: {now_fmt} (timefmt: {timefmt}) | entries summarized: multi {recent_multi}/{multi_total}, monitor {recent_mon}/{mon_total}"
    )
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--multi", type=Path, default=Path("artifacts/multi-repo-run.history.jsonl"))
    ap.add_argument("--monitor", type=Path, default=Path("artifacts/monitor-delegate.history.jsonl"))
    ap.add_argument("--count", type=int, default=10)
    ap.add_argument("--out", type=Path, default=Path("artifacts/conveyor-summary.md"))
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--timefmt", choices=["local","utc","relative"], default="local")
    args = ap.parse_args()

    if args.json:
        out_obj = build_json(args.multi, args.monitor, args.count)
        print(json.dumps(out_obj, indent=2))
        return 0

    md = build_markdown(args.multi, args.monitor, args.count, args.timefmt)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(md, encoding="utf-8")
    print(f"Wrote consolidated summary: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
