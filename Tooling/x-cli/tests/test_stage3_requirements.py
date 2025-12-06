from __future__ import annotations

import json
from pathlib import Path
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
import datetime as dt
import os

from tests.TestUtil.run import run

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_manifest_validation_fails_on_missing_artifact(tmp_path: Path) -> None:
    """AGENT-REQ-DEP-001: validation fails when referenced files are absent."""
    tele = tmp_path / "telemetry"
    tele.mkdir()
    manifest = {
        "schema": "pipeline.manifest/v1",
        "artifacts": {
            "win_x64": {"path": "dist/x-cli-win-x64", "sha256": "0" * 64},
            "linux_x64": {"path": "dist/x-cli-linux-x64", "sha256": "1" * 64},
        },
        "telemetry": {
            "summary": {"path": "telemetry/summary.json", "sha256": "2" * 64}
        },
    }
    (tele / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    script = REPO_ROOT / "scripts" / "validate-manifest.sh"
    proc = run(["bash", str(script), "telemetry/manifest.json"], cwd=tmp_path, check=False)
    assert proc.returncode != 0
    assert "path does not exist" in proc.stderr


def test_generate_manifest_includes_sha256(tmp_path: Path) -> None:
    """AGENT-REQ-ART-002: manifest lists SHA-256 for required artifacts."""
    dist = tmp_path / "dist"
    dist.mkdir()
    (dist / "x-cli-win-x64").write_text("win", encoding="utf-8")
    (dist / "x-cli-linux-x64").write_text("lin", encoding="utf-8")
    tele = tmp_path / "telemetry"
    tele.mkdir()
    (tele / "summary.json").write_text("{}", encoding="utf-8")
    script = REPO_ROOT / "scripts" / "generate-manifest.sh"
    env = {"GITHUB_SHA": "deadbeef", "GITHUB_RUN_ID": "1", "GITHUB_WORKFLOW": "ci.yml"}
    run(["bash", str(script)], cwd=tmp_path, env=env)
    manifest = json.loads((tele / "manifest.json").read_text())
    assert len(manifest["artifacts"]["win_x64"]["sha256"]) == 64
    assert len(manifest["artifacts"]["linux_x64"]["sha256"]) == 64
    assert len(manifest["telemetry"]["summary"]["sha256"]) == 64


def test_generate_manifest_requires_summary(tmp_path: Path) -> None:
    """AGENT-REQ-ART-002: manifest generation fails without telemetry summary."""
    dist = tmp_path / "dist"
    dist.mkdir()
    (dist / "x-cli-win-x64").write_text("win", encoding="utf-8")
    (dist / "x-cli-linux-x64").write_text("lin", encoding="utf-8")
    (tmp_path / "telemetry").mkdir()
    script = REPO_ROOT / "scripts" / "generate-manifest.sh"
    proc = run(["bash", str(script)], cwd=tmp_path, check=False)
    assert proc.returncode != 0
    assert "missing telemetry summary" in proc.stderr

class _WebhookHandler(BaseHTTPRequestHandler):
    payloads: list[bytes] = []

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        self.payloads.append(body)
        self.send_response(200)
        self.end_headers()

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        return


def test_telemetry_publish_baseline_and_discord(tmp_path: Path) -> None:
    """AGENT-REQ-TEL-003/AGENT-REQ-NOT-004: diff/baseline + Discord notification."""
    server = HTTPServer(("localhost", 0), _WebhookHandler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        tele = tmp_path / "telemetry"
        history = tele / "history"
        tele.mkdir()
        manifest = tele / "manifest.json"
        manifest.write_text(
            json.dumps(
                {
                    "schema": "pipeline.manifest/v1",
                    "run": {
                        "workflow": "ci.yml",
                        "run_id": "1",
                        "commit": "abc",
                        "ts": "2020-01-01T00:00:00Z",
                    },
                }
            ),
            encoding="utf-8",
        )
        script = REPO_ROOT / "scripts" / "telemetry-publish.py"

        def run_publish(data: dict[str, object]) -> str:
            summary = tele / "summary.json"
            summary.write_text(json.dumps(data), encoding="utf-8")
            result = run(
                [
                    sys.executable,
                    str(script),
                    "-Current",
                    str(summary),
                    "-Discord",
                    f"http://localhost:{port}",
                    "-HistoryDir",
                    str(history),
                    "-Manifest",
                    str(manifest),
                ],
                cwd=tmp_path,
            )
            return result.stdout

        # Baseline run
        run_publish({"pass": 1, "fail": 0, "skipped": 0, "duration_seconds": 1})
        diff1 = json.loads((history / "diff-latest.json").read_text())
        assert diff1["baseline"] is True
        assert (history / "summary-latest.json").exists()
        payload0 = json.loads(_WebhookHandler.payloads[0])
        assert "Baseline established" in payload0["content"]

        # Second run should compute diff
        old_summary = history / "summary-old.json"
        old_summary.write_text("{}", encoding="utf-8")
        old_diff = history / "diff-old.json"
        old_diff.write_text("{}", encoding="utf-8")
        old_ts = (dt.datetime.now(dt.UTC) - dt.timedelta(days=100)).timestamp()
        os.utime(old_summary, (old_ts, old_ts))
        os.utime(old_diff, (old_ts, old_ts))
        run_publish({"pass": 2, "fail": 0, "skipped": 0, "duration_seconds": 1})
        diff2 = json.loads((history / "diff-latest.json").read_text())
        assert diff2["baseline"] is False
        assert len(_WebhookHandler.payloads) == 2
        payload = json.loads(_WebhookHandler.payloads[-1])
        assert "Comparison vs previous" in payload["content"]
        assert "X-CLI CI Summary" in payload["content"]
        assert not old_summary.exists()
        assert not old_diff.exists()
    finally:
        server.shutdown()
