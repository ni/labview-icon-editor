#!/usr/bin/env python3
"""Update docs/traceability.yaml based on SRS IDs in commits and PR bodies."""
from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

from ruamel.yaml import YAML

ID_RE = re.compile(r"FGC-REQ-[A-Z]+-\d{3}")


def _spec_info(repo: Path, req_id: str) -> tuple[str, str]:
    """Return (desc, relative source path) for ``req_id``.

    Searches ``docs/srs`` for the requirement ID and extracts the description
    from the matching line. Raises ``RuntimeError`` if a unique spec entry
    cannot be determined.
    """
    srs_dir = repo / "docs" / "srs"
    direct = srs_dir / f"{req_id}.md"
    if direct.exists():
        path = direct
    else:
        result = subprocess.run(
            ["rg", "-l", req_id, str(srs_dir)], capture_output=True, text=True, check=True
        )
        paths = [Path(p) for p in result.stdout.splitlines() if p.strip()]
        if not paths:
            raise RuntimeError(f"{req_id}: spec file not found")
        if len(paths) > 1:
            rels = ", ".join(p.relative_to(repo).as_posix() for p in paths)
            raise RuntimeError(f"{req_id}: multiple spec files found: {rels}")
        path = paths[0]
    for line in path.read_text(encoding="utf-8").splitlines():
        if req_id in line:
            m = re.search(rf"{req_id}\s+[—-]\s*(.*)", line)
            if m:
                desc = m.group(1).strip().strip("*").strip()
                return desc, path.relative_to(repo).as_posix()
            break
    raise RuntimeError(
        f"{req_id}: description not found in {path.relative_to(repo).as_posix()}"
    )


def extract_ids(text: str) -> set[str]:
    """Return unique requirement IDs found in the given text."""
    return set(ID_RE.findall(text))


def collect_text() -> str:
    """Collect commit messages and PR body text."""
    # Only inspect the latest commit message
    result = subprocess.run(
        ["git", "log", "-1", "--format=%B"],
        check=True,
        capture_output=True,
        text=True,
    )
    commit_text = result.stdout
    pr_body = os.environ.get("PR_BODY", "")
    return commit_text + "\n" + pr_body


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    trace_file = repo / "docs" / "traceability.yaml"

    ids = extract_ids(collect_text())
    if not ids:
        print("No requirement IDs found.")
        return 0

    yaml = YAML(typ="rt")
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=4, offset=2)
    data = yaml.load(trace_file.read_text(encoding="utf-8"))

    requirements = {entry["id"]: entry for entry in data.get("requirements", [])}
    commit_hash = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()

    updated = False
    for req_id in ids:
        if req_id in requirements:
            entry = requirements[req_id]
            commits = entry.setdefault("commits", [])
            if commit_hash not in commits:
                commits.append(commit_hash)
                print(f"Updated {req_id} with commit {commit_hash}")
                updated = True
            else:
                print(f"{req_id} already contains commit {commit_hash}")
        else:
            try:
                desc, source = _spec_info(repo, req_id)
            except RuntimeError as exc:
                print(f"Error: {exc}")
                print(
                    "Provide a valid spec entry for this requirement and rerun the script.",
                    flush=True,
                )
                return 1
            data.setdefault("requirements", []).append(
                {
                    "id": req_id,
                    "desc": desc,
                    "source": source,
                    "code": [],
                    "tests": [],
                    "commits": [commit_hash],
                }
            )
            print(f"Added {req_id} from {source}")
            updated = True

    if updated:
        with trace_file.open("w", encoding="utf-8") as fh:
            yaml.dump(data, fh)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
