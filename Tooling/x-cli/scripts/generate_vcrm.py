#!/usr/bin/env python3
from pathlib import Path
import re, csv
ROOT = Path(__file__).resolve().parents[1]
SRS_DIR = ROOT / "docs" / "srs"
SEARCH_DIRS = [ROOT/"tests", ROOT/"src", ROOT/"scripts", ROOT/".github"/"workflows", ROOT/"docs"]
REQ = re.compile(r"\b[A-Z]{3}-REQ-[A-Z]+-\d{3}\b")
PY = re.compile(r'@pytest\.mark\.srs\(\s*[\'\"]({})[\'\"]\s*\)'.format(REQ.pattern))
CS = re.compile(r'\[Trait\(\s*"SRS"\s*,\s*"({})"\s*\)\]'.format(REQ.pattern))
WF = re.compile(r'#\s*SRS:\s*({})'.format(REQ.pattern))
INL = re.compile(r'\bSRS:\s*({})'.format(REQ.pattern))

def read(p):
    try:
        return p.read_text(encoding="utf-8")
    except:
        return p.read_text(errors="ignore")

def srs_meta():
    meta = {}
    for p in SRS_DIR.glob("FGC-REQ-*.md"):
        t = read(p)
        ids = set(REQ.findall(t))
        title = re.search(r"^#\s+(.+)$", t, re.M)
        for rid in ids:
            meta[rid] = {"file": p.relative_to(ROOT).as_posix(), "title": title.group(1).strip() if title else p.name}
    return meta

def find_markers(ids):
    cov = {rid: [] for rid in ids}
    kind = {}
    for d in SEARCH_DIRS:
        if not d.exists():
            continue
        for p in d.rglob("*"):
            if not p.is_file():
                continue
            t = read(p)
            found = set()
            if p.suffix == ".py":
                found |= set(PY.findall(t)) | set(INL.findall(t))
            elif p.suffix == ".cs":
                found |= set(CS.findall(t))
            elif p.suffix in {".yml", ".yaml"}:
                found |= set(WF.findall(t))
            else:
                found |= set(INL.findall(t))
            for rid in found:
                if rid in cov:
                    cov[rid].append(p.relative_to(ROOT).as_posix())
                    if p.parts[0] == "tests":
                        kind.setdefault(rid, set()).add("Test")
                    elif p.parts[0] == ".github":
                        kind.setdefault(rid, set()).add("Demonstration")
                    elif p.parts[0] == "scripts":
                        kind.setdefault(rid, set()).add("Demonstration")
                    elif p.parts[0] == "src":
                        kind.setdefault(rid, set()).add("Analysis")
                    else:
                        kind.setdefault(rid, set()).add("Inspection")
    return cov, kind

def main():
    meta = srs_meta()
    cov, kind = find_markers(meta.keys())
    rows = []
    for rid in sorted(meta.keys()):
        ev = cov.get(rid, [])
        methods = ", ".join(sorted(kind.get(rid, set())))
        rows.append({"Requirement ID": rid,
                     "SRS file": meta[rid]["file"],
                     "Title": meta[rid]["title"],
                     "Suggested Methods": methods,
                     "Evidence files (sample)": "; ".join(ev[:5]),
                     "Evidence count": len(ev)})
    out = ROOT / "docs" / "VCRM.csv"
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {out.relative_to(ROOT).as_posix()} with {len(rows)} rows.")

if __name__ == "__main__":
    main()
