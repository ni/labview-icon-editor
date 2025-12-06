#!/usr/bin/env python3
from pathlib import Path
import re, json, datetime as dt, os
SRS = Path("docs/srs"); OUT = Path("docs/compliance"); OUT.mkdir(parents=True, exist_ok=True)
BAD = re.compile(r"\b(easy|user[- ]?friendly|quick|fast|adequate|sufficient|robust|flexible|scalable|typically|generally|approximately|etc\.?)\b", re.I)
def has_sec(t,h): return f"## {h}" in t
def has_shall(t): return re.search(r"\bshall\b", t, re.I) is not None
def has_rq(t): return re.search(r"## Statement\(s\).*^- +RQ\d+\.\s", t, re.S|re.M) is not None
def has_ac(t): return re.search(r"Acceptance Criteria:\s*\n^- +AC\d+\.\s", t, re.S|re.M) is not None
def has_attrs(t): return "## Attributes" in t and all(k in t for k in ["Priority:", "Owner:", "Status:", "Trace:"])
def clean_lang(t): return not BAD.search(t) and not re.search(r"\bTBD|TBS|TBR\b", t)
def compliant(t):
    return all([has_sec(t,"Statement(s)"), has_rq(t), has_shall(t), has_sec(t,"Verification"), has_ac(t), has_attrs(t), clean_lang(t)])
def main():
    files=sorted([p for p in SRS.glob("FGC-REQ-*.md")])
    ok=sum(1 for p in files if compliant(p.read_text(errors="ignore")))
    pct=round(100.0*ok/len(files),1) if files else 0.0
    if os.getenv("TELEMETRY_USE_LOCAL_TIME") == "1":
        stamp=dt.datetime.now().astimezone().isoformat(timespec="seconds")
    else:
        stamp=dt.datetime.now(dt.UTC).isoformat(timespec="seconds")
    data={"timestamp_utc":stamp,"files_total":len(files),"files_ok":ok,"compliance_percent":pct}
    (OUT/"report.json").write_text(json.dumps(data,indent=2), encoding="utf-8")
    (OUT/"report.md").write_text(f"# 29148 Compliance Report ({stamp})\n- Files: **{len(files)}**\n- Fully compliant pages: **{ok}/{len(files)}**  (**{pct}%**)\n", encoding="utf-8")
    print(f"Compliant SRS pages: {ok}/{len(files)}  ({pct}%)")
if __name__=="__main__": main()
