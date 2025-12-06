#!/usr/bin/env python3
from __future__ import annotations
import os, subprocess, xml.etree.ElementTree as ET

TARGETS = ("codex_rules/correlate.py", "codex_rules/guidance.py")
MARK = "<!-- coverage-summary-guidance -->"

def parse(xml_path: str):
    root = ET.parse(xml_path).getroot()
    total = float(root.attrib.get("line-rate", 0.0)) * 100.0
    per = {}
    for cls in root.findall(".//class"):
        fn = cls.attrib.get("filename") or ""
        rate = cls.attrib.get("line-rate")
        if rate is None: 
            continue
        per[fn] = float(rate) * 100.0
    return total, per

def render(total, per) -> str:
    lines = [MARK, "### Guidance Coverage", ""]
    lines.append(f"**Total:** {total:.1f}%")
    lines.append("")
    lines.append("| File | Coverage |")
    lines.append("|---|---:|")
    for t in TARGETS:
        v = next((per[k] for k in per if k.endswith(t)), None)
        lines.append(f"| `{t}` | {('%.1f%%' % v) if v is not None else '-'} |")
    lines.append("")
    lines.append("For local coverage steps, see `x-cli/docs/coverage.md`.")
    lines.append("")
    lines.append(MARK)
    return "\n".join(lines)

def main():
    body = render(*parse("coverage.xml"))
    print(body)
    step = os.environ.get("GITHUB_STEP_SUMMARY")
    if step:
        try:
            with open(step, "a", encoding="utf-8") as fh:
                fh.write(body + "\n")
        except Exception:
            pass
if __name__ == "__main__":
    main()
