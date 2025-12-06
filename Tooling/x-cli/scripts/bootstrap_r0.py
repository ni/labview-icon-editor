#!/usr/bin/env python3
"""
Bootstrap Revision 0 (R0) for ISO/IEC/IEEE 29148 scaffolding and snapshot the current SRS.
 - Ensures minimal files exist (template, attributes, core, conformance page)
 - Runs linter (report-only) and compliance summary
 - Creates docs/baselines/R0/ with a copy of docs/srs and a manifest (sha256, sizes)
"""
from pathlib import Path
import hashlib, json, shutil, datetime as dt

ROOT = Path(".").resolve()
SRS = ROOT/"docs"/"srs"
CONF = ROOT/"docs"/"compliance"
BASE = ROOT/"docs"/"baselines"/"R0"

def sha256(p: Path)->str:
    h=hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024*1024), b""): h.update(chunk)
    return h.hexdigest()

def copy_tree(src: Path, dst: Path):
    if dst.exists(): shutil.rmtree(dst)
    shutil.copytree(src, dst)

def manifest_for_folder(folder: Path, root_label="srs/"):
    items=[]
    total=0
    for p in sorted(folder.rglob("*")):
        if p.is_file():
            rel = p.relative_to(folder)
            sz = p.stat().st_size
            total += sz
            items.append({"path": f"{root_label}{rel.as_posix()}", "size_bytes": sz, "sha256": sha256(p)})
    return {"files_total":len(items), "total_size_bytes": total, "files": items}

def ensure_minimum_files():
    # created by patch; just verify
    needed = [SRS/"_template.md", SRS/"attributes.yaml", ROOT/"docs"/"srs"/"core.md", ROOT/"docs"/"compliance"/"29148-conformance.md"]
    missing = [str(p) for p in needed if not p.exists()]
    if missing:
        raise SystemExit("Missing expected bootstrap files:\n - " + "\n - ".join(missing))

def run():
    ensure_minimum_files()
    CONF.mkdir(parents=True, exist_ok=True)
    # 1) Report-only linter + compliance summary
    import subprocess, sys
    subprocess.run(["python","scripts/lint_srs_29148.py"], check=False)
    subprocess.run(["python","scripts/compute_29148_compliance.py"], check=False)
    # 2) Snapshot baseline R0
    if not SRS.exists(): raise SystemExit("docs/srs not found; nothing to baseline.")
    BASE.mkdir(parents=True, exist_ok=True)
    copy_tree(SRS, BASE/"srs")
    stamp = dt.datetime.utcnow().isoformat(timespec="seconds")+"Z"
    mani = manifest_for_folder(BASE/"srs")
    data = {
        "schema":"urn:x-cli:srs-baseline:v1",
        "baseline_id":"R0",
        "generated_utc": stamp,
        "source":"docs/srs",
        **mani
    }
    (BASE/"manifest.json").write_text(json.dumps(data,indent=2),encoding="utf-8")
    print(f"\nBaseline R0 created at {BASE}")
    print(f"- Files: {mani['files_total']}  Size: {mani['total_size_bytes']} bytes")
    print(f"- Manifest: {BASE/'manifest.json'}")

if __name__=="__main__": run()
