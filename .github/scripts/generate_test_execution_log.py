#!/usr/bin/env python3
"""
Generate a minimal test execution log for CI artifacts.
This stub records environment-provided step results into a markdown log so the
workflow can complete even when detailed execution data is not available.
"""
import argparse
import os
from datetime import datetime


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate test execution log")
    parser.add_argument("--run-id", required=True, help="GitHub Actions run ID")
    args = parser.parse_args()

    run_id = args.run_id
    os.makedirs("reports", exist_ok=True)

    # Collect known signals from environment (defaults to unknown)
    keys = [
        "RTM_VALIDATE",
        "RTM_COVERAGE",
        "GENERATE_TCS",
        "DATA_READINESS",
        "ENV_READINESS",
        "ADR_LINT",
        "LINKCHECK",
    ]
    results = {k: os.environ.get(k, "unknown") for k in keys}

    log_path = f"reports/test-execution-log-{run_id}.md"
    with open(log_path, "w", encoding="utf-8") as f:
        f.write("# Test Execution Log\n\n")
        f.write(f"Run ID: {run_id}\n")
        f.write(f"Generated at (UTC): {datetime.utcnow().isoformat()}\n\n")
        f.write("## Signals\n")
        for key, value in results.items():
            f.write(f"- {key}: {value}\n")
        f.write("\n## Notes\n")
        f.write("Stub log generated for CI; no detailed execution trace available.\n")

    print(f"Generated {log_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
