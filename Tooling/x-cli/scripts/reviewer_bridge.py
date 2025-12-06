#!/usr/bin/env python3
"""
Codex Reviewer — mirrored AI critique for PRs.
Triggers:
  - pull_request events (opened/synchronize/labeled)
  - /reviewer critique [this|<pr>] in PR threads
  - workflow_dispatch with pr_number

Outputs:
  - Posts a PR review (general "COMMENT") with a structured critique
  - Saves .codex/reviews/<timestamp>-pr<no>.md and .json, commits [skip ci]

Guards (via env vars):
  REVIEWER_ALLOWED_USERS   = "user1,user2" (optional; author of the comment)
  REVIEWER_LABEL_REQUIRED  = "codex-proposal" (default enforced on pull_request events)
  REVIEWER_ALLOWED_GLOBS   = "docs/srs/**,scripts/**,.github/workflows/**,.codex/**,docs/compliance/**"
  REVIEWER_MAX_DIFF_KB     = "256"
  REVIEWER_ALLOWED_BRANCH_REGEX = "^(codex/|rescue/|feature/|bugfix/|hotfix/|release/|support/)" (gitflow-aware)
  REVIEWER_ALLOW_ANY_BRANCH    = "1" to bypass branch guard
  REVIEWER_ALLOW_DIFFERENT_BRANCH = "1" to allow running from a different branch than the PR head
  REVIEWER_COMMENT_ONLY        = "1" to post PR comment only (skip saving .codex/reviews and any git ops)
  REVIEWER_NO_POST             = "1" to skip posting the PR review comment
  REVIEWER_NO_LABELS           = "1" to skip adding labels to the PR
  REVIEWER_DRY_RUN             = "1" to compute only (no post, no labels, no save)
  REVIEWER_OUTPUT_PATH         = path to write the review Markdown when no-post/dry-run/comment-only is enabled
  REVIEWER_HTTP_RETRIES        = total retries for HTTP (default 3)
  REVIEWER_HTTP_BACKOFF_SEC    = base backoff seconds (default 0.5)
  REVIEWER_HTTP_JITTER_SEC     = added random jitter seconds (default 0.25)
  REVIEWER_TEMPERATURE         = LLM sampling temperature (default 0.1)
  REVIEWER_TOP_P               = LLM top-p nucleus sampling (optional; default unset)
  REVIEWER_SEED                = LLM seed for determinism (optional)
  REVIEWER_FREEZE_INPUTS       = "1" to cache PR JSON/diff/files and reuse them across cycles
  REVIEWER_INPUT_CACHE_DIR     = path for frozen inputs (default .codex/reviewer_inputs/pr<no>)
"""
from __future__ import annotations
import argparse, json, os, re, subprocess, sys, time, random, datetime as dt
from pathlib import Path
from typing import Dict, Any, List, Optional
import requests
from requests.adapters import HTTPAdapter
try:
    from urllib3.util.retry import Retry  # type: ignore
except Exception:  # pragma: no cover
    Retry = None

# Retry with jitter added to the exponential backoff used by urllib3
if Retry is not None:
    class JitterRetry(Retry):  # type: ignore
        def __init__(self, *args, **kwargs):
            self._jitter = float(kwargs.pop("jitter", os.environ.get("REVIEWER_HTTP_JITTER_SEC", "0.25") or 0.25))
            super().__init__(*args, **kwargs)

        def get_backoff_time(self):  # noqa: D401
            base = super().get_backoff_time()
            try:
                j = float(self._jitter)
            except Exception:
                j = 0.0
            if not base:
                return base
            if j > 0:
                return base + random.random() * j
            return base

GH = "https://api.github.com"

# Shared HTTP session with retries for transient faults
_SESSION: Optional[requests.Session] = None

def get_session() -> requests.Session:
    global _SESSION
    if _SESSION is None:
        s = requests.Session()
        total = int(os.environ.get("REVIEWER_HTTP_RETRIES", "3") or 3)
        backoff = float(os.environ.get("REVIEWER_HTTP_BACKOFF_SEC", "0.5") or 0.5)
        allowed = frozenset(["GET", "POST"])
        if Retry is not None:
            jitter = float(os.environ.get("REVIEWER_HTTP_JITTER_SEC", "0.25") or 0.25)
            retry = JitterRetry(total=total, connect=total, read=total, status=total,
                                backoff_factor=backoff,
                                status_forcelist=[408, 429, 500, 502, 503, 504, 520, 521, 522, 523, 524, 525, 526, 527],
                                allowed_methods=allowed,
                                raise_on_status=False,
                                jitter=jitter)
            adapter = HTTPAdapter(max_retries=retry)
            s.mount("https://", adapter)
            s.mount("http://", adapter)
        _SESSION = s
    return _SESSION

def get_json_with_retry(url: str, hdrs: Dict[str, str], timeout: int) -> Dict[str, Any]:
    tries = int(os.environ.get("REVIEWER_JSON_RETRIES", os.environ.get("REVIEWER_HTTP_RETRIES", "3")) or 3)
    backoff = float(os.environ.get("REVIEWER_HTTP_BACKOFF_SEC", "0.5") or 0.5)
    jitter = float(os.environ.get("REVIEWER_HTTP_JITTER_SEC", "0.25") or 0.25)
    last: Optional[Exception] = None
    for attempt in range(tries):
        try:
            r = get_session().get(url, headers=hdrs, timeout=timeout)
            r.raise_for_status()
            return r.json()
        except (requests.RequestException, ValueError) as e:
            last = e
            if attempt < tries - 1:
                sleep_s = backoff * (2 ** attempt)
                if jitter > 0:
                    sleep_s += random.random() * jitter
                time.sleep(sleep_s)
            else:
                raise
    if last:
        raise last
    raise RuntimeError("unreachable")

def _env_truthy(name: str) -> bool:
    v = (os.environ.get(name, "") or "").strip().lower()
    return v in ("1", "true", "yes", "y", "on")

def load_event(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def headers(token: str) -> Dict[str,str]:
    return {"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}

def pr_headers(token: str, accept: str) -> Dict[str,str]:
    h = headers(token).copy(); h["Accept"] = accept; return h

def ensure_dirs():
    Path(".codex/reviews").mkdir(parents=True, exist_ok=True)

def get_ctx(ev: Dict[str,Any]) -> Dict[str,Any]:
    repo = ev["repository"]["full_name"]
    owner, _, name = repo.partition("/")
    actor = ev["sender"]["login"]
    if ev.get("pull_request"):
        number = ev["pull_request"]["number"]
    elif ev.get("issue") and ev["issue"].get("pull_request"):
        number = ev["issue"]["number"]
    else:
        number = int(ev.get("inputs",{}).get("pr_number") or 0)
    comment_body = ev.get("comment",{}).get("body","")
    return {"owner":owner, "repo":name, "actor":actor, "pr":number, "comment":comment_body}

def require_label_on_pr(token: str, owner: str, repo: str, pr: int, label_required: str) -> bool:
    if not label_required: return True
    u = f"{GH}/repos/{owner}/{repo}/issues/{pr}"
    js = get_json_with_retry(u, headers(token), timeout=30)
    labels = [x["name"].strip().lower() for x in js.get("labels",[])]
    return label_required.lower() in labels

def fetch_pr(token: str, owner: str, repo: str, pr: int) -> Dict[str,Any]:
    u = f"{GH}/repos/{owner}/{repo}/pulls/{pr}"
    return get_json_with_retry(u, headers(token), timeout=30)

def fetch_pr_diff(token: str, owner: str, repo: str, pr: int) -> str:
    u = f"{GH}/repos/{owner}/{repo}/pulls/{pr}"
    r = get_session().get(u, headers=pr_headers(token, "application/vnd.github.v3.diff"), timeout=60)
    r.raise_for_status()
    return r.text

def fetch_pr_files(token: str, owner: str, repo: str, pr: int) -> List[Dict[str,Any]]:
    files = []; page=1
    while True:
        u = f"{GH}/repos/{owner}/{repo}/pulls/{pr}/files?per_page=100&page={page}"
        batch = get_json_with_retry(u, headers(token), timeout=60)
        files += batch
        if len(batch) < 100: break
        page += 1
    return files

# Frozen inputs helpers -------------------------------------------------------
def _freeze_dir_for_pr(pr_no: int) -> Path:
    base = (os.environ.get("REVIEWER_INPUT_CACHE_DIR", "") or "").strip()
    if not base:
        base = f".codex/reviewer_inputs/pr{pr_no}"
    return Path(base)

def load_or_fetch_pr(token: str, owner: str, repo: str, pr_no: int, freeze: bool) -> Dict[str, Any]:
    p = _freeze_dir_for_pr(pr_no) / "pr.json"
    if freeze and p.exists():
        return json.loads(p.read_text(encoding="utf-8"))
    obj = fetch_pr(token, owner, repo, pr_no)
    if freeze:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(obj, indent=2), encoding="utf-8")
    return obj

def load_or_fetch_diff(token: str, owner: str, repo: str, pr_no: int, freeze: bool) -> str:
    p = _freeze_dir_for_pr(pr_no) / "diff.patch"
    if freeze and p.exists():
        return p.read_text(encoding="utf-8")
    text = fetch_pr_diff(token, owner, repo, pr_no)
    if freeze:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    return text

def load_or_fetch_files(token: str, owner: str, repo: str, pr_no: int, freeze: bool) -> List[Dict[str, Any]]:
    p = _freeze_dir_for_pr(pr_no) / "files.json"
    if freeze and p.exists():
        return json.loads(p.read_text(encoding="utf-8"))
    obj = fetch_pr_files(token, owner, repo, pr_no)
    if freeze:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(obj, indent=2), encoding="utf-8")
    return obj

def naive_secret_scan(text:str)->bool:
    return bool(re.search(r"AKIA[0-9A-Z]{16}|secret[_-]?key|xox[baprs]-|ghp_[0-9A-Za-z]{36}", text, re.I))

def run_linter() -> str:
    if not Path("scripts/lint_srs_29148.py").exists(): return ""
    try:
        p = subprocess.run(["python","scripts/lint_srs_29148.py"], capture_output=True, text=True)
        return p.stdout.strip() + ("\n" + p.stderr.strip() if p.stderr else "")
    except Exception as e:
        return f"[linter error] {e}"

def call_llm(api_base:str, api_key:str, model:str, messages:List[Dict[str,str]], temperature:float=0.2, max_tokens:int=1400, top_p: Optional[float] = None, seed: Optional[int] = None)->str:
    url = api_base.rstrip("/") + "/chat/completions"
    tries = int(os.environ.get("REVIEWER_LLM_RETRIES", os.environ.get("REVIEWER_HTTP_RETRIES", "3")) or 3)
    backoff = float(os.environ.get("REVIEWER_HTTP_BACKOFF_SEC", "0.5") or 0.5)
    jitter = float(os.environ.get("REVIEWER_HTTP_JITTER_SEC", "0.25") or 0.25)
    payload = {"model":model, "messages":messages, "temperature":temperature, "max_tokens":max_tokens}
    if top_p is not None:
        try:
            payload["top_p"] = float(top_p)
        except Exception:
            pass
    if seed is not None:
        try:
            payload["seed"] = int(seed)
        except Exception:
            pass
    hdrs = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    last: Optional[Exception] = None
    for attempt in range(tries):
        try:
            r = get_session().post(url, headers=hdrs, json=payload, timeout=180)
            r.raise_for_status()
            js = r.json()
            return js["choices"][0]["message"]["content"]
        except (requests.RequestException, ValueError) as e:
            last = e
            if attempt < tries - 1:
                sleep_s = backoff * (2 ** attempt)
                if jitter > 0:
                    sleep_s += random.random() * jitter
                time.sleep(sleep_s)
            else:
                raise
    if last:
        raise last
    raise RuntimeError("unreachable")

REVIEWER_SYSTEM = """You are an **AI Pull Request Reviewer** for a repository that follows ISO/IEC/IEEE 29148:2018.
Return a **structured review in Markdown** with exactly these sections:
1) Executive Summary — bullets; call out severity (High/Med/Low).
2) SRS Alignment — list SRS IDs touched; check atomic “shall”, RQn/ACn, Attributes, and language hygiene issues (and/or, TBD, vague words); cite concrete lines or file paths when possible.
3) Risk & Impact — affected components; test/evidence gaps; backward compatibility notes.
4) Actionable Next Steps — numbered list of specific, verifiable fixes or follow-ups.
5) Verdict — one of: APPROVE, APPROVE WITH NITS, or REVISE, with a one-line rationale.
Do not return code patches. Be concise and specific."""

def extract_srs_ids(text:str)->List[str]:
    return sorted(set(re.findall(r"\b[A-Z]{3}-REQ-[A-Z]+-\d{3}\b", text)))

def post_pr_review(token:str, owner:str, repo:str, pr:int, body_md:str)->None:
    u = f"{GH}/repos/{owner}/{repo}/pulls/{pr}/reviews"
    r = get_session().post(u, headers=headers(token), json={"event":"COMMENT","body":body_md}, timeout=60)
    r.raise_for_status()

def label_issue(token:str, owner:str, repo:str, pr:int, labels:List[str]):
    if not labels: return
    u = f"{GH}/repos/{owner}/{repo}/issues/{pr}/labels"
    get_session().post(u, headers=headers(token), json={"labels":labels}, timeout=30)

def save_review(pr:int, content:str, meta:Dict[str,Any]):
    ensure_dirs()
    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d-%H%M%S")
    md = Path(f".codex/reviews/{ts}-pr{pr}.md")
    jj = Path(f".codex/reviews/{ts}-pr{pr}.json")
    md.write_text(content, encoding="utf-8")
    jj.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    # Stop cycles deterministically if review artifacts are ignored by git
    def _is_ignored(p: Path) -> bool:
        try:
            r = subprocess.run(["git","check-ignore","-q", str(p)], capture_output=True)
            return r.returncode == 0
        except Exception:
            return False
    ignored_paths = [p for p in [Path(".codex"), Path(".codex/reviews"), md, jj] if _is_ignored(p)]
    if ignored_paths:
        raise RuntimeError("Save aborted: git ignores these paths: " + ", ".join(str(p) for p in ignored_paths))
    subprocess.run(["git","config","user.email","codex-bot@users.noreply.github.com"], check=False)
    subprocess.run(["git","config","user.name","codex-bot"], check=False)
    add = subprocess.run(["git","add", str(md), str(jj)], capture_output=True, text=True)
    if add.returncode != 0:
        raise RuntimeError(f"git add failed: {add.stderr.strip() or add.stdout.strip()}")
    staged = subprocess.run(["git","diff","--cached","--name-only","--", str(md), str(jj)], capture_output=True, text=True)
    names = [ln.strip() for ln in staged.stdout.splitlines() if ln.strip()]
    if not names:
        raise RuntimeError("Save aborted: no files staged after git add (likely ignored by .gitignore)")
    commit = subprocess.run(["git","commit","-m", f"reviewer: save AI critique for PR #{pr} [skip ci]"], capture_output=True, text=True)
    if commit.returncode != 0 and "nothing to commit" not in (commit.stderr or "") and "nothing to commit" not in (commit.stdout or ""):
        raise RuntimeError(f"git commit failed: {commit.stderr.strip() or commit.stdout.strip()}")
    push = subprocess.run(["git","push"], capture_output=True, text=True)
    if push.returncode != 0:
        raise RuntimeError(f"git push failed: {push.stderr.strip() or push.stdout.strip()}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--event", required=True)
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
    api_base = os.environ.get("LLM_API_BASE", args.api_base)
    model = os.environ.get("LLM_MODEL", args.default_model)
    comment_only = _env_truthy("REVIEWER_COMMENT_ONLY")
    dry_run = _env_truthy("REVIEWER_DRY_RUN")
    no_post = _env_truthy("REVIEWER_NO_POST") or dry_run
    no_labels = _env_truthy("REVIEWER_NO_LABELS") or dry_run
    if not token: print("[ERR] Missing GitHub token (GITHUB_USER_TOKEN or GITHUB_TOKEN)", file=sys.stderr); sys.exit(1)
    if not api_key: print("[ERR] Missing LLM_API_KEY", file=sys.stderr); sys.exit(1)

    # Preflight: abort early if review artifacts would be ignored by git
    def _is_ignored(p: Path) -> bool:
        try:
            r = subprocess.run(["git","check-ignore","-q", str(p)], capture_output=True)
            return r.returncode == 0
        except Exception:
            return False
    if not (comment_only or dry_run):
        if _is_ignored(Path(".codex")) or _is_ignored(Path(".codex/reviews")):
            print("[ERR] Save aborted: git ignores .codex or .codex/reviews; unignore or set REVIEWER_COMMENT_ONLY=1 or REVIEWER_DRY_RUN=1", file=sys.stderr)
            sys.exit(2)

    allowed_users = {u.strip().lower() for u in os.environ.get("REVIEWER_ALLOWED_USERS","" ).split(",") if u.strip()}
    label_required = (os.environ.get("REVIEWER_LABEL_REQUIRED","codex-proposal") or "").strip().lower()
    allowed_globs = [g.strip() for g in (os.environ.get("REVIEWER_ALLOWED_GLOBS","docs/srs/**,scripts/**,.github/workflows/**,.codex/**,docs/compliance/**")).split(",") if g.strip()]
    try:
        max_kb = int(os.environ.get("REVIEWER_MAX_DIFF_KB","256"))
    except: max_kb = 256

    ev = load_event(args.event)
    ctx = get_ctx(ev)

    # ChatOps authz (only for /reviewer comments)
    if ev.get("comment"):
        if allowed_users and ctx["actor"].lower() not in allowed_users:
            # soft ignore
            print(f"Actor @{ctx['actor']} not allowed; ignoring.")
            sys.exit(0)

    pr_no = ctx["pr"]
    if not pr_no:
        print("No PR detected; pass pr_number via workflow_dispatch or comment in a PR thread.")
        sys.exit(0)

    # Label gate (for pull_request events)
    if ev.get("pull_request"):
        if label_required and not require_label_on_pr(token, ctx["owner"], ctx["repo"], pr_no, label_required):
            print(f"PR lacks required label: {label_required}")
            sys.exit(0)

    # Optional command parsing: "/reviewer critique ..."
    if ctx["comment"].strip():
        m = re.match(r"^/reviewer\s+critique", ctx["comment"].strip(), re.I)
        if not m:
            sys.exit(0)

    # Optional input freezing for deterministic cycles
    freeze_inputs = _env_truthy("REVIEWER_FREEZE_INPUTS")
    pr = load_or_fetch_pr(token, ctx["owner"], ctx["repo"], pr_no, freeze_inputs)
    # GitFlow-aware guard: when running locally, avoid pushing from unsafe branches
    # Safe defaults: disallow main/master/develop; require current branch to match PR head by default.
    # Overrides:
    #   REVIEWER_ALLOW_ANY_BRANCH=1            → allow any branch
    #   REVIEWER_ALLOW_DIFFERENT_BRANCH=1      → allow branch != PR head
    #   REVIEWER_ALLOWED_BRANCH_REGEX=<regex>  → custom allowlist (default: gitflow-style prefixes)
    if not _env_truthy("GITHUB_ACTIONS") and not (comment_only or dry_run):
        try:
            branch = subprocess.run([
                "git","rev-parse","--abbrev-ref","HEAD"
            ], capture_output=True, text=True, check=False).stdout.strip()
        except Exception:
            branch = ""
        pr_head = (pr.get("head",{}) or {}).get("ref","")
        disallow = {"main","master","develop"}
        allowed_regex = os.environ.get(
            "REVIEWER_ALLOWED_BRANCH_REGEX",
            r"^(codex/|rescue/|feature/|bugfix/|hotfix/|release/|support/)"
        )
        if branch in disallow and not _env_truthy("REVIEWER_ALLOW_ANY_BRANCH"):
            print(
                f"[ERR] Unsafe branch for reviewer save: '{branch}'. "
                f"Checkout PR head '{pr_head}' or set REVIEWER_ALLOW_ANY_BRANCH=1.",
                file=sys.stderr,
            )
            sys.exit(2)
        if pr_head and branch != pr_head and not _env_truthy("REVIEWER_ALLOW_DIFFERENT_BRANCH"):
            print(
                f"[ERR] Current branch '{branch}' does not match PR head '{pr_head}'. "
                f"Set REVIEWER_ALLOW_DIFFERENT_BRANCH=1 to override.",
                file=sys.stderr,
            )
            sys.exit(2)
        if allowed_regex and not re.match(allowed_regex, branch) and not _env_truthy("REVIEWER_ALLOW_ANY_BRANCH"):
            print(
                f"[ERR] Branch '{branch}' does not match allowed pattern '{allowed_regex}'. "
                f"Set REVIEWER_ALLOW_ANY_BRANCH=1 to override.",
                file=sys.stderr,
            )
            sys.exit(2)
    diff = load_or_fetch_diff(token, ctx["owner"], ctx["repo"], pr_no, freeze_inputs)
    if naive_secret_scan(diff):
        body = "Reviewer refused: diff appears to contain secret-like tokens."
        post_pr_review(token, ctx["owner"], ctx["repo"], pr_no, body)
        sys.exit(0)
    # Truncate large diffs
    diff_bytes = diff.encode("utf-8")
    truncated = False
    if len(diff_bytes) > max_kb*1024:
        diff = diff_bytes[:max_kb*1024].decode("utf-8", errors="ignore")
        truncated = True
    files = load_or_fetch_files(token, ctx["owner"], ctx["repo"], pr_no, freeze_inputs)
    changed_paths = [f["filename"] for f in files]
    # 29148 lint (optional)
    lint_out = run_linter()

    title = pr.get("title","")
    body = pr.get("body","") or ""
    if len(body) > 4000: body = body[:4000] + "\n\n…(truncated)…"
    srs_touched = extract_srs_ids("\n".join(changed_paths) + "\n" + diff)

    # Build messages
    context_md = f"""# PR #{pr_no}: {title}

**Author:** @{pr['user']['login']}
**Base:** {pr['base']['label']} → **Head:** {pr['head']['label']}

## Description (truncated to 4k)
{body}

## Files changed ({len(changed_paths)})
- """ + "\n- ".join(changed_paths[:200]) + ("" if len(changed_paths)<=200 else f"\n- …(+{len(changed_paths)-200} more)")

    if srs_touched:
        context_md += "\n\n## SRS IDs detected\n- " + "\n- ".join(srs_touched)

    if lint_out:
        context_md += "\n\n## 29148 Linter Output (summary)\n```\n" + lint_out[:4000] + ("\n…(truncated)…" if len(lint_out)>4000 else "") + "\n```"

    context_md += "\n\n## Diff " + ("(truncated)" if truncated else "") + "\n```\n" + diff + "\n```"

    messages = [
        {"role":"system","content": REVIEWER_SYSTEM},
        {"role":"user","content": context_md}
    ]
    # Determinism controls
    deterministic = _env_truthy("REVIEWER_DETERMINISTIC")
    def _float_env(name: str) -> Optional[float]:
        v = (os.environ.get(name, "") or "").strip()
        if not v:
            return None
        try:
            return float(v)
        except Exception:
            return None
    def _int_env(name: str) -> Optional[int]:
        v = (os.environ.get(name, "") or "").strip()
        if not v:
            return None
        try:
            return int(v)
        except Exception:
            return None
    temp = _float_env("REVIEWER_TEMPERATURE")
    top_p = _float_env("REVIEWER_TOP_P")
    seed = _int_env("REVIEWER_SEED")
    if deterministic:
        if temp is None:
            temp = 0.0
        if top_p is None:
            top_p = 1.0
    if temp is None:
        temp = 0.1
    # Optional: freeze review output across cycles
    freeze_review = _env_truthy("REVIEWER_FREEZE_REVIEW") or freeze_inputs
    review_cache_path = _freeze_dir_for_pr(pr_no) / "review.md"
    try:
        if freeze_review and review_cache_path.exists():
            review_md = review_cache_path.read_text(encoding="utf-8")
        else:
            review_md = call_llm(api_base, api_key, model, messages, temperature=temp, max_tokens=1600, top_p=top_p, seed=seed)
            if freeze_review:
                review_cache_path.parent.mkdir(parents=True, exist_ok=True)
                review_cache_path.write_text(review_md, encoding="utf-8")
    except requests.HTTPError as e:
        print(f"LLM error: {e.response.status_code} {e.response.text[:200]}")
        sys.exit(0)

    # Optional: dump review to file when not posting
    out_path = (os.environ.get("REVIEWER_OUTPUT_PATH", "") or "").strip()
    if out_path and (no_post or comment_only):
        try:
            p = Path(out_path)
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(review_md, encoding="utf-8")
            print(f"Reviewer: wrote review markdown to {p}")
        except Exception as ex:
            print(f"[WARN] Failed to write REVIEWER_OUTPUT_PATH: {ex}", file=sys.stderr)

    if not no_post:
        post_pr_review(token, ctx["owner"], ctx["repo"], pr_no, review_md)
    else:
        print("Reviewer: no-post/dry-run — skipped posting PR review.")
    if not no_labels:
        label_issue(token, ctx["owner"], ctx["repo"], pr_no, ["codex-reviewed"])
    else:
        print("Reviewer: no-labels/dry-run — skipped labeling PR.")
    meta = {
        "pr": pr_no,
        "title": title,
        "changed_paths": changed_paths,
        "srs_ids": srs_touched,
        "truncated_diff": truncated,
        "lint_summary_present": bool(lint_out),
        "model": model,
        "branch": subprocess.run(["git","rev-parse","--abbrev-ref","HEAD"], capture_output=True, text=True, check=False).stdout.strip(),
        "pr_head": (pr.get("head",{}) or {}).get("ref", ""),
        "comment_only": comment_only,
        "dry_run": dry_run,
        "no_post": no_post,
        "no_labels": no_labels
    }
    if not (comment_only or dry_run):
        save_review(pr_no, review_md, meta)
    else:
        print("Reviewer: comment-only/dry-run — skipped saving artifacts.")
    print("Reviewer completed.")

if __name__ == "__main__":
    try:
        main()
    except requests.HTTPError as e:
        print(f"[HTTP ERROR] {e.response.status_code} {e.response.text}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(3)
