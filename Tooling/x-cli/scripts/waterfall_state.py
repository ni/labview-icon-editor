#!/usr/bin/env python3
"""Waterfall state manager.

SRS: FGC-REQ-CI-002, FGC-REQ-CI-014
AC map:
- FGC-REQ-CI-002 AC1 – parse `.codex/state.json` and validate `stage:*` labels.
- FGC-REQ-CI-014 AC1 – lock prior stages and persist state on advancement.
- FGC-REQ-CI-014 AC2 – retain the current label when exit criteria fail.
- FGC-REQ-CI-014 AC3 – enforce entry prerequisites.

This module shall track pull-request stage transitions, validate objective
exit criteria, and block relabeling of locked stages. State writes shall commit
`.codex/state.json` only when executed in CI to keep local runs clean.
"""
from __future__ import annotations
import json, os, subprocess, sys, time
from pathlib import Path
import shutil

STAGES = ["requirements","design","implementation","testing","deployment"]
LABEL_PREFIX = "stage:"
STATE_PATH = Path(".codex/state.json")

def _sh(*args, check=True, capture=False):
    if capture:
        return subprocess.check_output(args, text=True)
    return subprocess.run(args, check=check)

def _has_gh() -> bool:
    return shutil.which("gh") is not None

def _gh_json(*args):
    if not _has_gh():
        return {}
    try:
        out = _sh("gh", *args, capture=True)
    except Exception:
        return {}
    return json.loads(out) if out.strip() else {}

def _event_load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))

def _pr_ctx(repo: str, ev: dict):
    pr = ev.get("pull_request") or {}
    number = pr.get("number") or ev.get("number")
    sha = (pr.get("head") or {}).get("sha") or ev.get("after") or ""
    labels = [l["name"] for l in pr.get("labels",[])]
    return int(number) if number else None, sha, labels

def label_get_current(labels: list[str]) -> str:
    for l in labels:
        if l.startswith(LABEL_PREFIX):
            return l.split(":",1)[1]
    return "requirements"

def next_stage(cur: str) -> str|None:
    try:
        i = STAGES.index(cur)
        return STAGES[i+1] if i+1 < len(STAGES) else None
    except ValueError:
        return None

def _criteria_ok(stage: str, repo: str, sha: str) -> bool:
    # Keep objective and deterministic. Network checks only where necessary.
    if stage == "requirements":
        # SRS index exists; optional smoke if present.
        if not Path("docs/srs/index.yaml").exists():
            return False
        if Path("scripts/srs_maintenance_smoke.py").exists():
            r = subprocess.run(["python","scripts/srs_maintenance_smoke.py"])
            if r.returncode != 0: 
                return False
        return True
    if stage == "design":
        d = Path("docs/Design.md")
        return d.exists() and "Status: Approved" in d.read_text(encoding="utf-8", errors="ignore")
    if stage == "implementation":
        st = _gh_json("api", f"repos/{repo}/commits/{sha}/status")
        # Look for Linux & Windows success OR combined success
        statuses = [s.get("context", "").lower() + ":" + s.get("state", "") for s in st.get("statuses", [])]
        want = all(any(os in c and ":success" in c for c in statuses) for os in ("linux","windows"))
        return want or st.get("state") == "success"
    if stage == "testing":
        # Require artifact produced in Stage 2
        arts = _gh_json("api", f"repos/{repo}/actions/artifacts")
        names = [a.get("name","") for a in arts.get("artifacts",[])]
        return any(n == "water-stage2-artifacts" for n in names)
    if stage == "deployment":
        return True
    return False

def _read_state() -> dict:
    if STATE_PATH.exists():
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    return {"current_stage":"requirements","locked":[], "history":[]}

def _write_state(st: dict):
    text = json.dumps(st, indent=2) + "\n"
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    prior = STATE_PATH.read_text(encoding="utf-8") if STATE_PATH.exists() else ""
    if text != prior:
        STATE_PATH.write_text(text, encoding="utf-8")
        # Commit only on CI in a repo context; no-op during local/unit tests.
        if os.getenv("GITHUB_ACTIONS") == "true" and (Path(".git").exists()):
            # Skip committing if the path is ignored by .gitignore
            try:
                res = subprocess.run(["git","check-ignore","-q", str(STATE_PATH)], check=False)
                is_ignored = (res.returncode == 0)
            except Exception:
                is_ignored = False
            if not is_ignored:
                _sh("git","add",str(STATE_PATH), check=False)
                _sh("git","commit","-m","ci: update waterfall state [skip ci]", check=False)
            else:
                print(f"info: skipping commit of {STATE_PATH} (ignored by .gitignore)")

def _apply_labels(repo: str, pr: int, remove: str|None, add: str|None):
    try:
        if remove:
            subprocess.run(["gh","pr","edit",str(pr),"-R",repo,"--remove-label",remove], check=False)
        if add:
            subprocess.run(["gh","pr","edit",str(pr),"-R",repo,"--add-label",add], check=False)
    except Exception as exc:
        print(f"warning: failed to update labels: {exc}", file=sys.stderr)

def _advance(repo: str, ev_path: str, commit_msg: str):
    ev = _event_load(ev_path)
    pr, sha, labels = _pr_ctx(repo, ev)
    if not pr:
        print("No PR context found; nothing to advance.")
        return
    cur = label_get_current(labels)
    st = _read_state()
    st["current_stage"] = cur
    if not _criteria_ok(cur, repo, sha):
        _write_state(st); return
    nxt = next_stage(cur)
    if not nxt:
        _write_state(st); return
    if cur not in st["locked"]:
        st["locked"].append(cur)
    st["history"].append({"from":cur,"to":nxt,"ts":int(time.time())})
    st["current_stage"] = nxt
    _write_state(st)
    # label move
    _apply_labels(repo, pr, f"{LABEL_PREFIX}{cur}", f"{LABEL_PREFIX}{nxt}")
    # Push state commit if created (skip if no changes)
    if os.getenv("GITHUB_ACTIONS") == "true" and Path(".git").exists():
        subprocess.run(["git","push"], check=False)

def _validate(repo: str, ev_path: str):
    ev = _event_load(ev_path)
    pr, sha, labels = _pr_ctx(repo, ev)
    cur = label_get_current(labels)
    st = _read_state()
    if cur not in STAGES:
        print(f"Invalid: unknown stage '{cur}'"); sys.exit(1)
    # Illegal: relabel to a stage that's already locked
    if cur in st.get("locked",[]):
        print(f"Invalid: current label '{cur}' is already locked"); sys.exit(1)
    # Preconditions
    if cur == "implementation" and not Path("docs/Design.md").exists():
        print("Invalid: entering implementation without docs/Design.md"); sys.exit(1)
    if cur == "testing" and not Path("docs/srs/index.yaml").exists():
        print("Invalid: entering testing without SRS index"); sys.exit(1)
    # State integrity (light)
    if st.get("current_stage") not in STAGES:
        print("Invalid: state current_stage corrupt"); sys.exit(1)
    print("Waterfall state OK.")

if __name__ == "__main__":
    # Usage:
    #   python scripts/waterfall_state.py advance --event PATH --repo owner/repo --commit-msg "..."
    #   python scripts/waterfall_state.py validate --event PATH --repo owner/repo
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    ev = None; repo = None; msg = "ci: waterfall advance [skip ci]"
    for i,a in enumerate(sys.argv):
        if a == "--event": ev = sys.argv[i+1]
        if a == "--repo": repo = sys.argv[i+1]
        if a == "--commit-msg": msg = sys.argv[i+1]
    if mode == "advance":
        _advance(repo, ev, msg)
    elif mode == "validate":
        _validate(repo, ev)
    else:
        print("unknown mode"); sys.exit(2)
