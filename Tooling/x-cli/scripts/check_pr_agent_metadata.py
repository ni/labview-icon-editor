#!/usr/bin/env python3
"""Ensure PR body includes Agent Checklist and correct AGENTS.md digest (FGC-REQ-CI-017)."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

DEFAULT_PR_PATH = Path("PR_DESCRIPTION.md")
DEFAULT_AGENTS_PATH = Path("AGENTS.md")
ARTIFACT_PATH = Path("artifacts/agents-contract-validation.jsonl")


def _load_text(path: Path | None) -> str:
    if path and path.exists():
        return path.read_text(encoding="utf-8")
    if DEFAULT_PR_PATH.exists():
        return DEFAULT_PR_PATH.read_text(encoding="utf-8")
    return os.environ.get("PR_BODY", "")


def _compute_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _append_result(check: str, passed: bool, details: str) -> None:
    ARTIFACT_PATH.parent.mkdir(parents=True, exist_ok=True)
    entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "check": check,
        "status": "pass" if passed else "fail",
        "details": details,
    }
    with ARTIFACT_PATH.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry) + "\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate Agent Checklist and AGENTS.md digest lines in PR body",
    )
    parser.add_argument("path", nargs="?", help="file containing PR description")
    parser.add_argument(
        "--digest",
        help="expected SHA256 digest for AGENTS.md; computed automatically when omitted",
    )
    args = parser.parse_args(argv)

    text = _load_text(Path(args.path) if args.path else None)
    if not text:
        _append_result("agent-checklist", False, "no PR description text found")
        _append_result("agents-md-digest", False, "no PR description text found")
        print("no PR description text found", file=sys.stderr)
        return 1

    ok = True

    # Agent Checklist
    checklist_present = bool(re.search(r"##\s*Agent Checklist", text, re.IGNORECASE) and re.search(r"- \[(?: |x)\]", text))
    if not checklist_present:
        _append_result("agent-checklist", False, "Agent Checklist missing or empty")
        print("agent checklist missing or empty", file=sys.stderr)
        ok = False
    else:
        _append_result("agent-checklist", True, "Agent Checklist present")

    # AGENTS.md digest
    agents_path = DEFAULT_AGENTS_PATH
    expected = args.digest or _compute_digest(agents_path)
    digest_pattern = rf"{re.escape(str(agents_path))} digest: SHA256 {expected}"
    digest_present = bool(re.search(digest_pattern, text, re.IGNORECASE))
    if not digest_present:
        _append_result(
            "agents-md-digest",
            False,
            f"AGENTS.md digest line missing or incorrect (expected SHA256 {expected})",
        )
        print("AGENTS.md digest line missing or incorrect", file=sys.stderr)
        ok = False
    else:
        _append_result("agents-md-digest", True, "AGENTS.md digest line present and correct")

    if ok:
        print("agent checklist and AGENTS.md digest valid")
        return 0
    return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
