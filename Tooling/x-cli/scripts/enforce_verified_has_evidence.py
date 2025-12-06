#!/usr/bin/env python3
from pathlib import Path
import csv, re, sys
ROOT = Path(__file__).resolve().parents[1]
SRS = ROOT/"docs"/"srs"; VCRM = ROOT/"docs"/"VCRM.csv"
RID = re.compile(r"\b[A-Z]{3}-REQ-[A-Z]+-\d{3}\b")
def statuses():
    out={}
    for p in SRS.glob("FGC-REQ-*.md"):
        t=p.read_text(errors="ignore"); m=RID.search(t)
        if not m: continue
        st=re.search(r"^Status:\s*([^\n]+)", t, re.M); out[m.group(0)]=(st.group(1).strip() if st else "Proposed")
    return out
def vcrm_counts():
    if not VCRM.exists(): return {}
    counts={}
    with VCRM.open() as f:
        for row in csv.DictReader(f): counts[row["Requirement ID"].strip()] = int(row.get("Evidence count","0"))
    return counts
def main():
    st=statuses(); cnt=vcrm_counts(); errs=[]
    for rid, s in st.items():
        if s.lower()=="verified" and cnt.get(rid,0)==0:
            errs.append(f"{rid}: Status=Verified but no evidence in VCRM.csv")
    if errs: print("\n".join(errs)); sys.exit(1)
    print("Verified→evidence: OK")
if __name__=="__main__": main()

