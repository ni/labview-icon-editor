#!/usr/bin/env python3
"""Lint GitHub workflows to discourage 'shell: powershell'.

Policy: Use PowerShell 7 ('pwsh') across platforms. 'shell: powershell' is only
allowed in explicit bootstrap steps named starting with 'Ensure PowerShell 7'.

Scan .github/workflows/*.yml and fail on disallowed usages.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from ruamel.yaml import YAML  # type: ignore
except Exception:
    print("ruamel.yaml is required (pip install ruamel.yaml)")
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
WF_DIR = ROOT / ".github" / "workflows"


def iter_workflows() -> list[Path]:
    files: list[Path] = []
    if WF_DIR.exists():
        files.extend(sorted(WF_DIR.glob("*.yml")))
        files.extend(sorted(WF_DIR.glob("*.yaml")))
    return files


def main() -> int:
    yaml = YAML(typ="safe")
    violations: list[str] = []
    for wf in iter_workflows():
        try:
            data = yaml.load(wf.read_text(encoding="utf-8")) or {}
        except Exception as e:
            # Ignore parse errors here; other hooks cover YAML validity
            continue
        jobs = (data or {}).get("jobs") or {}
        if not isinstance(jobs, dict):
            continue
        for job_id, job in jobs.items():
            steps = (job or {}).get("steps") or []
            if not isinstance(steps, list):
                continue
            for i, step in enumerate(steps):
                if not isinstance(step, dict):
                    continue
                shell = str(step.get("shell", "")).strip().lower()
                if not shell:
                    continue
                if "powershell" in shell and shell != "pwsh":
                    name = str(step.get("name", "")).strip()
                    if not name.lower().startswith("ensure powershell 7"):
                        violations.append(
                            f"{wf}: job '{job_id}', step {i+1} ('{name}'): disallowed shell: {shell}"
                        )
    if violations:
        print("Workflow shell lint failed:")
        for v in violations:
            print(f"- {v}")
        print("\nUse 'shell: pwsh' across platforms. 'shell: powershell' is only allowed in" 
              " bootstrap steps named 'Ensure PowerShell 7 ...'.")
        return 1
    print("Workflow shell lint: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

