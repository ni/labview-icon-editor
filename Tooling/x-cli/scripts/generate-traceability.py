#!/usr/bin/env python3
"""Generate requirement traceability matrix.

Scans ``docs/srs`` for ``FGC-REQ-*`` identifiers and cross references tests
across the entire ``tests`` tree as well as git commit metadata. The
resulting matrix is written to ``telemetry/traceability.json``. Optional
include/exclude patterns can scope which test files are considered.
"""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ID_RE = re.compile(r"FGC-REQ-[A-Z]+-\d{3}")

def _scan_specs(repo: Path) -> dict[str, str]:
    """Return mapping of requirement ID to spec path."""
    srs_dir = repo / "docs" / "srs"
    mapping: dict[str, str] = {}
    for path in srs_dir.rglob("*.md"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        for req_id in ID_RE.findall(text):
            mapping[req_id] = path.relative_to(repo).as_posix()
    return mapping

def _tests_for(
    repo: Path,
    req_id: str,
    include: list[str] | None = None,
    exclude: list[str] | None = None,
) -> list[str]:
    """Return list of test files referencing ``req_id``.

    Parameters ``include`` and ``exclude`` accept glob patterns relative to the
    ``tests`` directory. Patterns in ``include`` narrow the search, while
    ``exclude`` patterns are negated.
    """
    test_dir = repo / "tests"
    if not test_dir.exists():
        return []

    # ``rg`` (ripgrep) was previously used to efficiently search the ``tests``
    # tree. Relying on an external binary made the script fragile when the tool
    # was unavailable (for example in minimal test environments), causing
    # invocation to fail with ``FileNotFoundError``.  To keep the dependency
    # surface small we now scan files directly in Python.  While this is slower
    # than ripgrep on large trees, the simplicity is acceptable for the small
    # repositories this script targets and ensures the script always works
    # out-of-the-box.  When ``git`` is available we ask it for the list of test
    # files so ``.gitignore`` rules are honoured similar to ripgrep's default
    # behaviour.

    from fnmatch import fnmatch

    include = include or []
    exclude = exclude or []

    def iter_files() -> list[Path]:
        try:
            result = subprocess.run(
                [
                    "git",
                    "ls-files",
                    "--cached",
                    "--others",
                    "--exclude-standard",
                    str(test_dir),
                ],
                cwd=repo,
                capture_output=True,
                text=True,
                check=False,
            )
        except FileNotFoundError:
            result = subprocess.CompletedProcess("git", 1, stdout="", stderr="")

        if result.returncode == 0:
            return [repo / line for line in result.stdout.splitlines() if line.strip()]
        return [p for p in test_dir.rglob("*") if p.is_file()]

    matches: list[str] = []
    for path in iter_files():
        if not path.is_file():
            continue
        rel = path.relative_to(test_dir).as_posix()

        if include and not any(fnmatch(rel, pat) for pat in include):
            continue
        if any(fnmatch(rel, pat) for pat in exclude):
            continue

        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if req_id in text:
            matches.append(path.relative_to(repo).as_posix())

    return sorted(matches)

def _commits_for(repo: Path, req_id: str) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "log", "--format=%H", "--grep", req_id],
            cwd=repo,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return []
    if result.returncode != 0:
        return []
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]

def main() -> int:
    from argparse import ArgumentParser

    parser = ArgumentParser(description=__doc__)
    parser.add_argument(
        "--include",
        action="append",
        default=[],
        help="Glob pattern to include (relative to tests/)",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Glob pattern to exclude (relative to tests/)",
    )
    args = parser.parse_args()

    repo = Path(__file__).resolve().parent.parent
    specs = _scan_specs(repo)
    matrix = []
    for req_id, spec in sorted(specs.items()):
        entry = {
            "id": req_id,
            "spec": spec,
            "tests": _tests_for(repo, req_id, args.include, args.exclude),
            "commits": _commits_for(repo, req_id),
        }
        matrix.append(entry)
    out_path = repo / "telemetry" / "traceability.json"
    out_path.parent.mkdir(exist_ok=True)
    out_path.write_text(
        json.dumps({"requirements": matrix}, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote {out_path.relative_to(repo).as_posix()}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
