from __future__ import annotations

from pathlib import Path


def test_srs_gate_wires_ts_rtm_tool() -> None:
    """Ensure SRS Gate uses the TypeScript RTM verifier.

    Verifies setup-node usage, install/build steps for the tool, and the
    execution command with expected flags.
    """
    repo_root = Path(__file__).resolve().parents[1]
    wf = repo_root / ".github/workflows/srs-gate.yml"
    assert wf.exists(), "srs-gate workflow missing"
    text = wf.read_text(encoding="utf-8")

    # Node setup present
    assert "actions/setup-node@v4" in text

    # Install/build the TS tool from its folder
    assert "npm install --prefix tools/rtm-verify-ts" in text
    assert "npm run build --prefix tools/rtm-verify-ts" in text

    # Execute the compiled verifier with comment on failure
    assert "node tools/rtm-verify-ts/dist/index.js" in text
    assert "--comment" in text and "--only-on-failure" in text

