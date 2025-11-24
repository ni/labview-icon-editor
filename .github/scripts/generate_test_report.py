#!/usr/bin/env python3
"""Generate a markdown test report tied to the RTM."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import List

from rtm_utils import (
    Coverage,
    MIN_HIGH,
    MIN_TOTAL,
    ROOT,
    RTM_PATH,
    compute_coverage,
    detect_suites,
    load_rtm,
)

REPORT_PATH = ROOT / "test-report.md"


def write_report(rows: List[dict], high: Coverage, total: Coverage) -> None:
    suites = detect_suites(rows)
    completion = (
        "PASS"
        if high.pct() >= MIN_HIGH and total.pct() >= MIN_TOTAL
        else "FAIL"
    )

    lines: List[str] = []
    lines.append("# Test Report")
    lines.append("")
    lines.append("## Objectives")
    lines.append("- Validate regression coverage against RTM entries (functional and non-functional).")
    lines.append("- Confirm LabVIEW unit test suites exercise mapped requirements.")
    lines.append("- Record completion against RTM thresholds.")
    lines.append("")
    lines.append("## Completion Status")
    lines.append(
        f"- Completion: **{completion}** "
        f"(High/Critical: {high.covered}/{high.total} = {high.pct():.0%}; "
        f"Overall: {total.covered}/{total.total} = {total.pct():.0%}; "
        f"required >= {MIN_HIGH:.0%}/{MIN_TOTAL:.0%})"
    )
    lines.append("- Unit test execution: runs in self-hosted jobs `test-2021-x64` and `test-2021-x86` (see CI pipeline); this report captures RTM mapping and coverage prerequisites.")
    if suites:
        lines.append(f"- LabVIEW unit test suites referenced: {', '.join(suites)}")
    lines.append("")
    lines.append("## RTM to Test Mapping")
    lines.append("")
    lines.append("| Requirement | Priority | Objective | Test Path |")
    lines.append("| --- | --- | --- | --- |")
    for row in rows:
        lines.append(
            f"| {row['id']} | {row['priority']} | {row['title']} | `{row['test_path']}` |"
        )
    lines.append("")
    lines.append("## Evidence Sources")
    lines.append("- RTM source: `docs/requirements/rtm.csv`")
    lines.append("- Coverage enforcement: `.github/scripts/check_rtm_coverage.py`")
    lines.append("- Unit test runner: `.github/actions/run-unit-tests/RunUnitTests.ps1`")
    lines.append("")

    REPORT_PATH.write_text("\n".join(lines))


def main() -> int:
    try:
        rows = load_rtm()
    except Exception as exc:
        print(f"Failed to load RTM: {exc}", file=sys.stderr)
        return 2

    high, total, missing = compute_coverage(rows)
    exit_code = 0
    if missing:
        print("Missing coverage entries:")
        for item in missing:
            print(f"- {item}", file=sys.stderr)
        exit_code = 1

    write_report(rows, high, total)

    if high.pct() < MIN_HIGH or total.pct() < MIN_TOTAL:
        print("Coverage thresholds not met; report generated but failing pipeline.", file=sys.stderr)
        exit_code = 1

    print(f"Wrote {REPORT_PATH} with coverage summary.")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
