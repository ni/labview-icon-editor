#!/usr/bin/env python3
"""
Produce a minimal environment readiness report for the DoD Aggregator
workflow. Captures LabVIEW-related status signals exposed via environment
variables so consumers have a consistent artifact even in stub mode.
"""
from __future__ import annotations

import argparse
import os
from datetime import datetime, timezone


ENV_STATUS_KEYS = (
    "LV2021_X64_STATUS",
    "LV2021_X86_STATUS",
    "LV_UTF_LICENSE_STATUS",
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate test environment readiness report")
    parser.add_argument("--run-id", required=True, help="GitHub Actions run ID")
    args = parser.parse_args()

    os.makedirs("reports", exist_ok=True)

    report_path = f"reports/test-env-readiness-{args.run_id}.md"
    generated_at = datetime.now(timezone.utc).isoformat()

    env_statuses = {key: os.environ.get(key, "unknown") for key in ENV_STATUS_KEYS}

    with open(report_path, "w", encoding="utf-8") as handle:
        handle.write("# Test Environment Readiness\n\n")
        handle.write(f"Run ID: {args.run_id}\n")
        handle.write(f"Generated at (UTC): {generated_at}\n\n")
        handle.write("## LabVIEW signals\n")
        for key, value in env_statuses.items():
            handle.write(f"- {key}: {value}\n")
        handle.write("\nNotes: Placeholder report generated automatically for CI.\n")

    print(f"Generated {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
