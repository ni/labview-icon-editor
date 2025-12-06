#!/usr/bin/env python3
from pathlib import Path
import re
SRS = Path("docs/srs")
def renumber_block(text: str, header: str, prefix: str):
    m = re.search(rf"(## {re.escape(header)}\s*\n)(.+?)(?=\n## |\Z)", text, re.S)
    if not m: return text
    start, body = m.group(1), m.group(2)
    out, k = [], 1
    for ln in body.splitlines():
        if ln.strip().startswith("-"):
            ln = re.sub(rf"^- +{prefix}\d+\.\s", f"- {prefix}{k}. ", ln)
            if not re.search(rf"^- +{prefix}\d+\.\s", ln): ln = re.sub(r"^- +", f"- {prefix}{k}. ", ln, count=1)
            k += 1
        out.append(ln)
    return text[:m.start(2)] + "\n".join(out) + text[m.end(2):]
def main():
    for p in sorted(SRS.glob("FGC-REQ-*.md")):
        t=p.read_text(errors="ignore")
        t=renumber_block(t,"Statement(s)","RQ")
        m = re.search(r"(Acceptance Criteria:\s*\n)(.+?)(?=\n## |\Z)", t, re.S)
        if m:
            head, body = m.group(1), m.group(2)
            out, k = [], 1
            for ln in body.splitlines():
                if ln.strip().startswith("-"):
                    ln = re.sub(r"^- +AC\d+\.\s", f"- AC{k}. ", ln); 
                    if not re.search(r"^- +AC\d+\.\s", ln): ln = re.sub(r"^- +", f"- AC{k}. ", ln, count=1)
                    k += 1
                out.append(ln)
            t = t[:m.start(2)] + "\n".join(out) + t[m.end(2):]
        p.write_text(t, encoding="utf-8")
    print("Renumbered RQ/AC across SRS files.")
if __name__=="__main__": main()

