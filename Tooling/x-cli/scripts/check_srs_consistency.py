#!/usr/bin/env python3
from pathlib import Path
import re, sys, yaml, collections
ROOT = Path(__file__).resolve().parents[1]
IDX = ROOT / "docs" / "srs" / "index.yaml"; SRS = ROOT / "docs" / "srs"
def load(): return yaml.safe_load(IDX.read_text())
def read_text(p): return p.read_text(errors="ignore")
def main():
    if not IDX.exists(): print("index.yaml not found; run build_srs_index.py"); sys.exit(1)
    idx = load(); reqs = idx.get("requirements", []); errs=[]
    seen = collections.Counter(r["id"] for r in reqs); dups=[k for k,c in seen.items() if c>1]
    if dups: errs.append(f"Duplicate IDs: {', '.join(dups)}")
    for r in reqs:
        t = read_text(Path(r["file"]))
        stm = re.search(r"## Statement\(s\)(.+?)(?=\n## |\Z)", t, re.S)
        if not stm: continue
        part = stm.group(1)
        if re.search(r"\bshall\b", part, re.I) and re.search(r"\bshall\s+not\b", part, re.I):
            errs.append(f"{r['id']}: contains both 'shall' and 'shall not' in Statement(s) (split/clarify).")
    if errs: print("\n".join(errs)); sys.exit(1)
    print("SRS consistency: OK")
if __name__=="__main__": main()

