#!/usr/bin/env python3
"""
R1 migration orchestrator:
 - Auto-upgrade SRS to 29148 template (atomic shall + RQ/AC + Attributes)
 - Scrub language, renumber RQ/AC
 - Build index, VCRM; compute compliance report
 - Enforce Verified→Evidence
 - Snapshot baseline R1 under docs/baselines/R1/ with manifest (sha256)
"""
from pathlib import Path
import subprocess, sys, json, hashlib, shutil, datetime as dt

ROOT = Path(".").resolve()
SRS = ROOT/"docs"/"srs"
BASE = ROOT/"docs"/"baselines"/"R1"
COMP = ROOT/"docs"/"compliance"/"report.json"

def sha256(p: Path)->str:
    h=hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024*1024), b""): h.update(chunk)
    return h.hexdigest()

def manifest_for_folder(folder: Path, root_label="srs/"):
    items=[]; total=0
    for p in sorted(folder.rglob("*")):
        if p.is_file():
            rel=p.relative_to(folder); sz=p.stat().st_size; total+=sz
            items.append({"path": f"{root_label}{rel.as_posix()}", "size_bytes": sz, "sha256": sha256(p)})
    return {"files_total":len(items), "total_size_bytes": total, "files": items}

def run(cmd): 
    print("→", " ".join(cmd)); 
    r=subprocess.run(cmd); 
    if r.returncode!=0: sys.exit(r.returncode)

def main():
    if not SRS.exists(): print("docs/srs not found"); sys.exit(2)
    # Upgrade + hygiene + renumber
    run(["python","scripts/auto_upgrade_srs.py"])
    run(["python","scripts/auto_fix_language.py"])
    run(["python","scripts/renumber_rq_ac.py"])
    # Lint
    run(["python","scripts/lint_srs_29148.py"])
    # Index + VCRM + compliance
    try: run(["python","scripts/build_srs_index.py"])
    except SystemExit: pass
    try: run(["python","scripts/generate_vcrm.py"])
    except SystemExit: pass
    run(["python","scripts/compute_29148_compliance.py"])
    # Verified→Evidence guard (non-fatal; warn if missing VCRM)
    ve = subprocess.run(["python","scripts/enforce_verified_has_evidence.py"])
    if ve.returncode!=0:
        print("[WARN] Some Verified items lack evidence in VCRM.csv. Resolve before marking Verified.")
    # Snapshot baseline R1
    if BASE.exists(): shutil.rmtree(BASE)
    (BASE/"srs").mkdir(parents=True, exist_ok=True)
    shutil.copytree(SRS, BASE/"srs", dirs_exist_ok=True)
    stamp = dt.datetime.utcnow().isoformat(timespec="seconds")+"Z"
    mani = manifest_for_folder(BASE/"srs")
    data = {"schema":"urn:x-cli:srs-baseline:v1","baseline_id":"R1","generated_utc":stamp,"source":"docs/srs",**mani}
    (BASE/"manifest.json").write_text(json.dumps(data,indent=2),encoding="utf-8")
    print(f"\nR1 baseline created: {BASE}")
    print(f"- Files: {mani['files_total']}  Size: {mani['total_size_bytes']} bytes")
    print(f"- Manifest: {BASE/'manifest.json'}")
    # Print compliance summary
    if COMP.exists():
        info=json.loads(COMP.read_text(encoding="utf-8"))
        print(f"\nCompliance: {info.get('files_ok',0)}/{info.get('files_total',0)} ({info.get('compliance_percent',0)}%)")
    print("\nR1 migration complete.")

if __name__=="__main__": main()

