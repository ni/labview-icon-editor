#!/usr/bin/env python3
# ModuleIndex: merges and summarizes telemetry inputs.
"""Analyze test telemetry and detect regressions (FGC-REQ-TEL-001)."""

import argparse
import json
import os
import statistics
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze test telemetry")
    parser.add_argument(
        "path",
        nargs="?",
        default="artifacts/test-telemetry.jsonl",
        help="Path to telemetry JSONL file",
    )
    args = parser.parse_args()

    telemetry_path = Path(args.path)
    if not telemetry_path.is_file():
        print(f"No telemetry file found at {telemetry_path}", file=sys.stderr)
        return 0

    entries = []
    with telemetry_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

    durations: defaultdict[str, list[float]] = defaultdict(list)
    dependency_failures: Counter[str] = Counter()

    for entry in entries:
        test = entry.get("test")
        duration = float(entry.get("duration", 0))
        durations[test].append(duration)

        if entry.get("outcome") == "failed":
            for dep in entry.get("dependencies", []):
                dependency_failures[dep] += 1

    if not durations:
        print("No test entries in telemetry", file=sys.stderr)
        return 0

    total_duration = sum(sum(ds) for ds in durations.values())
    averages = {t: sum(ds) / len(ds) for t, ds in durations.items()}
    global_avg = statistics.mean(averages.values())

    slow_factor = float(os.getenv("SLOW_TEST_FACTOR", "2"))
    slow_tests = [
        (t, avg)
        for t, avg in averages.items()
        if avg > global_avg * slow_factor
    ]

    for test, avg in sorted(averages.items(), key=lambda x: x[0]):
        print(f"{test} average {avg:.3f}s")

    for test, avg in slow_tests:
        print(
            f"::warning::Slow test {test}: {avg:.3f}s exceeds {slow_factor}x global average {global_avg:.3f}s"
        )

    srs_ids = [s.strip() for s in os.getenv("SRS_IDS", "").split(",") if s.strip()]
    summary = {
        "srs_ids": srs_ids,
        "total_duration": total_duration,
        "slow_test_count": len(slow_tests),
        "slow_tests": [
            {"test": t, "avg_duration": avg} for t, avg in slow_tests
        ],
        "dependency_failures": dict(dependency_failures),
    }
    summary_path = telemetry_path.with_name("telemetry-summary.json")
    with summary_path.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2, sort_keys=True)

    history_path = telemetry_path.with_name("telemetry-summary-history.jsonl")
    history_limit = int(os.getenv("TELEMETRY_HISTORY_LIMIT", "20"))
    entry = {"timestamp": datetime.utcnow().isoformat() + "Z", **summary}
    existing: list[str] = []
    if history_path.is_file():
        with history_path.open("r", encoding="utf-8") as f:
            existing = [line.strip() for line in f if line.strip()]
    existing.append(json.dumps(entry, sort_keys=True))
    existing = existing[-history_limit:]
    with history_path.open("w", encoding="utf-8") as f:
        f.write("\n".join(existing) + "\n")

    max_dep_failures = int(os.getenv("MAX_DEPENDENCY_FAILURES", "0"))
    offenders = {
        dep: count for dep, count in dependency_failures.items() if count > max_dep_failures
    }
    if offenders:
        for dep, count in offenders.items():
            print(
                f"Dependency {dep} failed {count} times (threshold {max_dep_failures})",
                file=sys.stderr,
            )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
