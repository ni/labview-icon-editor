#!/usr/bin/env python3
"""Run ``pre-commit`` and record telemetry on failure."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

# Prefer internal helper to avoid packaging/PATH drift
from scripts.lib.telemetry import record_telemetry_entry  # type: ignore

LOG_PATH = Path(".codex/pre-commit.log")


def main(argv: list[str] | None = None) -> int:
    """Run ``pre-commit`` and capture failing hook IDs."""
    cmd = [sys.executable, "-m", "pre_commit", "run", "--hook-stage", "commit"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
    except Exception as exc:  # pragma: no cover - exercised in tests
        record_telemetry_entry(
            {
                "source": "pre-commit",
                "failing_hooks": [],
                "modules_inspected": [],
                "checks_skipped": [],
            },
            command=cmd,
            exception_type=type(exc).__name__,
            exception_message=str(exc),
        )
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        LOG_PATH.write_text(str(exc), encoding="utf-8")
        raise

    # Forward output so the user sees normal ``pre-commit`` messages.
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)

    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    LOG_PATH.write_text(proc.stdout + proc.stderr, encoding="utf-8")

    if proc.returncode != 0:
        failing: list[str] = []
        for line in proc.stdout.splitlines():
            match = re.match(r"- hook id: (.+)", line.strip())
            if match:
                failing.append(match.group(1))
        record_telemetry_entry(
            {
                "source": "pre-commit",
                "failing_hooks": failing,
                "modules_inspected": [],
                "checks_skipped": [],
            },
            command=cmd,
            exit_status=proc.returncode,
        )
        guidance = {
            "commit-message": (
                "Commit message must follow template in AGENTS.md;"
                " edit the message to match the required format."
            ),
            "agent-feedback": (
                "Telemetry modules need an 'agent_feedback' parameter or"
                " '--agent-feedback' flag (FGC-REQ-DEV-003)."
            ),
        }
        if failing:
            print("\nResolve pre-commit failures:", file=sys.stderr)
            for hook in failing:
                msg = guidance.get(hook)
                if msg:
                    print(f" - {msg}", file=sys.stderr)
            unknown = [h for h in failing if h not in guidance]
            if unknown:
                print(
                    " - See .codex/pre-commit.log for details on"
                    f" {', '.join(unknown)}",
                    file=sys.stderr,
                )

    return proc.returncode


if __name__ == "__main__":  # pragma: no cover - script entrypoint
    raise SystemExit(main())
