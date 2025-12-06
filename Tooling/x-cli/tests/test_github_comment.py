"""GitHub comment script integration (FGC-REQ-NOT-001)."""

import json
import sys
import urllib.request
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from github_comment import post_github_comment
def _stub_urlopen(expected, status=201):
    def _urlopen(req, timeout=5):
        expected["req"] = req
        class Resp:
            def __enter__(self):
                return self
            def __exit__(self, *exc):
                return False
            def read(self):
                return b""
            def getcode(self):
                return status
        return Resp()
    return _urlopen


def test_post_github_comment(monkeypatch):
    captured = {}
    monkeypatch.setenv("ADMIN_TOKEN", "t0k3n")
    monkeypatch.setattr(urllib.request, "urlopen", _stub_urlopen(captured))
    post_github_comment("octo/repo", 5, "hello")
    req = captured["req"]
    assert req.full_url == "https://api.github.com/repos/octo/repo/issues/5/comments"
    assert req.headers["Authorization"] == "token t0k3n"
    assert json.loads(req.data.decode()) == {"body": "hello"}


def test_post_github_comment_no_token(monkeypatch):
    monkeypatch.delenv("ADMIN_TOKEN", raising=False)
    monkeypatch.delenv("GITHUB_TOKEN", raising=False)
    with pytest.raises(ValueError):
        post_github_comment("octo/repo", 5, "hi")


def test_post_github_comment_http_error(monkeypatch):
    monkeypatch.setenv("ADMIN_TOKEN", "t0k3n")
    monkeypatch.setattr(
        urllib.request, "urlopen", _stub_urlopen({}, status=500)
    )
    with pytest.raises(RuntimeError):
        post_github_comment("octo/repo", 5, "oops")

