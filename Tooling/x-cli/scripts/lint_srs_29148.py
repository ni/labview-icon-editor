#!/usr/bin/env python3
from pathlib import Path
import re, sys, os
from ruamel.yaml import YAML  # type: ignore
SRS_DIR = Path("docs/srs")
ATTR = (SRS_DIR / "attributes.yaml")
_yaml = YAML(typ="safe")
ATTR_SCHEMA = _yaml.load(ATTR.read_text()) if ATTR.exists() else {}
BAD_WORDS = re.compile(r"\b(easy|user[- ]?friendly|quick|fast|adequate|sufficient|robust|flexible|scalable|typically|generally|approximately|etc\.?)\b", re.I)
TBD = re.compile(r"\b(TBD|TBS|TBR)\b")
REQ_ID = re.compile(r"\b[A-Z]{3}-REQ-[A-Z-]+-\d{3}\b")
def section(text, header):
    m = re.search(rf"## {re.escape(header)}\s*(.+?)(?=\n## |\Z)", text, re.S); return (m.group(1) if m else "").strip()
def lint_one(path: Path) -> tuple[list[str], list[str]]:
    t=path.read_text(encoding="utf-8", errors="ignore"); errs=[]
    # Parse attributes early to allow conditional relaxations (e.g., Deprecated)
    def parse_attrs(text: str) -> dict:
        attr_txt = section(text, "Attributes")
        pairs = {}
        for ln in attr_txt.splitlines():
            if ":" in ln:
                k, v = ln.split(":", 1)
                pairs[k.strip().lower()] = v.strip()
        return pairs
    attrs = parse_attrs(t)
    status = attrs.get("status", "")
    is_deprecated = status.lower() == "deprecated"
    infos: list[str] = []
    if is_deprecated:
        infos.append(f"INFO: {path} - Deprecated requirement detected; relaxed checks applied (shall/AC/vague terms).")
    # Required sections
    for sec in ATTR_SCHEMA.get("required_sections", ["Statement(s)","Rationale","Verification","Attributes"]):
        if f"## {sec}" not in t: errs.append(f"missing '## {sec}' section")
    # ID present & language
    if not REQ_ID.search(t): errs.append("no requirement ID found in file header")
    # Allow Deprecated requirements to omit normative 'shall' language
    if not is_deprecated and not re.search(r"\bshall\b", t, re.I):
        errs.append("no 'shall' in normative statements")
    if not is_deprecated and BAD_WORDS.search(t):
        errs.append("vague terms present (avoid easy/robust/sufficient/etc.)")
    if TBD.search(t): errs.append("contains TBD/TBS/TBR placeholder(s)")
    # Statements: atomic and numbered
    stm = section(t, "Statement(s)")
    rqs=[ln for ln in stm.splitlines() if ln.strip().startswith("-")]
    if not rqs: errs.append("no RQ bullets in Statement(s)")
    for i, ln in enumerate(rqs,1):
        if not re.search(r"^- +RQ\d+\.\s", ln): errs.append(f"Statement(s) line {i}: expected '- RQ<i>. <shall...>' numbering")
        if len(re.findall(r"\bshall\b", ln, re.I))>1: errs.append(f"Statement(s) line {i}: multiple 'shall' (split to atomic)")
        if re.search(r"\band/or\b", ln, re.I): errs.append(f"Statement(s) line {i}: contains 'and/or'")
        if re.search(r"\b(\.github/|\.ya?ml|\.py|/src/|/scripts/|/tests/)\b", ln): errs.append(f"Statement(s) line {i}: implementation path detected (move to Trace)")
    # Verification: AC numbering
    ver = section(t, "Verification")
    # Allow Deprecated requirements to omit AC details
    if "Acceptance Criteria:" not in ver:
        if not is_deprecated:
            errs.append("missing 'Acceptance Criteria' under Verification")
    else:
        ac_block = ver.split("Acceptance Criteria:",1)[1]
        ac=[ln for ln in ac_block.splitlines() if ln.strip().startswith("-")]
        if not ac and not is_deprecated:
            errs.append("no AC bullets under Acceptance Criteria")
        for i, ln in enumerate(ac,1):
            if not re.search(r"^- +AC\d+\.\s", ln):
                errs.append(f"AC line {i}: expected '- AC<i>. ...' numbering")
    # Attributes enums
    for key in ["priority","owner","status"]:
        if key not in attrs: errs.append(f"Attributes: missing {key}")
        else:
            enum = ATTR_SCHEMA.get(key,{}).get("enum")
            if enum and attrs[key] not in enum:
                errs.append(f"Attributes: '{key}' value '{attrs[key]}' not in schema enum")
    # Rationale & Trace placeholders
    rat = section(t, "Rationale")
    if not rat or re.search(r"<why this requirement|<filled by author>", rat, re.I): errs.append("Rationale: must be substantive (no placeholder)")
    if re.search(r"Trace:\s*<add (paths|evidence)[^>]*>", t, re.I): errs.append("Attributes: Trace must list real evidence paths (not placeholder)")
    return [f"{path}: {e}" for e in errs], infos
def main():
    failures=[]
    infos_all: list[str] = []
    for p in sorted(SRS_DIR.glob("FGC-REQ-*.md")):
        errs, infos = lint_one(p)
        failures += errs
        infos_all += infos
    # Optional verbose mode: always print infos. Otherwise, print only when failures occur.
    verbose = os.environ.get("SRS_LINT_VERBOSE", "0") not in ("0", "false", "False", "")
    if failures:
        if infos_all:
            print("\n".join(infos_all))
        print("\n".join(failures))
        sys.exit(1)
    else:
        if infos_all and verbose:
            print("\n".join(infos_all))
        print("SRS 29148 lint: OK")
if __name__=="__main__": main()
