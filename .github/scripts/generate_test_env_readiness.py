#!/usr/bin/env python3
"""Generate test environment readiness report (§8.6, §8.8)."""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import List

from rtm_utils import ROOT

REPORTS_DIR = ROOT / "reports"
DEFAULT_RUN_ID = "local"


@dataclass
class EnvRequirement:
    ident: str
    description: str
    runner: str
    version: str
    severity: str  # high/medium/low
    owner: str
    verifier: str  # auto | env:<VAR>

    def check_status(self) -> tuple[str, str]:
        """
        Return (status, note) where status is Ready/Warning/Blocker.

        Rules:
        - auto: check current platform/tooling
        - env: read environment variable (ready/warning/blocker); default warning
        """
        if self.verifier == "auto":
            if self.ident == "ENV-GATES-UBUNTU":
                if os.environ.get("GITHUB_RUNNER_OS", "").lower() in {"linux", "ubuntu"} or sys.platform.startswith(
                    ("linux",)
                ):
                    return "Ready", "Running on Linux/Ubuntu gate runner."
                return "Blocker", "Gate runner is not Linux/Ubuntu."
            return "Warning", "Auto verifier not implemented."

        if self.verifier.startswith("env:"):
            var = self.verifier.split(":", 1)[1]
            raw = os.environ.get(var, "").strip().lower()
            if raw == "ready":
                return "Ready", f"{var}=ready"
            if raw == "blocker":
                return "Blocker", f"{var}=blocker"
            if raw == "warning":
                return "Warning", f"{var}=warning"
            return "Warning", f"{var} not set (requires manual confirmation)"

        return "Warning", "Unknown verifier"


REQUIREMENTS: List[EnvRequirement] = [
    EnvRequirement(
        ident="ENV-GATES-UBUNTU",
        description="CI gates run on Ubuntu with Python 3.x",
        runner="ubuntu-latest",
        version="Python 3.x",
        severity="high",
        owner="Automation QA",
        verifier="auto",
    ),
    EnvRequirement(
        ident="ENV-LV-2021-X64",
        description="LabVIEW 2021 + UTF license on self-hosted x64 runner",
        runner="self-hosted, test-2021-x64, windows",
        version="LabVIEW 2021 + UTF",
        severity="high",
        owner="Automation QA",
        verifier="env:LV2021_X64_STATUS",
    ),
    EnvRequirement(
        ident="ENV-LV-2021-X86",
        description="LabVIEW 2021 + UTF license on self-hosted x86 runner",
        runner="self-hosted, test-2021-x86, windows",
        version="LabVIEW 2021 + UTF",
        severity="high",
        owner="Automation QA",
        verifier="env:LV2021_X86_STATUS",
    ),
    EnvRequirement(
        ident="ENV-LICENSE-UTF",
        description="LabVIEW Unit Test Framework license available/unexpired",
        runner="self-hosted",
        version="UTF license",
        severity="high",
        owner="Automation QA",
        verifier="env:LV_UTF_LICENSE_STATUS",
    ),
]


def timestamp_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")


def summarize(requirements: List[EnvRequirement], run_id: str) -> Path:
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORTS_DIR / f"test-env-readiness-{run_id}.md"

    rows = []
    blockers = []
    warnings = []

    for req in requirements:
        status, note = req.check_status()
        rows.append((req, status, note))
        if status == "Blocker":
            blockers.append((req, note))
        elif status == "Warning":
            warnings.append((req, note))

    lines: List[str] = []
    lines.append("# Test Environment Readiness Report (ISO/IEC/IEEE 29119-3 §8.6, §8.8)")
    lines.append("")
    lines.append(f"- Generated: {timestamp_utc()}")
    lines.append(f"- Run ID: `{run_id}`")
    lines.append("- Source: `docs/testing/test-environment-requirements.md`")
    lines.append("")
    lines.append("## Summary")
    lines.append(f"- Requirements: {len(requirements)}")
    lines.append(f"- Ready: {len(requirements) - len(blockers) - len(warnings)}")
    lines.append(f"- Warnings: {len(warnings)}")
    lines.append(f"- Blockers: {len(blockers)}")
    if blockers:
        lines.append("- Blocker details:")
        for req, note in blockers:
            lines.append(f"  - {req.ident}: {note}")
    elif warnings:
        lines.append("- Blocker details: none (warnings present)")
    else:
        lines.append("- Blocker details: none")
    lines.append("")
    lines.append("## Requirement Status")
    lines.append("| ID | Description | Runner | Version/Tooling | Severity | Owner | Status | Notes |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for req, status, note in rows:
        lines.append(
            f"| {req.ident} | {req.description} | {req.runner} | {req.version} | {req.severity} | {req.owner} | {status} | {note} |"
        )

    path.write_text("\n".join(lines), encoding="utf-8")
    return path, blockers


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate test environment readiness report.")
    parser.add_argument("--run-id", default=DEFAULT_RUN_ID, help="Run identifier (default: local).")
    args = parser.parse_args()
    run_id = args.run_id or DEFAULT_RUN_ID

    report_path, blockers = summarize(REQUIREMENTS, run_id)
    rel = report_path.relative_to(ROOT)
    print(f"Wrote {rel}")
    if blockers:
        print("Environment blockers detected:")
        for req, note in blockers:
            print(f"- {req.ident}: {note}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
