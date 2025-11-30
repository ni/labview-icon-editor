#!/usr/bin/env python3
"""Check aggregate test duration against a benchmark."""

import json
import os
import sys
from pathlib import Path


def main() -> int:
    telemetry_path = Path("artifacts/test-telemetry.jsonl")
    baseline_path = Path("tests/test-duration-benchmark.json")

    if not telemetry_path.is_file():
        print(f"No telemetry file found at {telemetry_path}", file=sys.stderr)
        return 0
    if not baseline_path.is_file():
        print(f"No baseline file found at {baseline_path}", file=sys.stderr)
        return 0

    total = 0.0
    languages: set[str] = set()
    with telemetry_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                data = json.loads(line)
                total += float(data.get("duration", 0))
                lang = data.get("language")
                if lang:
                    languages.add(str(lang))

    expected = {l for l in os.getenv("TEST_LANGUAGES", "python,dotnet").split(",") if l}
    missing = expected - languages
    if missing:
        print(
            f"Missing telemetry for languages: {', '.join(sorted(missing))}",
            file=sys.stderr,
        )
        return 1

    baseline = json.loads(baseline_path.read_text())
    baseline_total = float(baseline.get("total_duration", 0))

    factor = float(os.getenv("TEST_DURATION_FACTOR", "1.5"))
    if total > baseline_total * factor:
        print(
            f"Total test duration {total:.2f}s exceeds baseline {baseline_total:.2f}s "
            f"* factor {factor}",
            file=sys.stderr,
        )
        return 1

    print(
        f"Total test duration {total:.2f}s within benchmark {baseline_total:.2f}s"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
