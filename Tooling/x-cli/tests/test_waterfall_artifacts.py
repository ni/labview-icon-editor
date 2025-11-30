import json

import scripts.waterfall_artifacts as wa


def test_ensure_no_deployment(tmp_path):
    ev = tmp_path / "event.json"
    ev.write_text(json.dumps({"pull_request": {"labels": [{"name": "stage:testing"}]}}))
    assert wa.ensure(str(ev), "repo") == 0


def test_ensure_warns_on_missing_artifact(tmp_path, monkeypatch, capsys):
    ev = tmp_path / "event.json"
    ev.write_text(json.dumps({"pull_request": {"labels": [{"name": "stage:deployment"}]}}))
    monkeypatch.setattr(wa, "gh_json", lambda *args: {"artifacts": []})
    rc = wa.ensure(str(ev), "repo")
    out = capsys.readouterr().out
    assert "warning" in out.lower()
    assert rc == 0
