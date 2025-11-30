from pathlib import Path
import sys, json, csv
from ruamel.yaml import YAML

E_PREFIX = "[SRS-MAINT]"

def _hint(msg: str) -> str:
    return f"{msg} — hint: see docs/compliance/SRS-MAINTENANCE.md"

def run_checks(root: Path = Path(".")) -> list[str]:
    """Return a list of error strings (empty means OK)."""
    errors = []
    srs_dir = root / "docs" / "srs"
    index   = root / "docs" / "srs" / "index.yaml"
    vcrm    = root / "docs" / "VCRM.csv"
    report  = root / "docs" / "compliance" / "report.json"

    # E1: inputs
    if not srs_dir.exists():
        errors.append(_hint(f"{E_PREFIX} E1: missing directory docs/srs; create docs/srs and ensure SRS pages exist"))
        return errors  # other checks depend on this path

    # E2: index.yaml
    if not index.exists():
        errors.append(_hint(f"{E_PREFIX} E2: missing docs/srs/index.yaml; run scripts/build_srs_index.py"))
    else:
        try:
            idx = YAML(typ='safe').load(index.read_text(encoding="utf-8"))
            count = idx.get("count")
            reqs  = idx.get("requirements") or []
            if not isinstance(count, int):
                errors.append(_hint(f"{E_PREFIX} E2.1: index.yaml 'count' must be an integer"))
            if not isinstance(reqs, list):
                errors.append(_hint(f"{E_PREFIX} E2.2: index.yaml 'requirements' must be a list"))
            # membership: every FGC-REQ page appears in index
            fgc_files = [("docs/srs/" + p.name) for p in sorted((srs_dir).glob("FGC-REQ-*.md"))]
            in_index  = sorted({str(r.get("file","")) for r in reqs if isinstance(r, dict)})
            missing   = sorted(set(fgc_files) - set(in_index))
            if count is not None and isinstance(count,int) and count != len(in_index):
                errors.append(_hint(f"{E_PREFIX} E2.3: index count {count} != entries {len(in_index)}; rerun index builder"))
            if missing:
                tip = ", ".join(missing[:10]) + (" ..." if len(missing)>10 else "")
                errors.append(_hint(f"{E_PREFIX} E2.4: files missing from index: {tip}; ensure index builder includes all FGC-REQ-*.md"))
        except Exception as e:
            errors.append(_hint(f"{E_PREFIX} E2.x: index.yaml invalid: {e}"))

    # E3: VCRM.csv schema
    if not vcrm.exists():
        errors.append(_hint(f"{E_PREFIX} E3: missing docs/VCRM.csv; run scripts/generate_vcrm.py"))
    else:
        try:
            rows = list(csv.DictReader(vcrm.read_text(encoding="utf-8").splitlines()))
            if rows:
                hdr = set(rows[0].keys())
                for need in ("Requirement ID","Evidence count"):
                    if need not in hdr:
                        errors.append(_hint(f"{E_PREFIX} E3.1: VCRM.csv missing column '{need}'"))
        except Exception as e:
            errors.append(_hint(f"{E_PREFIX} E3.x: VCRM.csv unreadable: {e}"))

    # E4: compliance report numeric & sane
    if not report.exists():
        errors.append(_hint(f"{E_PREFIX} E4: missing docs/compliance/report.json; run scripts/compute_29148_compliance.py"))
    else:
        try:
            data = json.loads(report.read_text(encoding="utf-8"))
            pct = float(data.get("compliance_percent"))
            if not (0.0 <= pct <= 100.0):
                errors.append(_hint(f"{E_PREFIX} E4.1: compliance_percent out of range: {pct}; recompute compliance"))
        except Exception as e:
            errors.append(_hint(f"{E_PREFIX} E4.x: report.json invalid: {e}"))

    return errors

if __name__ == "__main__":
    errs = run_checks(Path("."))
    if errs:
        print("SMOKE TEST FAILED (objective checks):")
        for e in errs: print("-", e)
        sys.exit(1)
    print("SMOKE TEST OK")
