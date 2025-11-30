"""Smoke tests for SRS maintenance edge cases."""
from pathlib import Path
import json, importlib.util, io
from ruamel.yaml import YAML

_ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "srs_maintenance_smoke", _ROOT / "scripts" / "srs_maintenance_smoke.py"
)
sms = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(sms)
run_checks = sms.run_checks
# sms.E_PREFIX contains the standard "[SRS-MAINT]" prefix used by run_checks

def _mk_ok_repo(tmp: Path):
    (tmp/"docs/srs").mkdir(parents=True, exist_ok=True)
    (tmp/"docs/compliance").mkdir(parents=True, exist_ok=True)
    (tmp/"docs").mkdir(exist_ok=True)
    # one SRS page
    (tmp/"docs/srs/FGC-REQ-FOO-001.md").write_text("""# FGC-REQ-FOO-001

## Statement(s)
- RQ1. The system shall ...

## Verification
Acceptance Criteria:
- AC1. ...

## Attributes
Priority: Medium
Owner: QA
Status: Proposed
Trace: docs/srs/FGC-REQ-FOO-001.md
""", encoding="utf-8")
    # index.yaml
    idx = {"count": 1, "requirements":[{"file":"docs/srs/FGC-REQ-FOO-001.md"}]}
    _yaml = YAML()
    buf = io.StringIO()
    _yaml.dump(idx, buf)
    (tmp/"docs/srs/index.yaml").write_text(buf.getvalue(), encoding="utf-8")
    # VCRM.csv
    (tmp/"docs/VCRM.csv").write_text("Requirement ID,Evidence count\nFGC-REQ-FOO-001,0\n", encoding="utf-8")
    # report.json
    (tmp/"docs/compliance/report.json").write_text(json.dumps({"compliance_percent": 100.0}), encoding="utf-8")

def test_happy_path(tmp_path: Path):
    _mk_ok_repo(tmp_path)
    assert run_checks(tmp_path) == []

def test_missing_index(tmp_path: Path):
    _mk_ok_repo(tmp_path)
    (tmp_path/"docs/srs/index.yaml").unlink()
    errs = run_checks(tmp_path)
    assert any(e.startswith(f"{sms.E_PREFIX} E2") for e in errs)

def test_bad_report(tmp_path: Path):
    _mk_ok_repo(tmp_path)
    (tmp_path/"docs/compliance/report.json").write_text("invalid JSON", encoding="utf-8")
    errs = run_checks(tmp_path)
    assert any(e.startswith(f"{sms.E_PREFIX} E4.x") for e in errs)

def test_missing_compliance_percent(tmp_path: Path):
    _mk_ok_repo(tmp_path)
    (tmp_path/"docs/compliance/report.json").write_text("{}", encoding="utf-8")
    errs = run_checks(tmp_path)
    assert any(e.startswith(f"{sms.E_PREFIX} E4.x") for e in errs)

def test_negative_compliance_percent(tmp_path: Path):
    _mk_ok_repo(tmp_path)
    (tmp_path/"docs/compliance/report.json").write_text(json.dumps({"compliance_percent": -1}), encoding="utf-8")
    errs = run_checks(tmp_path)
    assert any(e.startswith(f"{sms.E_PREFIX} E4.1") for e in errs)

def test_index_requirements_wrong_type(tmp_path: Path):
    _mk_ok_repo(tmp_path)
    bad = {"count": 1, "requirements": "not-a-list"}
    _yaml = YAML()
    buf = io.StringIO()
    _yaml.dump(bad, buf)
    (tmp_path/"docs/srs/index.yaml").write_text(buf.getvalue(), encoding="utf-8")
    errs = run_checks(tmp_path)
    assert any(e.startswith(f"{sms.E_PREFIX} E2.2") for e in errs)

def test_index_count_mismatch(tmp_path: Path):
    _mk_ok_repo(tmp_path)
    idx = YAML(typ='safe').load((tmp_path/"docs/srs/index.yaml").read_text())
    idx["count"] = 999
    _yaml = YAML()
    buf = io.StringIO()
    _yaml.dump(idx, buf)
    (tmp_path/"docs/srs/index.yaml").write_text(buf.getvalue(), encoding="utf-8")
    errs = run_checks(tmp_path)
    assert any(e.startswith(f"{sms.E_PREFIX} E2.3") for e in errs)

def test_vcrm_missing_column(tmp_path: Path):
    _mk_ok_repo(tmp_path)
    (tmp_path/"docs/VCRM.csv").write_text(
        "Requirement ID,SomethingElse\nFGC-REQ-FOO-001,0\n", encoding="utf-8"
    )
    errs = run_checks(tmp_path)
    assert any(e.startswith(f"{sms.E_PREFIX} E3.1") for e in errs)

def test_compliance_out_of_range(tmp_path: Path):
    _mk_ok_repo(tmp_path)
    (tmp_path/"docs/compliance/report.json").write_text(
        json.dumps({"compliance_percent": 123.45}), encoding="utf-8"
    )
    errs = run_checks(tmp_path)
    assert any(e.startswith(f"{sms.E_PREFIX} E4.1") for e in errs)

def test_missing_srs_dir(tmp_path: Path):
    errs = run_checks(tmp_path)
    assert any(e.startswith(f"{sms.E_PREFIX} E1") for e in errs)
