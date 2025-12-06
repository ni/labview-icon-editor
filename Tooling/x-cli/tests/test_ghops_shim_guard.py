from __future__ import annotations

from pathlib import Path


def test_ghops_shim_block_present() -> None:
    """Ensure ghops Windows smoke keeps stubbed tool shims and PATH restore.

    This guard prevents accidental removal of the shim logic that keeps the
    Windows ghops smoke deterministic and tool-agnostic in CI.
    """
    repo = Path(__file__).resolve().parents[1]
    ps1 = (repo / "scripts/ghops/tests/Ghops.Tests.ps1").read_text(encoding="utf-8")

    required_snippets = (
        "shim-bin",  # temporary dir for shims
        "pre-commit.cmd",  # stub for pre-commit when missing
        "ssh.cmd",  # stub for ssh when missing
        "$script:OriginalPath = $env:PATH",  # capture original PATH
        "$env:PATH = $script:OriginalPath",  # restore PATH in teardown
        "$script:GhopsShellPath",  # explicit engine path selection
    )

    for snippet in required_snippets:
        assert snippet in ps1, f"Missing ghops shim snippet: {snippet!r}"

