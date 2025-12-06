#!/usr/bin/env python3
"""
Ensure required labels exist (idempotent).
Uses GITHUB_TOKEN and repo context.

Optional: --file <labels.json> to load label definitions from a JSON array:
[
  {"name":"coverage:conservative","color":"fbca04","description":"..."},
  {"name":"coverage:raise-iteratively","color":"0e8a16","description":"..."}
]
If omitted, built‑in REQUIRED set is used.
"""
from pathlib import Path
import os, sys, json, requests

API = "https://api.github.com"
REQUIRED = {
    "codex":               {"color":"6f42c1", "description":"Issue/PR is in the Codex ChatOps channel"},
    "codex-proposal":      {"color":"1f6feb", "description":"Draft PR created by Codex proposal"},
    "needs-human-review":  {"color":"fbca04", "description":"Human review required before merge"},
    "codex-reviewed":      {"color":"0e8a16", "description":"AI reviewer posted a critique"},
}

def gh(token, path):
    return requests.get(f"{API}{path}", headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}, timeout=30)

def gh_post(token, path, payload):
    return requests.post(f"{API}{path}", headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}, json=payload, timeout=30)

def gh_patch(token, path, payload):
    return requests.patch(f"{API}{path}", headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"}, json=payload, timeout=30)

def main():
    # Optional file arg
    labels_file = None
    if len(sys.argv) >= 3 and sys.argv[1] in {"--file","-f"}:
        labels_file = sys.argv[2]

    token = os.environ.get("GITHUB_TOKEN")
    repo = os.environ.get("GITHUB_REPOSITORY","")
    if not token or not repo:
        print("GITHUB_TOKEN or GITHUB_REPOSITORY missing", file=sys.stderr); sys.exit(1)
    owner, _, name = repo.partition("/")
    r = gh(token, f"/repos/{owner}/{name}/labels?per_page=100")
    r.raise_for_status()
    existing = {lbl["name"]: lbl for lbl in r.json()}
    # Load desired labels
    desired = REQUIRED.copy()
    if labels_file:
        try:
            arr = json.loads(Path(labels_file).read_text(encoding="utf-8"))
            if isinstance(arr, list):
                for it in arr:
                    if not isinstance(it, dict):
                        continue
                    n = it.get("name"); c = it.get("color"); d = it.get("description")
                    if isinstance(n,str) and isinstance(c,str) and isinstance(d,str):
                        desired[n] = {"color": c, "description": d}
        except Exception as exc:
            print(f"Warning: failed to load labels from {labels_file}: {exc}", file=sys.stderr)

    created, updated, ok = [], [], []
    for name_lbl, meta in desired.items():
        if name_lbl in existing:
            # ensure color/description
            cur = existing[name_lbl]
            if cur.get("color","").lower()!=meta["color"].lower() or (cur.get("description") or "") != meta["description"]:
                gh_patch(token, f"/repos/{owner}/{name}/labels/{name_lbl}", {"new_name":name_lbl, **meta})
                print(f"Updated label {name_lbl}")
                updated.append(name_lbl)
            else:
                print(f"Label {name_lbl} OK")
                ok.append(name_lbl)
        else:
            gh_post(token, f"/repos/{owner}/{name}/labels", {"name":name_lbl, **meta}).raise_for_status()
            print(f"Created label {name_lbl}")
            created.append(name_lbl)
    # Labels present in repo but not in desired set
    extra = sorted([k for k in existing.keys() if k not in desired])

    summary = {
        "repository": repo,
        "created": created,
        "updated": updated,
        "ok": ok,
        "extra": extra,
        "total": len(desired),
    }
    # Optional diagnostics output
    out_path = os.environ.get("LABELS_SUMMARY_PATH", "telemetry/labels-sync-summary.json")
    try:
        p = Path(out_path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(summary, indent=2), encoding="utf-8")
        print(f"Wrote labels summary to {p}")
    except Exception as exc:
        print(f"Warning: failed to write labels summary: {exc}", file=sys.stderr)
    print("Labels in sync.")

if __name__ == "__main__":
    main()
