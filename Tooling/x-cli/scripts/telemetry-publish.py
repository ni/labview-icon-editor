#!/usr/bin/env python3
"""Publish telemetry summary with Discord notification and diff history.

Reimplements the PowerShell telemetry-publish.ps1 logic in Python for
cross-platform testing. Stage 3 requires a valid Discord webhook.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
from pathlib import Path
import urllib.request


def _read_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-Current", required=True, help="Path to current telemetry summary")
    parser.add_argument("-Discord", default="", help="Webhook URL for Discord (required in Stage 3)")
    parser.add_argument("-HistoryDir", default="./telemetry/history")
    parser.add_argument("-Manifest", default="./telemetry/manifest.json")
    parser.add_argument("-RetentionDays", type=int, default=90)
    parser.add_argument("-DryRun", action="store_true")
    parser.add_argument("-WhatIf", action="store_true")
    parser.add_argument("-ForceDryRun", action="store_true")
    args = parser.parse_args()

    current = Path(args.Current)
    if not current.exists():
        raise FileNotFoundError(f"Telemetry summary not found: {current}")

    history_dir = Path(args.HistoryDir)
    history_dir.mkdir(parents=True, exist_ok=True)

    curr = _read_json(current)
    if curr is None:
        raise ValueError(f"Current summary is not valid JSON: {current}")

    summaries = sorted(history_dir.glob("summary-*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    prev = _read_json(summaries[0]) if summaries else None
    baseline = prev is None

    manifest_path = Path(args.Manifest)
    commit = run_id = None
    if manifest_path.exists():
        manifest = _read_json(manifest_path) or {}
        run_info = manifest.get("run", {})
        commit = run_info.get("commit")
        run_id = run_info.get("run_id")
    commit = commit or os.environ.get("GITHUB_SHA")
    run_id = run_id or os.environ.get("GITHUB_RUN_ID")

    def _to_str(v):
        return "n/a" if v is None else str(v)

    def _delta(curr_v, prev_v, label: str | None = None) -> str:
        if not baseline and isinstance(curr_v, (int, float)) and isinstance(prev_v, (int, float)):
            delta = float(curr_v) - float(prev_v)
            if label == "duration_seconds":
                return f" (Δ {delta:0.0#}s)"
            return f" (Δ {delta})"
        return ""

    curr_pass = curr.get("pass")
    curr_fail = curr.get("fail")
    curr_skip = curr.get("skipped")
    curr_dur = curr.get("duration_seconds")

    prev_pass = prev.get("pass") if prev else None
    prev_fail = prev.get("fail") if prev else None
    prev_skip = prev.get("skipped") if prev else None
    prev_dur = prev.get("duration_seconds") if prev else None

    lines = [":white_check_mark: **X-CLI CI Summary**"]
    if run_id or commit:
        if os.environ.get("GITHUB_SERVER_URL") and os.environ.get("GITHUB_REPOSITORY") and run_id:
            run_url = f"{os.environ['GITHUB_SERVER_URL']}/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{run_id}"
            lines.append(f"**run:** {run_id}   **commit:** {commit}   **url:** {run_url}")
        else:
            lines.append(f"`run:` {run_id}   `commit:` {commit}")
    if baseline:
        lines.append("**Baseline established.** No previous telemetry to compare.")
    else:
        lines.append("**Comparison vs previous:**")

    lines.append(f"- pass: {_to_str(curr_pass)}{_delta(curr_pass, prev_pass)}")
    lines.append(f"- fail: {_to_str(curr_fail)}{_delta(curr_fail, prev_fail)}")
    lines.append(f"- skipped: {_to_str(curr_skip)}{_delta(curr_skip, prev_skip)}")
    dur_suffix = ""
    try:
        if isinstance(curr_dur, (int, float)):
            dur_suffix = f" ({float(curr_dur):0.0#}s)"
    except Exception:
        dur_suffix = ""
    lines.append(
        f"- duration_seconds: {_to_str(curr_dur)}{dur_suffix}{_delta(curr_dur, prev_dur, 'duration_seconds')}"
    )

    msg = "\n".join(lines)

    dry_run = (
        args.DryRun
        or args.WhatIf
        or args.ForceDryRun
        or not args.Discord
        or os.environ.get("DRY_RUN") in {"true", "1"}
    )
    if dry_run:
        print("Dry-run: not posting to Discord. Message output below:")
        print(msg)
    else:
        data = json.dumps({"content": msg}).encode("utf-8")
        req = urllib.request.Request(args.Discord, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req):
            pass
        print("Posted summary to Discord.")

    ts = _dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    summary_dest = history_dir / f"summary-{ts}.json"
    summary_text = current.read_text(encoding="utf-8")
    summary_dest.write_text(summary_text, encoding="utf-8")
    (history_dir / "summary-latest.json").write_text(summary_text, encoding="utf-8")

    diff = {
        "run_id": run_id,
        "commit": commit,
        "ts": ts,
        "baseline": baseline,
        "metrics": {
            "pass": curr_pass,
            "fail": curr_fail,
            "skipped": curr_skip,
            "duration_seconds": curr_dur,
        },
    }
    if not baseline:
        diff["metrics"].update(
            {
                "prev_pass": prev_pass,
                "prev_fail": prev_fail,
                "prev_skipped": prev_skip,
                "prev_duration_seconds": prev_dur,
                "delta_pass": (curr_pass - prev_pass) if isinstance(curr_pass, (int, float)) and isinstance(prev_pass, (int, float)) else None,
                "delta_fail": (curr_fail - prev_fail) if isinstance(curr_fail, (int, float)) and isinstance(prev_fail, (int, float)) else None,
                "delta_skipped": (curr_skip - prev_skip) if isinstance(curr_skip, (int, float)) and isinstance(prev_skip, (int, float)) else None,
                "delta_duration_seconds": (curr_dur - prev_dur) if isinstance(curr_dur, (int, float)) and isinstance(prev_dur, (int, float)) else None,
            }
        )

    diff_path = history_dir / f"diff-{ts}.json"
    diff_path.write_text(json.dumps(diff), encoding="utf-8")
    (history_dir / "diff-latest.json").write_text(diff_path.read_text(encoding="utf-8"), encoding="utf-8")

    cutoff = _dt.datetime.utcnow() - _dt.timedelta(days=args.RetentionDays)
    for p in history_dir.glob("summary-*.json"):
        if _dt.datetime.utcfromtimestamp(p.stat().st_mtime) < cutoff:
            p.unlink()
    for p in history_dir.glob("diff-*.json"):
        if _dt.datetime.utcfromtimestamp(p.stat().st_mtime) < cutoff:
            p.unlink()


if __name__ == "__main__":
    main()
