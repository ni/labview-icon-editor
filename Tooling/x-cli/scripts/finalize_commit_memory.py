#!/usr/bin/env python3
"""Finalize commit-summary memory after commit.

Reads the temporary memory written by enrich_commit_summary.py and records
it to telemetry, augmenting with the HEAD commit SHA and subject.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path


def _git(cmd: list[str]) -> str:
    cp = subprocess.run(["git", *cmd], check=True, text=True, stdout=subprocess.PIPE)
    return cp.stdout.strip()


def main() -> int:
    tmp = Path(".codex/commit-msg-memory.tmp.json")
    if not tmp.exists():
        return 0
    try:
        payload = json.loads(tmp.read_text(encoding="utf-8"))
    except Exception:
        return 0

    try:
        sha = _git(["rev-parse", "HEAD"])
        subject = _git(["log", "-1", "--pretty=%s"])
        body = _git(["log", "-1", "--pretty=%b"])  # remainder (may be empty)
    except Exception:
        sha = ""
        subject = payload.get("candidate_summary") or payload.get("base_summary") or ""
        body = ""

    # Record via telemetry
    try:
        # Prefer internal helper to avoid packaging/PATH drift
        try:
            from scripts.lib.telemetry import record_telemetry_entry  # type: ignore
        except Exception:
            import sys as _sys
            from pathlib import Path as _Path
            _sys.path.insert(0, str(_Path(__file__).resolve().parent))
            from lib.telemetry import record_telemetry_entry  # type: ignore

        record_telemetry_entry(
            {
                "source": "commit-summary-enrich-finalize",
                "modules_inspected": [],
                "checks_skipped": [],
                "commit_sha": sha,
                "subject": subject,
                "body_present": bool(body),
                **payload,
            }
        )
    except Exception:
        pass

    try:
        tmp.unlink()
    except Exception:
        pass
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
