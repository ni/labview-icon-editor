#!/usr/bin/env python3
"""Aggregate failing pre-commit checks and post a single PR comment with suggestions.

Parses pre-commit output to list failing hook IDs and shows targeted fix commands.
Also estimates file counts for selected hooks.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import json
import urllib.request
from pathlib import Path
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
MARKER = "<!-- pre-commit-aggregated-suggestions -->"
# Default hook links; may be overridden by scripts/precommit_hook_links.json
DEFAULT_HOOK_LINKS = {
    "actionlint": "https://github.com/rhysd/actionlint",
    "trailing-whitespace": "https://github.com/pre-commit/pre-commit-hooks#trailing-whitespace",
    "end-of-file-fixer": "https://github.com/pre-commit/pre-commit-hooks#end-of-file-fixer",
    "yaml-parse-ruamel": "scripts/check_yaml_ruamel.py",
    "agent-feedback": "scripts/check_agent_feedback.py",
    "srs-title-ascii": "scripts/check_srs_title_ascii.py",
    "commit-message": "scripts/check-commit-msg.py",
}

def load_hook_links() -> dict:
    cfg = ROOT / "scripts" / "precommit_hook_links.json"
    if cfg.exists():
        try:
            data = json.loads(cfg.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                merged = DEFAULT_HOOK_LINKS.copy()
                merged.update({str(k): str(v) for k, v in data.items()})
                return merged
        except Exception:
            pass
    return DEFAULT_HOOK_LINKS.copy()


def run_py(*args: str) -> int:
    try:
        return subprocess.run([sys.executable, *args], cwd=ROOT).returncode
    except Exception:
        return 1


def yaml_files() -> list[Path]:
    # Respect pre-commit config's excludes for YAML hooks
    excl = re.compile(r"(\.venv/|vendor/|^docs/srs/index.yaml$|^\.github/ISSUE_TEMPLATE/|^docs/templates/|^docs/knowledge/|^knowledge/)")
    files: list[Path] = []
    for p in list(ROOT.rglob("*.yml")) + list(ROOT.rglob("*.yaml")):
        rel = str(p.relative_to(ROOT)).replace("\\", "/")
        if excl.search(rel):
            continue
        files.append(p)
    return files


def has_trailing_whitespace(path: Path) -> bool:
    try:
        for ln in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            if re.search(r"[ \t]+$", ln):
                return True
        return False
    except Exception:
        return False


def missing_final_newline(path: Path) -> bool:
    try:
        txt = path.read_bytes()
        if not txt:
            return False
        return not txt.endswith(b"\n")
    except Exception:
        return False


def gh_request(method: str, url: str, token: str, payload: dict | None = None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "x-cli-precommit-bot",
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
        print(f"Updated PR comment {existing['id']}")
    else:
        gh_request("POST", f"{base}/issues/{pr}/comments", token, {"body": msg})
        print("Posted PR comment")


def get_artifact_info(repo: str, run_id: str, token: str, name: str = "pre-commit") -> tuple[str | None, int | None, str | None]:
    base = f"https://api.github.com/repos/{repo}"
    code, data = gh_request("GET", f"{base}/actions/runs/{run_id}/artifacts", token)
    if code != 200:
        return None, None, None
    arts = data.get("artifacts") or []
    target = None
    for a in arts:
        if isinstance(a, dict) and a.get("name") == name and not a.get("expired"):
            target = a
            break
    if not target:
        return None, None, None
    aid = target.get("id")
    if not aid:
        return None, None, None
    url = f"{base}/actions/artifacts/{aid}/zip"
    req = urllib.request.Request(url, method="GET", headers={
        "Authorization": f"token {token}",
        "Accept": "application/octet-stream",
        "User-Agent": "x-cli-precommit-bot",
    })
    class NoRedirect(urllib.request.HTTPErrorProcessor):
        def http_response(self, request, response):
            return response
        https_response = http_response
    opener = urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(req, timeout=10) as resp:
            signed = resp.headers.get("Location")
    except HTTPError as e:
        signed = e.headers.get("Location")
    except Exception:
        signed = None
    size = None
    created = None
    try:
        size = int(target.get("size_in_bytes")) if target.get("size_in_bytes") is not None else None
    except Exception:
        size = None
    created = target.get("created_at")
    return signed, size, created


def run_precommit_capture() -> tuple[list[str], set[str]]:
    """Run pre-commit and parse failing hook IDs.

    Returns (output_lines, failing_hook_ids)
    """
    failing: set[str] = set()
    lines: list[str] = []
    # Prefer JSON produced by parse_precommit_output.py
    json_path = ROOT / "artifacts" / "pre-commit.json"
    if json_path.exists():
        try:
            data = json.loads(json_path.read_text(encoding="utf-8"))
            lines = [str(x) for x in (data.get("lines") or [])]
            failing = set(str(x) for x in (data.get("failed_hooks") or []))
            return lines, failing
        except Exception:
            pass
    try:
        env = os.environ.copy()
        env.setdefault("SKIP", "actionlint")
        proc = subprocess.Popen(
            ["pre-commit", "run", "--all-files", "--verbose", "--color", "never"],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        header_re = re.compile(r"^(.+?)\.+(Failed|Passed|Skipped)$")
        id_re = re.compile(r"^\s*-\s*hook id:\s*([A-Za-z0-9_.-]+)\s*$")
        in_failed_block = False
        if proc.stdout:
            for ln in proc.stdout:
                ln = ln.rstrip("\n")
                lines.append(ln)
                m = header_re.match(ln.strip())
                if m:
                    in_failed_block = (m.group(2) == "Failed")
                    continue
                m2 = id_re.match(ln)
                if m2 and in_failed_block:
                    failing.add(m2.group(1))
        proc.wait(timeout=120)
    except Exception:
        pass
    return lines, failing


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--pr", required=True, type=int)
    args = ap.parse_args(argv)

    tok = os.getenv("GITHUB_TOKEN") or os.getenv("ADMIN_TOKEN")
    if not tok:
        print("GITHUB_TOKEN not set", file=sys.stderr)
        return 2

    # Parse pre-commit output
    pc_lines, pc_failing = run_precommit_capture()

    # Run repo-native checks for counts
    failed_srs = (run_py("scripts/check_srs_title_ascii.py") != 0)
    failed_yaml = (run_py("scripts/check_yaml_ruamel.py") != 0)
    failed_agent = (run_py("scripts/check_agent_feedback.py") != 0)

    # Count functions
    def count_srs_nonascii() -> int:
        h1 = re.compile(r"^#\s+(.+)$", re.M)
        cnt = 0
        srs_dir = ROOT / "docs/srs"
        for p in srs_dir.glob("*.md"):
            if p.name == "_template.md":
                continue
            t = p.read_text(encoding="utf-8", errors="ignore")
            m = h1.search(t)
            if not m:
                continue
            try:
                m.group(1).encode("ascii")
            except UnicodeEncodeError:
                cnt += 1
        return cnt

    tw_count = sum(1 for p in yaml_files() if has_trailing_whitespace(p))
    eof_count = sum(1 for p in yaml_files() if missing_final_newline(p))

    # Build summaries
    HOOK_LINKS = load_hook_links()
    def link_for(hid: str) -> str:
        url = HOOK_LINKS.get(hid)
        return f" ([docs]({url}))" if url else ""

    hook_summaries: list[str] = []
    for hid in sorted(pc_failing):
        if hid == "srs-title-ascii" and failed_srs:
            hook_summaries.append(f"- {hid}: {count_srs_nonascii()} files{link_for(hid)}")
        elif hid == "yaml-parse-ruamel" and failed_yaml:
            hook_summaries.append(f"- {hid}: see output{link_for(hid)}")
        elif hid == "trailing-whitespace" and tw_count:
            hook_summaries.append(f"- {hid}: {tw_count} files{link_for(hid)}")
        elif hid == "end-of-file-fixer" and eof_count:
            hook_summaries.append(f"- {hid}: {eof_count} files{link_for(hid)}")
        elif hid == "agent-feedback" and failed_agent:
            hook_summaries.append(f"- {hid}: failed{link_for(hid)}")
        else:
            hook_summaries.append(f"- {hid}{link_for(hid)}")

    # Suggestions
    suggestions: list[str] = []
    if failed_srs:
        suggestions.append("- SRS H1 ASCII: `pre-commit run srs-title-ascii-fix --all-files`.")
    if failed_yaml:
        suggestions.append("- YAML parse: `python scripts/check_yaml_ruamel.py` (fix syntax).")
    if tw_count:
        suggestions.append("- Trailing whitespace: `pre-commit run trailing-whitespace --all-files`.")
    if eof_count:
        suggestions.append("- Final newline: `pre-commit run end-of-file-fixer --all-files`.")
    if failed_agent:
        suggestions.append("- Agent feedback: `python scripts/check_agent_feedback.py`.")

    if not pc_failing and not suggestions:
        print("No tailored suggestions to post.")
        return 0

    # Link to artifacts on the workflow run page (where logs/JSON are uploaded)
    server = os.getenv("GITHUB_SERVER_URL", "https://github.com").rstrip("/")
    repo = os.getenv("GITHUB_REPOSITORY", "").strip()
    run_id = os.getenv("GITHUB_RUN_ID", "").strip()
    run_url = f"{server}/{repo}/actions/runs/{run_id}" if repo and run_id else None

    header = "Some pre-commit checks failed.\n\nFailed hooks:\n" + ("\n".join(hook_summaries) if hook_summaries else "- (unable to parse)")
    body = header + "\n\nTargeted suggestions:\n\n" + ("\n".join(suggestions) if suggestions else "- (no tailored suggestions)")
    body += "\n\nRun `pre-commit run --all-files` to attempt auto-fixes in one go."
    if run_url:
        # Helper to format bytes to human-readable
        def human_size(n: int) -> str:
            units = ["bytes","KB","MB","GB","TB"]
            s = float(n)
            i = 0
            while s >= 1024 and i < len(units)-1:
                s /= 1024.0
                i += 1
            return f"{s:.1f} {units[i]}" if i > 0 else f"{int(s)} {units[i]}"

        body += f"\n\nArtifacts: [pre-commit logs]({run_url}) (see Artifacts section)."
        # Build a small table with size and created time
        signed, size, created = (None, None, None)
        if repo and run_id:
            signed, size, created = get_artifact_info(repo, run_id, tok)
        table = [
            "",
            "| Artifact | Size | Created | Download |",
            "|---|---:|---|---|",
        ]
        sz = human_size(size) if isinstance(size, int) else "(unknown)"
        dl = f"[pre-commit.zip]({signed})" if signed else "(pending)"
        cr = created or "(unknown)"
        table.append(f"| pre-commit | {sz} | {cr} | {dl} |")
        body += "\n" + "\n".join(table)

    post_or_update_comment(args.repo, args.pr, tok, body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
