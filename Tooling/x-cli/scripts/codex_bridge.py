#!/usr/bin/env python3
"""
Codex ⇄ LLM 2-way bridge for ChatOps.
Triggers on /codex commands in issue/PR comments or via workflow_dispatch.

Commands:
  /codex init                  → start/ensure a session
  /codex ping                  → health check (“pong”)
  /codex policy                → show policy information
  /codex say <message>         → send <message> to the LLM and post reply
  /codex propose <task>        → ask LLM for a single unified diff; persist proposal
  /codex apply [<id>|latest]   → validate + apply stored proposal, open draft PR
  /codex state                 → short session status
  /codex end                   → close session

State is persisted under .codex/sessions/<thread-id>.json and committed with [skip ci].
System prompt lives at .codex/system/codex-bridge.md (editable).
"""
from __future__ import annotations
import argparse, json, os, re, subprocess, sys, time, shlex
from pathlib import Path
from typing import Dict, List, Any, Optional
import requests

GITHUB_API = "https://api.github.com"

def load_event(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def gh_headers(token: str) -> Dict[str, str]:
    return {"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}

def post_issue_comment(token: str, owner: str, repo: str, number: int, body: str):
    url = f"{GITHUB_API}/repos/{owner}/{repo}/issues/{number}/comments"
    r = requests.post(url, headers=gh_headers(token), json={"body": body}, timeout=60)
    r.raise_for_status()

def detect_thread_context(ev: Dict[str, Any]) -> Dict[str, Any]:
    # Issue comment
    if ev.get("issue"):
        number = ev["issue"]["number"]
        owner = ev["repository"]["owner"]["login"]
        repo  = ev["repository"]["name"]
        comment = ev["comment"]["body"]
        actor = ev["comment"]["user"]["login"]
        return {"owner": owner, "repo": repo, "number": number, "comment": comment, "actor": actor}
    # PR review comment
    if ev.get("pull_request") or ev.get("comment"):
        number = ev.get("issue",{}).get("number") or ev.get("pull_request",{}).get("number") or ev.get("pull_request",{}).get("number")
        owner = ev["repository"]["owner"]["login"]
        repo  = ev["repository"]["name"]
        comment = ev["comment"]["body"]
        actor = ev["comment"]["user"]["login"]
        return {"owner": owner, "repo": repo, "number": number, "comment": comment, "actor": actor}
    # Manual dispatch fallback
    owner = ev["repository"]["owner"]["login"]
    repo  = ev["repository"]["name"]
    number = ev.get("inputs",{}).get("issue_number") or 0
    msg = ev.get("inputs",{}).get("message")
    return {"owner": owner, "repo": repo, "number": int(number), "comment": f"/codex say {msg}" if msg else "/codex ping", "actor": ev["sender"]["login"]}

def ensure_dirs():
    Path(".codex/system").mkdir(parents=True, exist_ok=True)
    Path(".codex/sessions").mkdir(parents=True, exist_ok=True)
    Path(".codex/proposals").mkdir(parents=True, exist_ok=True)

def load_system_prompt() -> str:
    p = Path(".codex/system/codex-bridge.md")
    return p.read_text(encoding="utf-8") if p.exists() else "You are an engineering copilot. Be concise, actionable, and safe."

def sess_path(thread_id: str) -> Path:
    return Path(f".codex/sessions/{thread_id}.json")

def prop_dir(thread_id: str) -> Path:
    d = Path(f".codex/proposals/{thread_id}")
    d.mkdir(parents=True, exist_ok=True)
    return d

def next_proposal_id(thread_id: str) -> str:
    d = prop_dir(thread_id)
    existing = sorted([p.stem for p in d.glob("*.patch")])
    n = len(existing) + 1
    return f"p{n:03d}"

def save_proposal(thread_id: str, pid: str, diff_text: str) -> Path:
    p = prop_dir(thread_id) / f"{pid}.patch"
    p.write_text(diff_text, encoding="utf-8")
    subprocess.run(["git","config","user.email","codex-bot@users.noreply.github.com"], check=False)
    subprocess.run(["git","config","user.name","codex-bot"], check=False)
    subprocess.run(["git","add", str(p)], check=False)
    subprocess.run(["git","commit","-m", f"codex: save proposal {thread_id}/{pid} [skip ci]"], check=False)
    subprocess.run(["git","push"], check=False)
    return p

def load_session(thread_id: str, system_prompt: str) -> Dict[str, Any]:
    p = sess_path(thread_id)
    if p.exists():
        return json.loads(p.read_text(encoding="utf-8"))
    return {"thread_id": thread_id, "status": "open", "created_utc": time.time(), "messages": [{"role":"system","content":system_prompt}]}

def save_session(s: Dict[str, Any]):
    p = sess_path(s["thread_id"])
    p.write_text(json.dumps(s, indent=2), encoding="utf-8")
    # Commit with [skip ci] to avoid loops
    subprocess.run(["git","config","user.email","codex-bot@users.noreply.github.com"], check=False)
    subprocess.run(["git","config","user.name","codex-bot"], check=False)
    subprocess.run(["git","add", str(p)], check=False)
    subprocess.run(["git","commit","-m", f"codex: update session {s['thread_id']} [skip ci]"], check=False)
    subprocess.run(["git","push"], check=False)

def call_llm(api_base: str, api_key: str, model: str, messages: List[Dict[str,str]], temperature: float=0.2, max_tokens: int=800) -> str:
    url = api_base.rstrip("/") + "/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    body = {"model": model, "messages": messages, "temperature": temperature, "max_tokens": max_tokens}
    r = requests.post(url, headers=headers, json=body, timeout=120)
    r.raise_for_status()
    js = r.json()
    return js["choices"][0]["message"]["content"]

PROPOSE_SYSTEM = """You are a code assistant operating in a Git repository root.
Return **only** a single unified diff (git-style) inside one fenced block:
```diff
<diff here>
```
Constraints:
- Touch only allowed paths; keep changes minimal and coherent.
- Follow ISO/IEC/IEEE 29148 shaping for any SRS edits (atomic "shall", RQn/ACn, Attributes).
- No commentary or explanations outside the diff block."""

def extract_diff_block(text: str) -> Optional[str]:
    m = re.search(r"```diff\s+([\s\S]+?)\s*```", text, re.I)
    return m.group(1).strip() if m else None

def get_repo_context() -> Dict[str,str]:
    repo = os.environ.get("GITHUB_REPOSITORY","")
    owner, _, name = repo.partition("/")
    default_branch = os.environ.get("GITHUB_REF_NAME","")
    return {"owner": owner, "repo": name, "default_branch": default_branch}

def allowed_globs() -> List[str]:
    """
    Resolve allowed path globs. If the repo variable exists but is empty, use a safe default.
    Includes .github/** so Codex can maintain repo meta (PR template, workflows).
    """
    raw = (os.environ.get("CODEX_ALLOWED_GLOBS", "") or "").strip()
    if not raw:
        raw = "docs/srs/**,scripts/**,.github/**,.codex/**,docs/compliance/**"
    return [g.strip() for g in raw.split(",") if g.strip()]

def max_lines_limit() -> int:
    try:
        return int(os.environ.get("CODEX_MAX_LINES","500"))
    except:
        return 500

def validate_patch_text(diff_text: str, globs: List[str], max_lines: int) -> str:
    """Basic checks: size, allowed paths, naive secret scan; ignores /dev/null for new files."""
    import fnmatch
    lines = diff_text.splitlines()
    added = sum(1 for ln in lines if ln.startswith("+") and not ln.startswith("+++"))
    removed = sum(1 for ln in lines if ln.startswith("-") and not ln.startswith("---"))
    if (added + removed) > max_lines:
        return f"Patch too large: {added+removed} lines (limit {max_lines})."
    # collect file paths from +++/---; ignore /dev/null; strip a|b prefixes
    paths = []
    for ln in lines:
        m = re.match(r'^(?:\+\+\+|---)\s+(?:[ab]/)?(.+)$', ln)
        if not m:
            continue
        pth = m.group(1).strip()
        if pth in ("dev/null", "/dev/null"):
            continue
        if pth not in paths:
            paths.append(pth)
    if not paths:
        return "No file paths detected in diff."
    for pth in paths:
        if not any(fnmatch.fnmatch(pth, g) for g in globs):
            allowed = ", ".join(globs) if globs else "(none)"
            return f"Path '{pth}' is not allowed.\nAllowed globs: {allowed}"
    # naive secret scan
    if re.search(r"AKIA[0-9A-Z]{16}|secret[_-]?key|xox[baprs]-|ghp_[0-9A-Za-z]{36}", diff_text, re.I):
        return "Secret-like token found in patch."
    return ""

def _run_maintenance():
    """The system **shall** run an optional, idempotent post-apply hook
    to keep derived artifacts in sync (FGC-REQ-AIC-004@1.0).
    Attributes: reliability, maintainability.

    - If $CODEX_MAINTENANCE_CMD is set -> run it.
    - Else, if .codex/maintenance.sh or .codex/maintenance.py exists -> run it.
    - If nothing found, no-op.

    Acceptance criteria:
    - Derived artifacts are regenerated when hooks exist.
    - Traceability verification passes.
    - Worktree remains clean.

    Any failure shall raise to stop committing a broken PR.
    """
    cmd = (os.getenv("CODEX_MAINTENANCE_CMD") or "").strip()
    if not cmd:
        for candidate in (".codex/maintenance.sh", ".codex/maintenance.py"):
            if os.path.exists(candidate):
                cmd = candidate
                break
    if not cmd:
        return
    print(f"[codex] running maintenance: {cmd}")
    if cmd.endswith(".py"):
        subprocess.run(["python", cmd], check=True)
    else:
        # Prefer invoking bash directly with the script path to improve Windows compatibility.
        # If the default 'bash' resolves to WSL's relay (which may not be installed),
        # attempt common Git Bash locations.
        import shutil
        bash = shutil.which("bash") or "bash"
        # Avoid WSL relay bash.exe which fails without WSL
        if os.name == "nt" and bash.lower().endswith("\\system32\\bash.exe"):
            for guess in (
                r"C:\\Program Files\\Git\\bin\\bash.exe",
                r"C:\\Program Files\\Git\\usr\\bin\\bash.exe",
                r"C:\\Program Files (x86)\\Git\\bin\\bash.exe",
                r"C:\\Program Files (x86)\\Git\\usr\\bin\\bash.exe",
            ):
                if Path(guess).exists():
                    bash = guess
                    break
        subprocess.run([bash, cmd], check=True)

def create_branch_commit_push(branch: str, patch_file: Path, title: str) -> Optional[str]:
    # Apply patch, run basic checks, commit, push. Return commit SHA or None on failure.
    # Ensure we are up-to-date
    subprocess.run(["git","fetch","--all"], check=False)
    subprocess.run(["git","checkout","-B", branch], check=False)
    # Apply patch (check first)
    chk = subprocess.run(["git","apply","--check", str(patch_file)])
    if chk.returncode != 0:
        return None
    ap = subprocess.run(["git","apply", str(patch_file)])
    if ap.returncode != 0:
        return None
    # The system shall run maintenance now so derived artifacts and
    # traceability stay in sync (FGC-REQ-AIC-004@1.0)
    _run_maintenance()
    # identity
    subprocess.run(["git","config","user.email","codex-bot@users.noreply.github.com"], check=False)
    subprocess.run(["git","config","user.name","codex-bot"], check=False)
    subprocess.run(["git","add","-A"], check=False)
    c = subprocess.run(["git","commit","-m", title])
    if c.returncode != 0:
        return None
    # Run 29148 lints only if docs/srs/** changed
    if Path("scripts/lint_srs_29148.py").exists():
        try:
            changed = subprocess.check_output(["git","diff","--name-only","--cached"]).decode().splitlines()
        except Exception:
            changed = []
        if any(p.startswith("docs/srs/") for p in changed):
            lint = subprocess.run(["python","scripts/lint_srs_29148.py"])
            if lint.returncode != 0:
                return None
    pu = subprocess.run(["git","push","-u","origin", branch])
    if pu.returncode != 0:
        return None
    sha = subprocess.check_output(["git","rev-parse","HEAD"]).decode().strip()
    return sha

def open_draft_pr(token: str, owner: str, repo: str, head: str, base: str, title: str, body: str, labels: List[str]) -> str:
    url = f"{GITHUB_API}/repos/{owner}/{repo}/pulls"
    r = requests.post(url, headers=gh_headers(token), json={
        "title": title, "head": head, "base": base, "body": body, "draft": True
    }, timeout=60)
    r.raise_for_status()
    pr = r.json()
    # labels
    if labels:
        lurl = f"{GITHUB_API}/repos/{owner}/{repo}/issues/{pr['number']}/labels"
        requests.post(lurl, headers=gh_headers(token), json={"labels": labels}, timeout=30)
    return pr["html_url"]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--event", required=True, help="Path to GITHUB_EVENT_PATH JSON")
    ap.add_argument("--default-model", default="gpt-4o-mini")
    ap.add_argument("--api-base", default="https://api.openai.com/v1")
    args = ap.parse_args()

    # Prefer user token if present (env, keyring, file), then fallback to GITHUB_TOKEN
    token = (os.environ.get("GITHUB_USER_TOKEN", "") or "").strip()
    if not token:
        try:
            import keyring  # type: ignore

            token = (keyring.get_password("x-cli", "github_user_token") or "").strip()
        except Exception:
            token = ""
    if not token:
        p = Path(".secrets/github_user_token.txt")
        if p.exists():
            try:
                token = p.read_text(encoding="utf-8").strip()
            except Exception:
                token = ""
    if not token:
        token = (os.environ.get("GITHUB_TOKEN", "") or "").strip()
    api_key = os.environ.get("LLM_API_KEY","")
    allowed_users = {u.strip().lower() for u in os.environ.get("CODEX_ALLOWED_USERS", "").split(",") if u.strip()}
    required_label = os.environ.get("CODEX_LABEL_REQUIRED", "").strip().lower()
    if not token: print("[ERR] Missing GitHub token (GITHUB_USER_TOKEN or GITHUB_TOKEN)", file=sys.stderr); sys.exit(1)
    if not api_key: print("[ERR] Missing LLM_API_KEY secret", file=sys.stderr); sys.exit(1)

    ev = load_event(args.event)
    ctx = detect_thread_context(ev)
    ensure_dirs()
    system_prompt = load_system_prompt()
    thread_id = str(ctx["number"] or "manual")
    session = load_session(thread_id, system_prompt)

    raw = (ctx["comment"] or "").strip()
    m = re.match(r"^/codex(?:\s+(.*))?$", raw, re.I)
    if not m:
        # Not for us
        sys.exit(0)
    cmdline = (m.group(1) or "").strip()

    def respond(markdown: str):
        if ctx["number"]:
            post_issue_comment(token, ctx["owner"], ctx["repo"], ctx["number"], markdown)
        else:
            print(markdown)

    if cmdline.lower().startswith("policy"):
        globs = sorted(allowed_globs())
        users = ", ".join(sorted(allowed_users)) if allowed_users else "(any)"
        label = f"#{required_label}" if required_label else "(none)"
        globs_str = ", ".join(globs) if globs else "(none)"
        policy = f"""**Codex Policy**

- Allowed users: {users}
- Required label: {label}
- Allowed globs: {globs_str}
- Max patch lines: {max_lines_limit()}

See [.codex/README.md](.codex/README.md) for details."""
        respond(policy)
        sys.exit(0)

    # --- Authorization & label gate ---
    if allowed_users and ctx.get("actor"):
        if ctx["actor"].lower() not in allowed_users:
            respond(f"Sorry @{ctx['actor']}, this command is restricted.")
            sys.exit(0)
    if required_label and ctx.get("number"):
        # Check labels on the issue/PR
        url = f"{GITHUB_API}/repos/{ctx['owner']}/{ctx['repo']}/issues/{ctx['number']}"
        r = requests.get(url, headers=gh_headers(token), timeout=30)
        r.raise_for_status()
        labels = [lbl["name"].strip().lower() for lbl in r.json().get("labels",[])]
        if required_label not in labels:
            respond(f"This thread needs the `#{required_label}` label before `/codex` commands are accepted.")
            sys.exit(0)

    if cmdline.lower().startswith("ping"):
        respond("pong ✅")
        sys.exit(0)
    if cmdline.lower().startswith("init"):
        session["status"]="open"
        save_session(session)
        respond("Codex session initialized. Use `/codex say <message>` to chat, `/codex end` to close.")
        sys.exit(0)
    if cmdline.lower().startswith("state"):
        respond(f"**Session** `{thread_id}` — status: `{session.get('status')}` · messages: {len(session['messages'])}")
        sys.exit(0)
    if cmdline.lower().startswith("end"):
        session["status"]="closed"
        save_session(session)
        respond("Codex session closed. Use `/codex init` to start again.")
        sys.exit(0)

    # /codex say ...
    say_m = re.match(r"^say\s+(.+)$", cmdline, re.I)
    if say_m:
        if session.get("status")=="closed":
            respond("Session is closed. `/codex init` to restart.")
            sys.exit(0)
        user_text = say_m.group(1).strip()
        session["messages"].append({"role":"user", "content": user_text})
        try:
            reply = call_llm(args.api_base, api_key, args.default_model, session["messages"])
        except requests.HTTPError as e:
            respond(f"LLM call failed: `{e.response.status_code}` — {e.response.text[:300]}")
            sys.exit(1)
        session["messages"].append({"role":"assistant", "content": reply})
        save_session(session)
        respond(f"**Codex**:\n\n{reply}")
        sys.exit(0)

    # /codex propose ...
    prop_m = re.match(r"^propose\s+(.+)$", cmdline, re.I)
    if prop_m:
        if session.get("status")=="closed":
            respond("Session is closed. `/codex init` to restart.")
            sys.exit(0)
        task = prop_m.group(1).strip()
        # Build messages with a proposal-specific system prompt
        messages = [{"role":"system","content": PROPOSE_SYSTEM},
                    *session["messages"][1:],  # skip original system
                    {"role":"user","content": f"Task: {task}\n\nReturn only a unified diff from repo root."}]
        try:
            out = call_llm(args.api_base, api_key, args.default_model, messages, temperature=0.15, max_tokens=1800)
        except requests.HTTPError as e:
            respond(f"LLM call failed: `{e.response.status_code}` — {e.response.text[:300]}")
            sys.exit(1)
        diff = extract_diff_block(out) or ""
        if not diff:
            respond("I didn’t receive a valid ```diff block. Please try narrowing the task or re-run `/codex propose ...`.")
            sys.exit(0)
        # Validate basic constraints before saving
        err = validate_patch_text(diff, allowed_globs(), max_lines_limit())
        if err:
            respond(f"Proposal rejected by guardrails:\n\n> {err}")
            sys.exit(0)
        pid = next_proposal_id(thread_id)
        patch_path = save_proposal(thread_id, pid, diff)
        session["messages"].append({"role":"assistant","content": f"[[proposal saved: {pid} → {patch_path}]]"})
        save_session(session)
        respond(f"📦 Proposal **{pid}** saved (`{patch_path}`).\n\nTo apply: `/codex apply {pid}` (or `/codex apply latest`).")
        sys.exit(0)

    # /codex apply [id|latest]
    apply_m = re.match(r"^apply(?:\s+(\S+))?$", cmdline, re.I)
    if apply_m:
        pid = (apply_m.group(1) or "latest").strip().lower()
        d = prop_dir(thread_id)
        candidates = sorted(d.glob("*.patch"))
        if not candidates:
            respond("No proposals found for this thread.")
            sys.exit(0)
        patch_file = candidates[-1] if pid=="latest" else d / f"{pid}.patch"
        if not patch_file.exists():
            respond(f"Proposal `{pid}` not found.")
            sys.exit(0)
        diff = patch_file.read_text(encoding="utf-8")
        err = validate_patch_text(diff, allowed_globs(), max_lines_limit())
        if err:
            respond(f"Apply refused by guardrails:\n\n> {err}")
            sys.exit(0)
        ctx_repo = get_repo_context()
        branch = f"codex/{thread_id}-{patch_file.stem}"
        title = f"codex: apply proposal {thread_id}/{patch_file.stem}"
        sha = create_branch_commit_push(branch, patch_file, title)
        if not sha:
            respond("Failed to apply/commit the patch (lint or git apply check likely failed). See workflow logs.")
            sys.exit(0)
        pr_url = open_draft_pr(
            os.environ["GITHUB_TOKEN"], ctx_repo["owner"], ctx_repo["repo"],
            head=branch, base=ctx_repo.get("default_branch") or "main",
            title=f"[CODEx] Draft PR for {thread_id}/{patch_file.stem}",
            body="Draft PR created by Codex. This PR is gated by CI and requires human review.",
            labels=["codex-proposal","needs-human-review"]
        )
        respond(f"✅ Applied proposal `{patch_file.stem}` and opened draft PR: {pr_url}")
        sys.exit(0)

    # Fallback help
    respond("Unrecognized `/codex` command. Try: `init`, `ping`, `policy`, `say <msg>`, `propose <task>`, `apply [id|latest]`, `state`, `end`.")

if __name__ == "__main__":
    main()
