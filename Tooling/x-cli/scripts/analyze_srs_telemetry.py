#!/usr/bin/env python3
# ModuleIndex: builds SRS telemetry aggregates for dashboards.
"""Analyze SRS omission telemetry (FGC-REQ-TEL-001)."""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Analyze SRS omission telemetry"
    )
    parser.add_argument(
        "path",
        nargs="?",
        default=".codex/telemetry.json",
        help="Path to codex telemetry JSON file",
    )
    args = parser.parse_args()

    telemetry_path = Path(args.path)
    if not telemetry_path.is_file():
        print(f"No telemetry file found at {telemetry_path}", file=sys.stderr)
        return 0

    try:
        data = json.loads(telemetry_path.read_text(encoding="utf-8"))
        entries = list(data.get("entries", []))
    except Exception:
        print(f"Invalid telemetry format in {telemetry_path}", file=sys.stderr)
        return 0

    total = len(entries)
    if total == 0:
        print("No telemetry entries found", file=sys.stderr)
        return 0

    omitted = sum(1 for e in entries if e.get("srs_omitted"))
    omission_rate = omitted / total if total else 0.0

    srs_ids = [s.strip() for s in os.getenv("SRS_IDS", "").split(",") if s.strip()]
    summary = {
        "srs_ids": srs_ids,
        "total_entries": total,
        "srs_omitted_count": omitted,
        "srs_omission_rate": omission_rate,
    }

    summary_path = Path("artifacts/srs-telemetry-summary.json")
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    with summary_path.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, sort_keys=True)

    history_path = Path("artifacts/srs-telemetry-summary-history.jsonl")
    history_limit = int(os.getenv("SRS_TELEMETRY_HISTORY_LIMIT", "20"))
    entry = {"timestamp": datetime.utcnow().isoformat() + "Z", **summary}
    existing: list[str] = []
    if history_path.is_file():
        with history_path.open("r", encoding="utf-8") as f:
            existing = [line.strip() for line in f if line.strip()]
    existing.append(json.dumps(entry, sort_keys=True))
    existing = existing[-history_limit:]
    with history_path.open("w", encoding="utf-8") as f:
        f.write("\n".join(existing) + "\n")

    threshold = float(os.getenv("MAX_SRS_OMISSION_RATE", "0"))
    if omission_rate > threshold:
        print(
            f"::warning::SRS omission rate {omission_rate:.2%} exceeds {threshold:.2%}",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
