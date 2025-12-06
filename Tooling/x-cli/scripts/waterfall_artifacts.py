#!/usr/bin/env python3
"""Check artifact hand-off for waterfall deployment.

SRS: FGC-REQ-CI-015
AC map: FGC-REQ-CI-015 AC1
This script shall warn when a pull request labeled `stage:deployment` lacks the
Stage 2 hand-off artifact `water-stage2-artifacts` but shall still exit with
status 0 to avoid blocking advancement.
"""
from __future__ import annotations
import json, os, subprocess, sys

def _gh_json(*args):
    return json.loads(subprocess.check_output(["gh", *args], text=True) or "{}")

gh_json = _gh_json  # allow patching in tests

def ensure(event: str, repo: str) -> int:
    ev = json.loads(open(event,"r",encoding="utf-8").read())
    pr = ev.get("pull_request") or {}
    labels = {l["name"] for l in pr.get("labels",[])}
    if "stage:deployment" not in labels:
        return 0
    try:
        arts = gh_json("api", f"repos/{repo}/actions/artifacts")
        names = [a.get("name","") for a in arts.get("artifacts",[])]
    except Exception as exc:
        print(f"warning: failed to fetch artifacts: {exc}", file=sys.stderr)
        return 0
    # AC1 (FGC-REQ-CI-015): warn (exit 0) when the Stage 2 hand-off artifact is missing
    if "water-stage2-artifacts" not in names:
        print("warning: required artifact 'water-stage2-artifacts' missing; Stage 3 deployment will fail")
    return 0

if __name__ == "__main__":
    mode = sys.argv[1]
    ev, repo = None, None
    for i,a in enumerate(sys.argv):
        if a == "--event": ev = sys.argv[i+1]
        if a == "--repo": repo = sys.argv[i+1]
    if mode == "ensure":
        sys.exit(ensure(ev, repo))
    sys.exit(0)

