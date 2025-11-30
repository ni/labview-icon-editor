#!/usr/bin/env python3
"""Post or update a PR comment suggesting pre-commit template sync.

Runs the sync script with --dry-run to capture pending changes and posts a
single sticky comment with exact commands to fix.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.request

MARKER = "<!-- pre-commit-template-sync -->"


def gh_request(method: str, url: str, token: str, payload: dict | None = None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "x-cli-precommit-sync-bot",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return resp.getcode(), json.loads(resp.read() or b"{}")


def post_or_update_comment(repo: str, pr: int, token: str, body: str) -> None:
    base = f"https://api.github.com/repos/{repo}"
    comments_url = f"{base}/issues/{pr}/comments?per_page=100"
    code, data = gh_request("GET", comments_url, token)
    existing = None
    if code == 200:
        for c in data:
            if isinstance(c, dict) and isinstance(c.get("body"), str) and MARKER in c["body"]:
                existing = c
                break
    msg = f"{MARKER}\n{body}"
    if existing:
        gh_request("PATCH", f"{base}/issues/comments/{existing['id']}", token, {"body": msg})
    else:
        gh_request("POST", f"{base}/issues/{pr}/comments", token, {"body": msg})


def run_dry_run() -> tuple[int, str]:
    try:
        cp = subprocess.run(
            [sys.executable, "scripts/sync_precommit_templates.py", "--dry-run"],
            capture_output=True,
            text=True,
            check=False,
        )
        out = (cp.stdout or "") + ("\n" + cp.stderr if cp.stderr else "")
        return cp.returncode, out.strip()
    except Exception as e:
        return 2, f"error invoking dry-run: {e}"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--pr", type=int, required=True)
    args = ap.parse_args(argv)

    tok = os.getenv("GITHUB_TOKEN") or os.getenv("ADMIN_TOKEN")
    if not tok:
        print("GITHUB_TOKEN not set", file=sys.stderr)
        return 2

    rc, msg = run_dry_run()
    if rc == 0:
        print("No template sync needed; skipping comment.")
        return 0

    server = os.getenv("GITHUB_SERVER_URL", "https://github.com").rstrip("/")
    repo = os.getenv("GITHUB_REPOSITORY", "").strip()
    sha = os.getenv("GITHUB_SHA", "").strip()
    commit_url = f"{server}/{repo}/commit/{sha}" if repo and sha else None
    # Try to fetch commit subject for extra context
    subject = None
    if repo and sha:
        try:
            base = f"https://api.github.com/repos/{repo}"
            code, data = gh_request("GET", f"{base}/commits/{sha}", tok)
            if code == 200:
                full = (data.get("commit") or {}).get("message") or ""
                subject = (full.splitlines()[0] if full else None)
        except Exception:
            subject = None
        # Local fallback (no network): git log -1 --pretty=%s <sha>
        if subject is None:
            try:
                import pathlib
                root = pathlib.Path(__file__).resolve().parents[1]
                cp = subprocess.run(["git", "log", "-1", "--pretty=%s", sha], cwd=root, capture_output=True, text=True)
                if cp.returncode == 0:
                    s = (cp.stdout or "").strip()
                    subject = s or None
            except Exception:
                pass

    suggestion = (
        "Pre-commit template sync is needed. Apply locally with one of:\n\n"
        "- `pre-commit run precommit-template-sync --all-files`\n"
        "- `python scripts/sync_precommit_templates.py`\n\n"
        + (f"Commit: [{sha[:7]}]({commit_url})" + (f" - {subject}" if subject else "") + "\n\n" if commit_url else "")
        + "Dry-run output:\n\n"
        + ("```\n" + msg + "\n```" if msg else "(no output)")
    )
    post_or_update_comment(args.repo, args.pr, tok, suggestion)
    print("Posted/updated pre-commit template sync suggestion.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
