import json
import urllib.request
from pathlib import Path


def test_hydrate_metadata_from_issue(tmp_path, monkeypatch):
    meta_dir = tmp_path / ".codex"
    meta_dir.mkdir()

    issue_body = (
        "### Summary\n"
        "Do the thing.\n\n"
        "### SRS IDs\n"
        "FGC-REQ-CLI-001\nFGC-REQ-LOG-002\n"
    )
    issue_json = {
        "body": issue_body,
        "labels": [{"name": "impl"}],
    }

    class DummyResp:
        def __init__(self, data):
            self._data = data

        def read(self):
            return json.dumps(self._data).encode("utf-8")

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_urlopen(req, timeout=10):
        return DummyResp(issue_json)

    monkeypatch.setenv("GITHUB_REPOSITORY", "owner/repo")
    monkeypatch.setenv("REPO_ROOT", str(tmp_path))
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    from scripts import hydrate_metadata_from_issue as h

    assert h.main(["hydrate_metadata_from_issue.py", "42"]) == 0

    meta = json.loads((meta_dir / "metadata.json").read_text())
    assert meta == {
        "summary": "Do the thing.",
        "change_type": "impl",
        "srs_ids": ["FGC-REQ-CLI-001", "FGC-REQ-LOG-002"],
        "issue": 42,
    }
