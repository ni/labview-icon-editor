#!/usr/bin/env python3
"""Generate §8.10 test execution log summarizing notable events and impacts."""

from __future__ import annotations

import argparse
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Tuple

from rtm_utils import ROOT

REPORTS_DIR = ROOT / "reports"
DEFAULT_RUN_ID = "local"


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build_events(env: dict) -> List[Tuple[str, str, str, str]]:
    """Return list of (uid, timestamp, description, impact/outcome)."""
    ts = utc_now()
    mapping = [
        ("EXEC-RTM-VALIDATE", "RTM path validation", env.get("RTM_VALIDATE", "") or "unknown"),
        ("EXEC-RTM-COVERAGE", "RTM coverage thresholds", env.get("RTM_COVERAGE", "") or "unknown"),
        ("EXEC-TCS", "Test case spec generation", env.get("GENERATE_TCS", "") or "unknown"),
        ("EXEC-DATA", "Test data readiness", env.get("DATA_READINESS", "") or "unknown"),
        ("EXEC-ENV", "Test environment readiness", env.get("ENV_READINESS", "") or "unknown"),
        ("EXEC-ADR-LINT", "ADR/agent language lint", env.get("ADR_LINT", "") or "unknown"),
        ("EXEC-LINKCHECK", "Docs link check", env.get("LINKCHECK", "") or "unknown"),
    ]
    events: List[Tuple[str, str, str, str]] = []
    for uid, desc, outcome in mapping:
        impact = "Blocks merge when failure" if outcome != "success" else "No impact"
        events.append((uid, ts, desc, f"{outcome}: {impact}"))
    return events


def generate(run_id: str, env: dict) -> Path:
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORTS_DIR / f"test-execution-log-{run_id}.md"
    events = build_events(env)
    lines: List[str] = []
    lines.append("# Test Execution Log (ISO/IEC/IEEE 29119-3 §8.10)")
    lines.append("")
    lines.append(f"- UID: `TEST-EXEC-LOG-{run_id}`")
    lines.append(f"- Generated: {utc_now()}")
    lines.append(f"- Run ID: `{run_id}`")
    lines.append("")
    lines.append("| UID | Timestamp (UTC) | Description | Outcome / Impact |")
    lines.append("| --- | --- | --- | --- |")
    for uid, ts, desc, impact in events:
        lines.append(f"| {uid} | {ts} | {desc} | {impact} |")
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate test execution log.")
    parser.add_argument("--run-id", default=os.getenv("GITHUB_RUN_ID", DEFAULT_RUN_ID))
    args = parser.parse_args()
    env = {
        "RTM_VALIDATE": os.getenv("RTM_VALIDATE", ""),
        "RTM_COVERAGE": os.getenv("RTM_COVERAGE", ""),
        "GENERATE_TCS": os.getenv("GENERATE_TCS", ""),
        "DATA_READINESS": os.getenv("DATA_READINESS", ""),
        "ENV_READINESS": os.getenv("ENV_READINESS", ""),
        "ADR_LINT": os.getenv("ADR_LINT", ""),
        "LINKCHECK": os.getenv("LINKCHECK", ""),
    }
    path = generate(args.run_id or DEFAULT_RUN_ID, env)
    print(f"Wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
