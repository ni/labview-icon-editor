from __future__ import annotations

import json
from pathlib import Path


def _stage2_update_summary(summary_path: Path, result: str) -> None:
    """Update telemetry summary with win_x64_smoke result.

    This mimics the Stage 2 step that records the Wine smoke test outcome
    so downstream stages can decide whether a native rebuild is required.
    """
    data: dict[str, object]
    if summary_path.exists():
        data = json.loads(summary_path.read_text(encoding="utf-8"))
    else:
        data = {}
    data["win_x64_smoke"] = result
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def test_win_smoke_field(tmp_path: Path) -> None:
    """Ensure Stage 2 telemetry adds a win_x64_smoke field."""
    summary = tmp_path / "telemetry" / "summary.json"
    _stage2_update_summary(summary, "success")
    data = json.loads(summary.read_text(encoding="utf-8"))
    assert isinstance(data.get("win_x64_smoke"), str)
