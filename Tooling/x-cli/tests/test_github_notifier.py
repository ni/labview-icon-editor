import json
import urllib.request
import time

from notifications.github_notifier import GitHubNotifier


def test_github_notifier_posts_comment(monkeypatch):
    captured = {}

    class DummyResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self):
            return b""

        def getcode(self):
            return 201

    def fake_urlopen(req, timeout=0):
        captured["url"] = req.full_url
        captured["headers"] = {k: v for k, v in req.headers.items()}
        captured["data"] = req.data
        captured["timeout"] = timeout
        return DummyResponse()

    monkeypatch.setenv("GITHUB_REPO", "octo/repo")
    monkeypatch.setenv("GITHUB_ISSUE", "5")
    monkeypatch.setenv("ADMIN_TOKEN", "t0k3n")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)

    notifier = GitHubNotifier()
    result = notifier.send_alert("hello")

    assert result is True
    assert captured["url"] == "https://api.github.com/repos/octo/repo/issues/5/comments"
    assert captured["headers"]["Authorization"] == "token t0k3n"
    assert json.loads(captured["data"].decode()) == {"body": "hello"}
    assert captured["timeout"] == 5


def test_github_notifier_missing_config(monkeypatch, capsys):
    monkeypatch.delenv("GITHUB_REPO", raising=False)
    monkeypatch.delenv("GITHUB_ISSUE", raising=False)
    monkeypatch.delenv("ADMIN_TOKEN", raising=False)
    monkeypatch.delenv("GITHUB_TOKEN", raising=False)

    notifier = GitHubNotifier()
    assert notifier.send_alert("hi") is False
    err = capsys.readouterr().err
    assert "configuration incomplete" in err

    # second call should not emit the warning again
    notifier.send_alert("again")
    err2 = capsys.readouterr().err
    assert err2 == ""


def test_github_notifier_retries_once_on_failure(monkeypatch):
    calls = {"count": 0}

    class DummyResponse:
        def __init__(self, code):
            self._code = code

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def read(self):
            return b""

        def getcode(self):
            return self._code

    def fake_urlopen(req, timeout=0):
        calls["count"] += 1
        if calls["count"] == 1:
            return DummyResponse(500)
        return DummyResponse(201)

    monkeypatch.setenv("GITHUB_REPO", "octo/repo")
    monkeypatch.setenv("GITHUB_ISSUE", "5")
    monkeypatch.setenv("ADMIN_TOKEN", "t0k3n")
    monkeypatch.delenv("NOTIFICATIONS_DRY_RUN", raising=False)
    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    monkeypatch.setattr(time, "sleep", lambda s: None)

    notifier = GitHubNotifier()
    result = notifier.send_alert("retry")

    assert result is True
    assert calls["count"] == 2


def test_dry_run_logs_payload(monkeypatch, capsys):
    monkeypatch.setenv("GITHUB_REPO", "octo/repo")
    monkeypatch.setenv("GITHUB_ISSUE", "5")
    monkeypatch.setenv("ADMIN_TOKEN", "t0k3n")
    monkeypatch.setenv("NOTIFICATIONS_DRY_RUN", "1")
    notifier = GitHubNotifier()
    notifier.send_alert("hi", {"dashboard_url": "http://dash"})
    out = capsys.readouterr().out.strip()
    prefix, payload = out.split(": ", 1)
    assert prefix == "DRYRUN github"
    data = json.loads(payload)
    assert data["body"].endswith("Dashboard: http://dash")
