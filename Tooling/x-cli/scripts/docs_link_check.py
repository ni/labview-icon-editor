#!/usr/bin/env python3
"""Pre-commit: Markdown link + anchor check via lychee.

Prefers a native `lychee` binary if available; otherwise falls back to the
official Docker image. Uses repository `.lychee.toml` and scans current repo.

Exit codes: lychee's exit code; 2 when neither lychee nor docker is available.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str], cwd: Path) -> int:
    try:
        proc = subprocess.run(cmd, cwd=cwd)
        return proc.returncode
    except FileNotFoundError:
        return 127


def main(argv: list[str] | None = None) -> int:
    repo = Path(__file__).resolve().parents[1]
    config = ".lychee.toml"
    args = ["--config", config, "--no-progress", "--offline", "--include-fragments", "."]

    # Prefer native lychee
    if shutil.which("lychee"):
        return run(["lychee", *args], repo)

    # Fallback to Docker image
    if shutil.which("docker"):
        mount = f"{repo}:/data"
        cmd = [
            "docker",
            "run",
            "--rm",
            "-v",
            mount,
            "-w",
            "/data",
            "lycheeverse/lychee:latest",
            *args,
        ]
        return run(cmd, repo)

    print(
        "docs-link-check: neither 'lychee' nor 'docker' is available on PATH; "
        "install lychee or Docker, or run scripts/docs-link-check.ps1|.sh",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

