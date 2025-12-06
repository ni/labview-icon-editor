from __future__ import annotations

from pathlib import Path

import pytest

# Mapping from requirement ID to workflow paths and expected substrings
WORKFLOW_EXPECTATIONS = {
    "FGC-REQ-CI-001": {
        ".github/workflows/build.yml": ["dotnet build", "dotnet test", "Publish (linux-x64)"],
        ".github/workflows/stage2.yml": ["dotnet build", "dotnet test", "scripts/build.sh"],
        ".github/workflows/stage2-3-ci.yml": ["Stage 2 - Ubuntu CI", "Publish linux-x64 single-file"],
    },
    "FGC-REQ-CI-006": {
        ".github/workflows/design-lock.yml": ["pull_request", "validate_design.py"],
    },
    "FGC-REQ-CI-010": {
        ".github/workflows/telemetry-aggregate.yml": ["workflow_run", "telemetry"],
    },
    "FGC-REQ-CI-011": {
        ".github/workflows/tests-gate.yml": ["pytest", "ENFORCE_WRITE_GUARD"],
    },
    "FGC-REQ-CI-020": {
        ".github/workflows/stage3.yml": ["Validate manifest & checksums", "Smoke test win-x64"],
    },
    "AGENT-REQ-DEP-001": {
        ".github/workflows/stage3.yml": ["Missing required file", "Manifest entry"],
    },
    "AGENT-REQ-ART-002": {
        "scripts/generate-manifest.sh": ["sha256sum", '"sha256"'],
    },
    "AGENT-REQ-TEL-003": {
        ".github/workflows/stage3.yml": ["Telemetry diff", "summary.json"],
        "scripts/telemetry-publish.ps1": ["Baseline established", "diff-latest.json"],
    },
    "AGENT-REQ-NOT-004": {
        ".github/workflows/stage3.yml": ["DISCORD_WEBHOOK_URL"],
        "scripts/telemetry-publish.ps1": ["Discord"],
    },
}

# Flatten mapping for parametrization
PARAMS = [
    (req_id, Path(path), expected)
    for req_id, files in WORKFLOW_EXPECTATIONS.items()
    for path, expected in files.items()
]


@pytest.mark.parametrize("req_id, path, expected_substrings", PARAMS)
def test_workflow_satisfies_requirement(req_id: str, path: Path, expected_substrings: list[str]) -> None:
    """Verify workflow files contain key markers satisfying their SRS requirement."""
    repo_root = Path(__file__).resolve().parents[1]
    wf_path = repo_root / path
    text = wf_path.read_text()
    for snippet in expected_substrings:
        assert snippet in text, f"{req_id}: '{snippet}' not found in {path}"
