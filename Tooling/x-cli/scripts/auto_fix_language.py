#!/usr/bin/env python3
from pathlib import Path
import re
SRS = Path("docs/srs")
BAD = {
    r"\beasy\b":"", r"user[- ]?friendly":"", r"\bquick\b":"rapid", r"\bfast\b":"rapid",
    r"\badequate\b":"", r"\bsufficient\b":"", r"\brobust\b":"resilient",
    r"\bflexible\b":"configurable", r"\bscalable\b":"scales to stated targets",
    r"\btypically\b":"", r"\bgenerally\b":"", r"\bapproximately\b":"(approx.)", r"\betc\.\?":""
}
def fix_text(t:str)->str:
    for pat,rep in BAD.items(): t = re.sub(pat, rep, t, flags=re.I)
    t = re.sub(r"\band/or\b","or", t, flags=re.I)
    t = re.sub(r"\bTBD|TBS|TBR\b","to be defined in a subsequent requirement update", t)
    return t
def main():
    files=list(SRS.glob("FGC-REQ-*.md"))
    for p in files: p.write_text(fix_text(p.read_text(errors="ignore")), encoding="utf-8")
    print(f"Scrubbed language in {len(files)} files.")
if __name__=="__main__": main()

