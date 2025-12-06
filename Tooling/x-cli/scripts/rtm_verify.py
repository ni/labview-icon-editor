#!/usr/bin/env python3
"""
RTM gate: verify Req→Test→Code links for changed requirements or touched src/**
- Loads docs/traceability.yaml.
- Detects changed files (PR diff if possible).
- For req entries whose `source` changed or whose `code` globs match a changed src/** file:
  * ID must match ^FGC-REQ-[A-Z]+-\\d{3,}$
  * `tests` and `code` must list at least 1 existing path each (globs expanded)
Exits non-zero on gaps and prints a compact table.
"""
from __future__ import annotations
import os, re, sys, subprocess, glob
from pathlib import Path
from ruamel.yaml import YAML

ROOT = Path(__file__).resolve().parents[1]

ID_RE = re.compile(r"^FGC-REQ-[A-Z]+-\d{3,}$")

def git_changed_files() -> list[str]:
    # Prefer PR base/head if available
    base = os.getenv("GITHUB_BASE_REF")
    if base:
        # Fetch base to ensure diff works in Actions
        try:
            subprocess.run(["git","fetch","origin", base], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
        cmd = ["git","diff","--name-only", f"origin/{base}...HEAD"]
    else:
        cmd = ["git","diff","--name-only","HEAD~1","HEAD"]
    try:
        out = subprocess.check_output(cmd, text=True).strip()
        return [line.strip() for line in out.splitlines() if line.strip()]
    except Exception:
        return []

def main() -> int:
    mapping_path = ROOT / "docs" / "traceability.yaml"
    if not mapping_path.exists():
        print("docs/traceability.yaml not found", file=sys.stderr)
        return 2

    changed = set(git_changed_files())
    # Treat edits to the mapping file or docs/srs as "requirements changed"
    req_changed = any(p.startswith("docs/traceability.yaml") or p.startswith("docs/srs/") for p in changed)
    code_touched = {p for p in changed if p.startswith("src/")}

    y = YAML(typ="safe")
    data = y.load(mapping_path.read_text(encoding="utf-8")) or {}
    rows = []
    errs = []

    reqs = data.get("requirements") or []
    for ent in reqs:
        rid = (ent.get("id") or "").strip()
        src = (ent.get("source") or "").strip()
        code_globs = ent.get("code") or []
        tests = ent.get("tests") or []

        # Determine if this entry is in-scope for this PR
        in_scope = False
        if req_changed and src:
            in_scope = True
        if code_touched:
            for g in code_globs:
                for c in code_touched:
                    # crude glob match
                    if glob.fnmatch.fnmatch(c, g) or c.endswith(g.lstrip("./")):
                        in_scope = True
                        break
                if in_scope: break
        if not in_scope:
            continue

        rid_ok = bool(ID_RE.fullmatch(rid))
        code_expanded = sorted({p for g in code_globs for p in glob.glob(g, recursive=True)})
        tests_expanded = sorted({p for g in tests for p in glob.glob(g, recursive=True)})
        src_ok = (Path(src).exists()) if src else False
        code_ok = len(code_expanded) > 0
        tests_ok = len(tests_expanded) > 0

        if not rid_ok or not src_ok or not code_ok or not tests_ok:
            errs.append((rid or "(missing id)", rid_ok, src, src_ok, code_globs, code_ok, tests, tests_ok))

    if errs:
        # Context: show the changed file set to aid triage
        if changed:
            print("Changed files:")
            for p in sorted(changed):
                print(f"- {p}")
            print("")

        print("| ReqID | ID shape | source exists | code linked | tests linked |")
        print("|---|:---:|:---:|:---:|:---:|")
        for rid, rid_ok, src, src_ok, code_globs, code_ok, tests, tests_ok in errs:
            print(f"| {rid} | {'✅' if rid_ok else '❌'} | {'✅' if src_ok else '❌'} | {'✅' if code_ok else '❌'} | {'✅' if tests_ok else '❌'} |")

        # Detailed reasons per requirement
        print("\nDetails:")
        for rid, rid_ok, src, src_ok, code_globs, code_ok, tests, tests_ok in errs:
            reasons = []
            if not rid_ok:
                reasons.append("invalid id shape")
            if not src_ok:
                reasons.append(f"missing source: {src or '(none)'}")
            if not code_ok:
                reasons.append(f"no code paths found for globs: {code_globs or '[]'}")
            if not tests_ok:
                reasons.append(f"no tests found for globs: {tests or '[]'}")
            print(f"- {rid or '(missing id)'}: " + "; ".join(reasons))
        sys.exit(1)

    print("RTM OK (no gaps for changed requirements / touched src/**).")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
