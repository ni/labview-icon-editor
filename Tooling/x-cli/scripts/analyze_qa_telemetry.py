"""Analyze QA telemetry results (FGC-REQ-TEL-001)."""

import argparse
import json
import os
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze QA telemetry")
    parser.add_argument(
        "path",
        nargs="?",
        default="artifacts/qa-telemetry.jsonl",
        help="Path to QA telemetry JSONL file",
    )
    args = parser.parse_args()

    telemetry_path = Path(args.path)
    if not telemetry_path.is_file():
        print(f"No telemetry file found at {telemetry_path}", file=sys.stderr)
        return 0

    entries: list[dict] = []
    with telemetry_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

    if not entries:
        print("No entries in QA telemetry", file=sys.stderr)
        return 0

    durations: defaultdict[str, list[float]] = defaultdict(list)
    failures: defaultdict[str, int] = defaultdict(int)
    for entry in entries:
        step = entry.get("step")
        durations[step].append(float(entry.get("duration_ms", 0)))
        if entry.get("status") != "pass":
            failures[step] += 1

    averages = {s: sum(ds) / len(ds) for s, ds in durations.items()}
    summary = {
        "step_averages": [
            {"step": s, "avg_duration_ms": averages[s]} for s in sorted(averages)
        ],
        "failure_counts": dict(sorted(failures.items())),
    }
    summary_path = telemetry_path.with_name("qa-telemetry-summary.json")
    with summary_path.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, sort_keys=True)

    history_path = telemetry_path.with_name("qa-telemetry-summary-history.jsonl")
    history_limit = int(os.getenv("QA_TELEMETRY_HISTORY_LIMIT", "20"))
    entry = {"timestamp": datetime.utcnow().isoformat() + "Z", **summary}
    existing: list[str] = []
    if history_path.is_file():
        with history_path.open("r", encoding="utf-8") as f:
            existing = [line.strip() for line in f if line.strip()]
    existing.append(json.dumps(entry, sort_keys=True))
    existing = existing[-history_limit:]
    with history_path.open("w", encoding="utf-8") as f:
        f.write("\n".join(existing) + "\n")

    archive_path = os.getenv("QA_TELEMETRY_ARCHIVE")
    if archive_path:
        try:
            archive = Path(archive_path)
            archive.parent.mkdir(parents=True, exist_ok=True)
            with archive.open("a", encoding="utf-8") as f:
                f.write(json.dumps(entry, sort_keys=True) + "\n")
        except OSError as e:
            print(
                f"Unable to append QA telemetry to archive {archive_path}: {e}",
                file=sys.stderr,
            )

    max_failures = int(os.getenv("MAX_QA_FAILURES", "0"))
    offenders = {s: c for s, c in failures.items() if c > max_failures}
    if offenders:
        for step, count in offenders.items():
            print(
                f"Step {step} failed {count} times (threshold {max_failures})",
                file=sys.stderr,
            )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
