#!/usr/bin/env python3
"""Generate docs/compliance/Release-Record.md from coverage.xml and thresholds."""
from __future__ import annotations

import datetime
import json
import os
import pathlib
import xml.etree.ElementTree as ET


def main() -> None:
    root = pathlib.Path(".")
    coverage_xml = root / "coverage.xml"
    skip_flag = os.environ.get("SKIP_COVERAGE", "").lower() == "true"

    cfg_path = root / "docs/compliance/coverage-thresholds.json"
    cfg = json.loads(cfg_path.read_text())
    thresholds = {
        "line": float(cfg.get("total", 0.0)),
        "branch": float(cfg.get("branch_total", 0.0)),
    }
    coverage_lines: list[str]
    if not skip_flag and coverage_xml.exists():
        cov = ET.parse(coverage_xml).getroot()
        line = float(cov.attrib.get("line-rate", "0")) * 100.0
        branch = float(cov.attrib.get("branch-rate", "0")) * 100.0
        totals = {"line": round(line, 1), "branch": round(branch, 1)}
        status = {
            "line": "PASS" if totals["line"] + 1e-6 >= thresholds["line"] else "FAIL",
            "branch": "PASS" if totals["branch"] + 1e-6 >= thresholds["branch"] else "FAIL",
        }
        coverage_lines = [
            f"- Totals: line={totals['line']:.1f}% (min {thresholds['line']:.1f}%) - {status['line']}",
            f"          branch={totals['branch']:.1f}% (min {thresholds['branch']:.1f}%) - {status['branch']}",
        ]
    else:
        coverage_lines = [
            "- Totals: SKIPPED (coverage disabled or unavailable)",
            f"  Minimums: line>={thresholds['line']:.1f}%, branch>={thresholds['branch']:.1f}%",
        ]

    sha = os.environ.get("GITHUB_SHA", "")[:7]
    tag = os.environ.get("GITHUB_REF_NAME", "")
    run_url = "{}/{}/actions/runs/{}".format(
        os.environ.get("GITHUB_SERVER_URL"),
        os.environ.get("GITHUB_REPOSITORY"),
        os.environ.get("GITHUB_RUN_ID"),
    )
    version = os.environ.get("VERSION", "")
    artifacts = [
        "artifacts/coverage/Cobertura.xml",
        "artifacts/coverage/index.html",
        f"artifacts/release/linux-x64/x-cli-linux-x64-{version}",
        f"artifacts/release/win-x64/x-cli-win-x64-{version}.exe",
        f"artifacts/action/x-cli-action-{version}.tar",
    ]
    artifact_lines = "\n".join(f"- {a}" for a in artifacts)

    coverage_section = "\n".join(coverage_lines)

    template = """# Release Record

- Tag: {tag}
- Commit: {sha}
- Date: {date}
- CI Run: {run_url}

## Coverage
{coverage_section}

## Artifacts
{artifact_lines}
"""
    out = template.format(
        tag=tag,
        sha=sha,
        date=datetime.date.today().isoformat(),
        run_url=run_url,
        coverage_section=coverage_section,
        artifact_lines=artifact_lines,
    )

    target = root / "docs/compliance/Release-Record.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(out, encoding="utf-8")
    print(out)


if __name__ == "__main__":
    main()
