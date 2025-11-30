#!/usr/bin/env python3
"""Generate a minimal telemetry stub for local QA runs."""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_PATH = Path(__file__).resolve().parents[1] / ".codex" / "telemetry.json"


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate telemetry stub")
    parser.add_argument("path", nargs="?", default=DEFAULT_PATH)
    args = parser.parse_args()
    path = Path(args.path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "entries": [
            {
                "agent_feedback": (
                    "### Cross-Agent Telemetry Recommendation\n"
                    "#### Effectiveness\n- no cross-agent feedback collected yet\n"
                    "#### Obstacles\n- none observed\n"
                    "#### Improvements\n- capture real QA metrics\n"
                )
            },
            {
                "source": "qa.sh",
                "command": ["./scripts/qa.sh"],
                "exit_status": 0,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            },
        ]
    }
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
