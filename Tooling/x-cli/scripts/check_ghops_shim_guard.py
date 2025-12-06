#!/usr/bin/env python3
"""Guard that ghops Windows smoke retains shim logic and PATH restore.

Usage:
  python scripts/check_ghops_shim_guard.py [--path scripts/ghops/tests/Ghops.Tests.ps1]

Exits non‑zero when expected snippets are missing to alert during pre-commit.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


REQUIRED_SNIPPETS = (
    "shim-bin",  # temporary dir for shims
    "pre-commit.cmd",  # stub for pre-commit when missing
    "ssh.cmd",  # stub for ssh when missing
    "$script:OriginalPath = $env:PATH",  # capture original PATH
    "$env:PATH = $script:OriginalPath",  # restore PATH in teardown
    "$script:GhopsShellPath",  # explicit engine path selection across runners
)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument(
        "--path",
        default="scripts/ghops/tests/Ghops.Tests.ps1",
        help="Path to the Pester smoke file to check",
    )
    args = ap.parse_args(argv)

    ps1 = Path(args.path)
    if not ps1.exists():
        print(f"ghops shim guard: file not found: {ps1}")
        return 1

    text = ps1.read_text(encoding="utf-8", errors="ignore")
    missing: list[str] = [s for s in REQUIRED_SNIPPETS if s not in text]
    if missing:
        print("ghops shim guard: missing required snippet(s):")
        for s in missing:
            print(f" - {s}")
        print(
            "See docs/workflows-inventory.md (ghops smoke Windows note) for rationale."
        )
        return 1

    print("ghops shim guard: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

