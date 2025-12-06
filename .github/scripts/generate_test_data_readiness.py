#!/usr/bin/env python3
"""
Produce a minimal test data readiness report so the DoD Aggregator
workflow can upload an artifact even when no curated test data exists.
"""
from __future__ import annotations

import argparse
import os
from datetime import datetime, timezone


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate test data readiness report")
    parser.add_argument("--run-id", required=True, help="GitHub Actions run ID")
    args = parser.parse_args()

    os.makedirs("reports", exist_ok=True)

    report_path = f"reports/test-data-readiness-{args.run_id}.md"
    generated_at = datetime.now(timezone.utc).isoformat()

    with open(report_path, "w", encoding="utf-8") as handle:
        handle.write("# Test Data Readiness\n\n")
        handle.write(f"Run ID: {args.run_id}\n")
        handle.write(f"Generated at (UTC): {generated_at}\n\n")
        handle.write("No curated test datasets are registered for this run. "
                     "This placeholder is emitted to keep the DoD Aggregator "
                     "artifact contract intact.\n")

    print(f"Generated {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
