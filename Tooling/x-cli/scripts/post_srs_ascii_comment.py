#!/usr/bin/env python3
"""Post or update a PR comment suggesting the SRS ASCII H1 fixer.

Behavior:
- Looks for an existing comment containing the marker.
- If present, updates it; else creates a new comment.

Inputs:
- --repo <owner/name>
- --pr <number>
- GITHUB_TOKEN in env

Message includes the exact fixer command and a short rationale.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request

MARKER = "<!-- srs-title-ascii-lint -->"
FIX_CMD = "pre-commit run srs-title-ascii-fix --all-files"


def gh_request(method: str, url: str, token: str, payload: dict | None = None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "x-cli-srs-ascii-bot",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return resp.getcode(), json.loads(resp.read() or b"{}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, help="owner/name")
    ap.add_argument("--pr", type=int, required=True)
    args = ap.parse_args(argv)

    tok = os.getenv("GITHUB_TOKEN") or os.getenv("ADMIN_TOKEN")
    if not tok:
        print("GITHUB_TOKEN not set", file=sys.stderr)
        return 2

    base = f"https://api.github.com/repos/{args.repo}"
    comments_url = f"{base}/issues/{args.pr}/comments?per_page=100"
    code, body = gh_request("GET", comments_url, tok)
    if code != 200:
        print(f"failed to list PR comments: HTTP {code}", file=sys.stderr)
        return 1
    existing = None
    for c in body:
        if isinstance(c, dict) and isinstance(c.get("body"), str) and MARKER in c["body"]:
            existing = c
            break

    message = (
        f"{MARKER}\n"
        "SRS H1 ASCII lint is failing.\n\n"
        "To auto-fix SRS titles locally, run:\n"
        f"  `{FIX_CMD}`\n\n"
        "If fixes are intentional, commit and push to re-run CI."
    )

    if existing:
        update_url = f"{base}/issues/comments/{existing['id']}"
        gh_request("PATCH", update_url, tok, {"body": message})
        print(f"Updated PR comment {existing['id']} with fix suggestion.")
    else:
        post_url = f"{base}/issues/{args.pr}/comments"
        gh_request("POST", post_url, tok, {"body": message})
        print("Posted PR comment with fix suggestion.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

