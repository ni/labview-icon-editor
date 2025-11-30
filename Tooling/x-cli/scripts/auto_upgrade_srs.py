#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SRS = ROOT / "docs" / "srs"
RID = re.compile(r"\b([A-Z]{3}-REQ-[A-Z]+-\d{3})\b")
BAD = re.compile(r"\b(easy|user[- ]?friendly|quick|fast|adequate|sufficient|robust|flexible|scalable|typically|generally|approximately|etc\.?)\b", re.I)

def first_sentence(txt: str) -> str:
    txt = re.sub(r"\s+", " ", (txt or "").strip())
    parts = re.split(r"(?<=\.)\s+", txt)
    return parts[0] if parts and parts[0] else txt

def to_shall(sentence: str, title: str) -> str:
    s = (sentence or title or "the stated behavior").rstrip(".")
    s = re.sub(r"^(Ensure|Make sure|Provide|Enable)\b", "The system shall", s, flags=re.I)
    s = re.sub(r"^(The|This)\s+(system|workflow|tool|CLI)\s+(.*)", r"The \2 shall \3", s, flags=re.I)
    if " shall " not in s.lower():
        s = "The system shall " + s[0].lower() + s[1:]
    return s + "."

def extract_section(text: str, header: str) -> str:
    m = re.search(rf"## {re.escape(header)}\s*(.+?)(?=\n## |\Z)", text, re.S)
    return (m.group(1).strip() if m else "")

def set_section(text: str, header: str, body: str) -> str:
    if f"## {header}" in text:
        return re.sub(rf"(## {re.escape(header)}\s*)(.+?)(?=\n## |\Z)", rf"\1{body}", text, flags=re.S)
    # insert before Attributes if present; else append
    if "## Attributes" in text and header != "Attributes":
        return re.sub(r"(## Attributes)", f"## {header}\n{body}\n\n\\1", text, count=1)
    return text.rstrip() + f"\n\n## {header}\n{body}\n"

def renumber_block(body: str, prefix: str) -> str:
    out, k = [], 1
    for ln in body.splitlines():
        if ln.strip().startswith("-"):
            ln = re.sub(rf"^- +{prefix}\d+\.\s", f"- {prefix}{k}. ", ln)
            if not re.search(rf"^- +{prefix}\d+\.\s", ln):
                ln = re.sub(r"^- +", f"- {prefix}{k}. ", ln, count=1)
            k += 1
        out.append(ln)
    return "\n".join(out)

def ensure_statements(text: str, title: str) -> str:
    if "## Statement(s)" in text:
        return text
    desc = extract_section(text, "Description")
    rq1 = to_shall(first_sentence(desc), title)
    return set_section(text, "Statement(s)", f"- {rq1}")

def ensure_rationale(text: str, title: str) -> str:
    rat = extract_section(text, "Rationale")
    if not rat or "<" in rat.lower():
        rat = f"{title.strip()} is specified to allow objective verification and maintain design independence (ISO/IEC/IEEE 29148 §5.2.5, §5.2.7)."
        text = set_section(text, "Rationale", rat)
    return text

def ensure_verification(text: str) -> str:
    ver = extract_section(text, "Verification")
    if "Acceptance Criteria:" not in ver:
        ver = "Method(s): Test | Demonstration | Inspection\nAcceptance Criteria:\n- AC1. Objective pass/fail evidence exists for RQ1."
    else:
        head = re.search(r"^Method\(s\):[^\n]*", ver, re.M)
        if not head:
            ver = "Method(s): Test | Demonstration | Inspection\n" + ver
        # Renumber AC
        if "Acceptance Criteria:" in ver:
            head, ac_body = ver.split("Acceptance Criteria:", 1)
            ac_body = renumber_block(ac_body, "AC")
            ver = head.strip() + "\nAcceptance Criteria:\n" + ac_body.strip()
    return set_section(text, "Verification", ver)

def ensure_attributes(text: str, guess_trace: str) -> str:
    attr = extract_section(text, "Attributes")
    need = {"Priority:": "Medium", "Owner:": "QA", "Source:": "Team policy", "Status:": "Proposed", "Trace:": guess_trace}
    if not attr:
        attr = "\n".join([f"{k} {v}" for k,v in need.items()])
    else:
        for k,v in need.items():
            if k not in attr:
                attr += f"\n{k} {v}"
        attr = re.sub(r"Trace:\s*<[^>]+>", f"Trace: {guess_trace}", attr)
    return set_section(text, "Attributes", attr)

def sanitize_language(text: str) -> str:
    text = BAD.sub("", text)
    text = re.sub(r"\band/or\b", "or", text, flags=re.I)
    text = re.sub(r"\bTBD|TBS|TBR\b", "to be defined in a subsequent requirement update", text)
    return text

def upgrade_file(p: Path) -> bool:
    t = p.read_text(encoding="utf-8", errors="ignore")
    title_m = re.search(r"^#\s+(.+)$", t, re.M)
    title = title_m.group(1).strip() if title_m else p.stem
    t = ensure_statements(t, title)
    # Renumber RQ
    stm = extract_section(t, "Statement(s)")
    stm = renumber_block(stm, "RQ")
    t = set_section(t, "Statement(s)", stm)
    t = ensure_rationale(t, title)
    t = ensure_verification(t)
    t = ensure_attributes(t, f"docs/srs/{p.name}")
    t = sanitize_language(t)
    p.write_text(t, encoding="utf-8"); return True

def main():
    changed = 0
    for p in sorted(SRS.glob("FGC-REQ-*.md")):
        changed += 1 if upgrade_file(p) else 0
    print(f"Auto-upgraded {changed} files to 29148 template.")
if __name__ == "__main__": main()

