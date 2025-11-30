#!/usr/bin/env python3
"""Validate Stage 1 invocation metadata and run the codex agent."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = ROOT / ".codex" / "schema" / "invoke.schema.json"
TECH_DEBT_SCRIPT = ROOT / "scripts" / "check-tech-debt.sh"
DESIGN_VALIDATE_SCRIPT = ROOT / "scripts" / "validate_design.py"
SRS_DOCS_DIR = ROOT / "docs" / "srs"
STAGE1_RUN_FILE = ROOT / ".codex" / "stage1_run_id"
WORKFLOW_FILE = "stage1-telemetry.yml"


def _github_headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "stage1-dispatcher",
    }


def _resolve_repo() -> str:
    repo = os.environ.get("GITHUB_REPOSITORY")
    if repo:
        return repo
    try:
        url = (
            subprocess.run(
                ["git", "config", "--get", "remote.origin.url"],
                check=True,
                capture_output=True,
                text=True,
            )
            .stdout.strip()
        )
    except subprocess.CalledProcessError as exc:  # pragma: no cover - git failure
        raise RuntimeError("Unable to determine repository") from exc
    if url.endswith(".git"):
        url = url[:-4]
    if url.startswith("https://github.com/"):
        return url.split("https://github.com/")[-1]
    if url.startswith("git@github.com:"):
        return url.split("git@github.com:")[-1]
    raise RuntimeError("Cannot parse repository name from remote URL")


def _latest_run_id(repo: str, branch: str, token: str) -> int | None:
    url = (
        f"https://api.github.com/repos/{repo}/actions/workflows/{WORKFLOW_FILE}/runs"
        f"?branch={branch}&event=workflow_dispatch&per_page=1"
    )
    req = urllib.request.Request(url, headers=_github_headers(token))
    with urllib.request.urlopen(req) as resp:  # pragma: no cover - network
        data = json.load(resp)
    runs = data.get("workflow_runs", [])
    return runs[0]["id"] if runs else None


def _dispatch_stage1(repo: str, ref: str, branch: str, token: str) -> int:
    """Dispatch Stage 1 Telemetry workflow and return its run ID."""

    before = _latest_run_id(repo, branch, token)
    url = f"https://api.github.com/repos/{repo}/actions/workflows/{WORKFLOW_FILE}/dispatches"
    data = json.dumps({"ref": ref}).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=_github_headers(token))
    with urllib.request.urlopen(req) as resp:  # pragma: no cover - network
        if resp.getcode() not in (201, 204):
            raise RuntimeError(f"Dispatch failed with status {resp.getcode()}")
        resp.read()

    run_id = None
    for _ in range(10):  # pragma: no cover - network timing
        time.sleep(1)
        run_id = _latest_run_id(repo, branch, token)
        if run_id and run_id != before:
            break
    if not run_id:
        raise RuntimeError("Unable to determine Stage 1 Telemetry run ID")
    STAGE1_RUN_FILE.write_text(str(run_id), encoding="utf-8")
    print(f"Dispatched Stage 1 Telemetry: run id {run_id}")
    return run_id


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate Stage 1 invocation metadata and optionally dispatch telemetry",
    )
    parser.add_argument("payload", help="Path to payload JSON file")
    parser.add_argument(
        "--dispatch-telemetry",
        action="store_true",
        help="Dispatch Stage 1 telemetry workflow after command succeeds",
    )
    parser.add_argument("--token", help="GitHub token (default: env GITHUB_TOKEN)")
    parser.add_argument(
        "cmd",
        nargs=argparse.REMAINDER,
        help="Command to run after validation (prefix with --)",
    )
    ns = parser.parse_args(argv)

    try:
        subprocess.run([str(TECH_DEBT_SCRIPT)], check=True)
    except subprocess.CalledProcessError:
        print(
            "Technical debt check failed. Resolve the reported items before running Stage 1.",
            file=sys.stderr,
        )
        return 1

    try:
        subprocess.run([sys.executable, str(DESIGN_VALIDATE_SCRIPT)], check=True)
    except subprocess.CalledProcessError:
        print("Design document validation failed. See errors above.", file=sys.stderr)
        return 1

    payload_path = Path(ns.payload)
    with payload_path.open(encoding="utf-8") as f:
        payload = json.load(f)

    with SCHEMA_PATH.open(encoding="utf-8") as f:
        schema = json.load(f)

    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(payload), key=lambda e: e.path)
    if errors:
        for err in errors:
            location = "/".join(map(str, err.path)) or "<root>"
            print(f"{location}: {err.message}", file=sys.stderr)
        return 1

    missing_ids = [
        sid
        for sid in payload.get("srs_ids", [])
        if not (SRS_DOCS_DIR / f"{sid.upper()}.md").exists()
    ]
    if missing_ids:
        joined = ", ".join(missing_ids)
        print(
            "Unknown SRS IDs: "
            f"{joined}. Register new requirements via src/SrsApi before running Stage 1.",
            file=sys.stderr,
        )
        return 1

    print("Payload validated.")

    if ns.cmd:
        subprocess.run(ns.cmd, check=True)

    if ns.dispatch_telemetry:
        token = ns.token or os.environ.get("GITHUB_TOKEN")
        if not token:
            print("GitHub token required for telemetry dispatch", file=sys.stderr)
            return 1
        repo = _resolve_repo()
        branch = (
            subprocess.run(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
        )
        ref = branch
        try:
            _dispatch_stage1(repo, ref, branch, token)
        except Exception as exc:  # pragma: no cover - network
            print(f"Failed to dispatch Stage 1 telemetry: {exc}", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":  # pragma: no cover - script entrypoint
    raise SystemExit(main())
