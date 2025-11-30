#!/usr/bin/env python3
"""Create a GitHub issue in the current repository and print a commit meta.

Usage:
  python scripts/create_issue.py --title "Brief summary" [--body "..."] [--label bug] [--assignee user]

Requirements:
  - GH token via env var `GITHUB_TOKEN` or `GH_TOKEN`
  - Repository via env var `GITHUB_REPOSITORY` (owner/repo) or derivable from git remote

Output:
  - Prints the issue URL and number to stdout
  - Prints a convenience snippet: "issue: #<number>" (use at the end of line 3)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Tuple


def _detect_repo() -> Tuple[str, str]:
    env = os.getenv("GITHUB_REPOSITORY")
    if env and "/" in env:
        owner, repo = env.split("/", 1)
        return owner, repo
    try:
        url = (
            subprocess.check_output(["git", "config", "--get", "remote.origin.url"], text=True)
            .strip()
        )
        # Support https and SSH forms
        m = re.search(r"github\.com[:/](?P<owner>[^/]+)/(?P<repo>[^/.]+)(?:\.git)?$", url)
        if m:
            return m.group("owner"), m.group("repo")
    except Exception:
        pass
    raise SystemExit(
        "Unable to detect repository. Set GITHUB_REPOSITORY=owner/repo or run inside a git repo with an origin URL."
    )


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--title", required=True, help="Issue title")
    ap.add_argument("--body", default="", help="Issue body (markdown)")
    ap.add_argument("--label", action="append", default=[], help="Add a label (repeatable)")
    ap.add_argument("--assignee", action="append", default=[], help="Assign to user (repeatable)")
    args = ap.parse_args(argv)

    token = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN")
    if not token:
        print("ERROR: GITHUB_TOKEN (or GH_TOKEN) not set in environment.", file=sys.stderr)
        return 2

    owner, repo = _detect_repo()
    url = f"https://api.github.com/repos/{owner}/{repo}/issues"
    payload = {
        "title": args.title,
        "body": args.body,
    }
    if args.label:
        payload["labels"] = args.label
    if args.assignee:
        payload["assignees"] = args.assignee

    import urllib.request

    req = urllib.request.Request(url, method="POST")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    data = json.dumps(payload).encode("utf-8")
    try:
        with urllib.request.urlopen(req, data=data) as r:  # nosec: B310
            resp = json.loads(r.read().decode("utf-8"))
    except Exception as e:
        print(f"ERROR: failed to create issue: {e}", file=sys.stderr)
        return 1

    number = resp.get("number")
    html_url = resp.get("html_url")
    if not number:
        print(f"ERROR: unexpected API response: {resp}", file=sys.stderr)
        return 1
    print(f"Created issue #{number}: {html_url}")
    print(f"Commit meta: issue: #{number}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

