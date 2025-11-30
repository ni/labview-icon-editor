"""Edge-case unit tests for waterfall orchestration behaviors."""
from pathlib import Path
import json
import pytest
import scripts.waterfall_state as wf
import scripts.waterfall_artifacts as wa

def test_label_and_next_stage_math():
    assert wf.label_get_current(["stage:design","foo"]) == "design"
    assert wf.label_get_current(["foo"]) == "requirements"
    assert wf.next_stage("requirements") == "design"
    assert wf.next_stage("deployment") is None

def test_design_criteria_requires_approved_design_md(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    (Path("docs")).mkdir(parents=True, exist_ok=True)
    (Path("docs")/"Design.md").write_text("Status: Draft", encoding="utf-8")
    assert wf._criteria_ok("design","x/y","") is False
    (Path("docs")/"Design.md").write_text("Title\n\nStatus: Approved\n", encoding="utf-8")
    assert wf._criteria_ok("design","x/y","") is True

def test_state_roundtrip_is_ci_safe(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    monkeypatch.delenv("GITHUB_ACTIONS", raising=False)
    st = {"current_stage":"requirements","locked":[],"history":[]}
    wf.STATE_PATH = Path(".codex/state.json")
    wf._write_state(st)
    out = wf._read_state()
    assert out["current_stage"] == "requirements"

def test_testing_criteria_requires_stage2_artifact(monkeypatch):
    monkeypatch.setattr(wf, "_gh_json", lambda *a: {"artifacts":[{"name":"water-stage2-artifacts"}]})
    assert wf._criteria_ok("testing", "x/y", "") is True
    monkeypatch.setattr(wf, "_gh_json", lambda *a: {"artifacts":[{"name":"other"}]})
    assert wf._criteria_ok("testing", "x/y", "") is False

def test_implementation_criteria_requires_green_checks(monkeypatch):
    good = {
        "state": "success",
        "statuses": [
            {"context": "linux", "state": "success"},
            {"context": "windows", "state": "success"},
        ],
    }
    bad = {"state": "failure", "statuses": [{"context": "linux", "state": "failure"}]}
    monkeypatch.setattr(wf, "_gh_json", lambda *a: good)
    assert wf._criteria_ok("implementation", "x/y", "sha") is True
    monkeypatch.setattr(wf, "_gh_json", lambda *a: bad)
    assert wf._criteria_ok("implementation", "x/y", "sha") is False

def _write_event(tmp_path, labels):
    ev = {"pull_request":{"number":1,"head":{"sha":"abc"},"labels":[{"name":l} for l in labels]}}
    p = tmp_path/"event.json"
    p.write_text(json.dumps(ev))
    return str(p)

def test_advance_stays_when_criteria_fail(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(wf, "_apply_labels", lambda repo, pr, remove, add: None)
    event = _write_event(tmp_path, ["stage:requirements"])
    wf.STATE_PATH = Path(".codex/state.json")
    wf._advance("x/y", event, "msg")
    st = wf._read_state()
    assert st["current_stage"] == "requirements"
    assert st.get("locked") == []

def test_advance_moves_to_next_stage_when_criteria_pass(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    calls = []
    monkeypatch.setattr(wf, "_criteria_ok", lambda stage, repo, sha: True)
    monkeypatch.setattr(wf, "_apply_labels", lambda repo, pr, remove, add: calls.append((remove, add)))
    event = _write_event(tmp_path, ["stage:requirements"])
    wf.STATE_PATH = Path(".codex/state.json")
    wf._advance("x/y", event, "msg")
    st = wf._read_state()
    assert st["current_stage"] == "design"
    assert "requirements" in st.get("locked", [])
    assert calls and calls[0][1] == "stage:design"

def test_validate_rejects_locked_stage(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    wf.STATE_PATH = Path(".codex/state.json")
    wf._write_state({"current_stage":"design","locked":["design"],"history":[]})
    event = _write_event(tmp_path, ["stage:design"])
    with pytest.raises(SystemExit):
        wf._validate("x/y", event)

def test_validate_requires_design_doc(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    wf.STATE_PATH = Path(".codex/state.json")
    wf._write_state({"current_stage":"requirements","locked":[],"history":[]})
    event = _write_event(tmp_path, ["stage:implementation"])
    with pytest.raises(SystemExit):
        wf._validate("x/y", event)
    (Path("docs")).mkdir()
    (Path("docs")/"Design.md").write_text("Status: Approved", encoding="utf-8")
    wf._validate("x/y", event)

def test_validate_requires_srs_index(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    wf.STATE_PATH = Path(".codex/state.json")
    wf._write_state({"current_stage":"implementation","locked":[],"history":[]})
    event = _write_event(tmp_path, ["stage:testing"])
    with pytest.raises(SystemExit):
        wf._validate("x/y", event)
    (Path("docs/srs")).mkdir(parents=True)
    (Path("docs/srs")/"index.yaml").write_text("", encoding="utf-8")
    wf._validate("x/y", event)

def test_validate_rejects_unknown_stage(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    wf.STATE_PATH = Path(".codex/state.json")
    wf._write_state({"current_stage":"requirements","locked":[],"history":[]})
    event = _write_event(tmp_path, ["stage:unknown"])
    with pytest.raises(SystemExit):
        wf._validate("x/y", event)

def test_artifact_check_warns_and_exits_zero(tmp_path, capsys, monkeypatch):
    monkeypatch.chdir(tmp_path)
    event = _write_event(tmp_path, ["stage:deployment"])
    monkeypatch.setattr(wa, "gh_json", lambda *a: {"artifacts":[{"name":"other"}]})
    rc = wa.ensure(event, "x/y")
    out = capsys.readouterr().out.lower()
    assert "warning" in out
    assert rc == 0

def test_artifact_check_noop_when_not_deployment(tmp_path, capsys):
    event = _write_event(tmp_path, ["stage:testing"])
    rc = wa.ensure(event, "x/y")
    out = capsys.readouterr().out
    assert out == ""
    assert rc == 0

def test_artifact_check_passes_when_artifact_present(tmp_path, capsys, monkeypatch):
    event = _write_event(tmp_path, ["stage:deployment"])
    monkeypatch.setattr(wa, "gh_json", lambda *a: {"artifacts":[{"name":"water-stage2-artifacts"}]})
    rc = wa.ensure(event, "x/y")
    out = capsys.readouterr().out
    assert rc == 0
    assert out == ""


