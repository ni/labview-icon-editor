#!/usr/bin/env python3
"""Best-effort enrichment of the commit summary (line 1).

Adds concise context in square brackets at the end of the summary while
respecting the 50-character limit enforced by check-commit-msg.py.

Signals (optional):
- GITHUB_RUN_ATTEMPT: when present, adds "[rN]" (run attempt N)
- XCLI_SUMMARY_TAGS: space/comma-separated tags -> "[tag1 tag2]"
- Automatic increment: if HEAD summary base matches current base, add
  "[nK]" where K = previous counter + 1. This does not persist state.

If enrichment would exceed 50 chars, tags are dropped first, then the
automatic counter. If still too long, no changes are made.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple


def _strip_trailing_brackets(text: str) -> str:
    # Remove one or more trailing bracket groups (e.g., "[...]" blocks)
    out = text.rstrip()
    while True:
        new = re.sub(r"\s*\[[^\]]*\]\s*$", "", out)
        if new == out:
            return out
        out = new


def _head_summary_base() -> tuple[str, int]:
    try:
        cp = subprocess.run(
            ["git", "log", "-1", "--pretty=%s"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        head = cp.stdout.strip()
    except Exception:
        return "", 0
    base = _strip_trailing_brackets(head)
    # Attempt to extract the highest known counter from tokens like nK or rK
    tokens = re.findall(r"\[(.*?)\]", head)
    max_n = 0
    for t in tokens:
        for part in t.split():
            m = re.match(r"[nr](\d+)$", part)
            if m:
                max_n = max(max_n, int(m.group(1)))
    return base, max_n


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        return 0
    path = Path(argv[1])
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return 0

    lines = text.splitlines()
    if not lines:
        return 0

    # Find the first non-comment line (the summary)
    idx = next((i for i, l in enumerate(lines) if not l.startswith("#")), None)
    if idx is None:
        return 0
    summary = lines[idx]
    base = _strip_trailing_brackets(summary)

    # Build tokens
    tokens: List[str] = []
    run_attempt = os.getenv("GITHUB_RUN_ATTEMPT")
    if run_attempt and run_attempt.isdigit():
        tokens.append(f"r{int(run_attempt)}")

    head_base, head_n = _head_summary_base()
    if head_base and head_base.lower() == base.lower():
        # Increment from the highest seen counter
        if head_n > 0:
            tokens.append(f"n{head_n + 1}")
        else:
            tokens.append("n2")  # second attempt

    tags_env = os.getenv("XCLI_SUMMARY_TAGS", "").strip()
    if tags_env:
        raw = re.split(r"[\s,;]+", tags_env)
        tags = [t for t in (s.strip() for s in raw) if t]
        if tags:
            # Keep short tags only (<=6 chars) to stay within 50 chars
            short = [t[:6] for t in tags]
            tokens.extend(short)

    suffix = f" [{' '.join(tokens)}]" if tokens else ""
    candidate = f"{base}{suffix}" if base else summary

    # Enforce 50-char limit by trimming tokens if needed
    kept_tokens: List[str] = list(tokens)
    dropped_tokens: List[str] = []
    if len(candidate) > 50 and tokens:
        # Drop tags first (anything not starting with r/n)
        core = [t for t in tokens if t.startswith("r") or t.startswith("n")]
        dropped_tokens = [t for t in tokens if t not in core]
        kept_tokens = core
        suffix = f" [{' '.join(core)}]" if core else ""
        candidate = f"{base}{suffix}" if base else summary
    if len(candidate) > 50 and kept_tokens:
        # If still long, drop all tokens
        dropped_tokens.extend(kept_tokens)
        kept_tokens = []
        candidate = base

    if candidate and candidate != summary and len(candidate) <= 50:
        lines[idx] = candidate
        # Preserve newline style: join with '\n' and add trailing newline if present originally
        out = "\n".join(lines)
        if text.endswith("\n"):
            out += "\n"
        path.write_text(out, encoding="utf-8")
        # If we had to drop tokens to fit the 50-char summary, persist them
        # as a trailer line at the end of the commit message for portability.
        if dropped_tokens:
            try:
                tag_line = f"X-Tags: {' '.join(tokens)}\n"
                with path.open("a", encoding="utf-8") as fh:
                    fh.write(tag_line)
            except Exception:
                pass

    # Persist full context for later correlation (post-commit)
    try:
        payload = {
            "source": "commit-summary-enrich",
            "original_summary": summary,
            "base_summary": base,
            "candidate_summary": candidate,
            "kept_tokens": kept_tokens,
            "dropped_tokens": dropped_tokens,
            "attempt": os.getenv("GITHUB_RUN_ATTEMPT"),
            "tags_env": os.getenv("XCLI_SUMMARY_TAGS", ""),
        }
        codex_dir = Path(".codex")
        codex_dir.mkdir(parents=True, exist_ok=True)
        (codex_dir / "commit-msg-memory.tmp.json").write_text(
            __import__("json").dumps(payload, indent=2), encoding="utf-8"
        )
    except Exception:
        # Non-fatal
        pass

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main(sys.argv))
