from __future__ import annotations

from pathlib import Path
import subprocess
import shutil
import pytest


@pytest.mark.skipif(shutil.which("pwsh") is None, reason="pwsh not installed")
def test_ps1_requires_discord(tmp_path: Path) -> None:
    summary = tmp_path / "summary.json"
    summary.write_text("{}", encoding="utf-8")
    script = Path(__file__).resolve().parents[1] / "scripts" / "telemetry-publish.ps1"
    result = subprocess.run(
        [
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            str(script),
            "-Current",
            str(summary),
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
