#!/usr/bin/env python3
"""Populate `.codex/metadata.json` from a GitHub issue.

Usage: hydrate_metadata_from_issue.py [issue-number]
The issue number may also be supplied via the `ISSUE_NUMBER` environment
variable. The repository slug (`owner/repo`) must be provided via
`GITHUB_REPOSITORY`.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path


def parse_issue_body(body: str) -> tuple[str, list[str]]:
    summary_lines: list[str] = []
    srs_ids: list[str] = []
    section: str | None = None
    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith("### "):
            header = stripped[4:].lower()
            if header.startswith("summary"):
                section = "summary"
                continue
            if header.startswith("srs"):
                section = "srs"
                continue
            section = None
            continue
        if section == "summary":
            summary_lines.append(line.rstrip())
        elif section == "srs" and stripped:
            srs_ids.append(stripped.lstrip("-* "))
    return "\n".join(summary_lines).strip(), srs_ids


def get_change_type(labels: list[dict]) -> str:
    names = {str(l.get("name", "")).lower() for l in labels}
    for cand in ("impl", "spec", "both"):
        if cand in names:
            return cand
    return ""


def fetch_issue(repo: str, issue_number: int) -> dict:
    url = f"https://api.github.com/repos/{repo}/issues/{issue_number}"
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "x-cli",
        },
    )
    tok = os.getenv("GITHUB_TOKEN")
    if tok:
        req.add_header("Authorization", f"token {tok}")
    with urllib.request.urlopen(req, timeout=10) as resp:  # noqa: S310
        return json.loads(resp.read().decode("utf-8"))


def main(argv: list[str] | None = None) -> int:
    argv = argv or sys.argv
    issue_str = argv[1] if len(argv) > 1 else os.getenv("ISSUE_NUMBER")
    if not issue_str:
        print("Usage: hydrate_metadata_from_issue.py <issue-number>", file=sys.stderr)
        return 1
    try:
        issue_number = int(issue_str)
    except ValueError:
        print("Issue number must be an integer", file=sys.stderr)
        return 1

    repo = os.getenv("GITHUB_REPOSITORY")
    if not repo:
        print("GITHUB_REPOSITORY not set", file=sys.stderr)
        return 1

    data = fetch_issue(repo, issue_number)
    summary, srs_ids = parse_issue_body(data.get("body", ""))
    change_type = get_change_type(data.get("labels", []))

    repo_root = Path(os.environ.get("REPO_ROOT", Path(__file__).resolve().parent.parent))
    meta_path = repo_root / ".codex" / "metadata.json"
    meta_path.parent.mkdir(parents=True, exist_ok=True)
    meta = {
        "summary": summary,
        "change_type": change_type,
        "srs_ids": srs_ids,
        "issue": issue_number,
    }
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":  # pragma: no cover - entry point
    raise SystemExit(main())
