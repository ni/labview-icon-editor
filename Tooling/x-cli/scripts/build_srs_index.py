#!/usr/bin/env python3
from pathlib import Path
import re
from ruamel.yaml import YAML
ROOT = Path(__file__).resolve().parents[1]
SRS = ROOT / "docs" / "srs"; OUT = SRS / "index.yaml"
# Accept domains with optional hyphen segments (e.g., QA, QA-COV)
RID = re.compile(r"\b([A-Z]{3}-REQ-([A-Z-]+)-(\d{3}))\b")
def parse(p: Path):
    t=p.read_text(errors="ignore")
    ridm=RID.search(t); title=re.search(r"^#\s+(.+)$", t, re.M)
    version=re.search(r"^Version:\s*([^\n]+)", t, re.M)
    owner=re.search(r"^Owner:\s*([^\n]+)", t, re.M)
    priority=re.search(r"^Priority:\s*([^\n]+)", t, re.M)
    status=re.search(r"^Status:\s*([^\n]+)", t, re.M)
    methods=re.findall(r"Method\(s\):\s*([^\n]+)", t)
    if not ridm: return None
    rid, domain, num = ridm.group(1), ridm.group(2), int(ridm.group(3))
    return {"id":rid,"title":title.group(1).strip() if title else p.stem,"domain":domain,"number":num,
            "version":version.group(1).strip() if version else "","priority":priority.group(1).strip() if priority else "",
            "owner":owner.group(1).strip() if owner else "","status":status.group(1).strip() if status else "",
            "verification_methods":[m.strip() for m in methods[-1].split("|")] if methods else [],
            "file":p.relative_to(ROOT).as_posix()}
def main():
    rows=[r for r in (parse(p) for p in sorted(SRS.glob("FGC-REQ-*.md"))) if r]
    data = {"count": len(rows), "requirements": rows}
    yaml = YAML(typ="safe")
    yaml.default_flow_style = False
    with OUT.open("w", encoding="utf-8") as f:
        yaml.dump(data, f)
    print(f"Wrote {OUT.relative_to(ROOT).as_posix()} with {len(rows)} items.")
if __name__=="__main__": main()
