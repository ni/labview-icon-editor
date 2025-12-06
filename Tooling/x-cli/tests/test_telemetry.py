import importlib
"""Telemetry system integration tests (FGC-REQ-TEL-001)."""

import argparse
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

import pytest

from codex_rules import cli
from codex_rules.storage import InMemoryStorage
from codex_rules.telemetry import append_telemetry_entry

from tests.TestUtil.run import run


def test_all_subcommands_require_record_when_agent_feedback(tmp_path_factory) -> None:
    """Ensure subcommands with telemetry support expose agent feedback."""

    def capture(self, *args, **kwargs):
        raise RuntimeError(self)

    with pytest.raises(RuntimeError) as excinfo:
        with mock.patch("argparse.ArgumentParser.parse_args", capture):
            cli.main([])

    parser = excinfo.value.args[0]
    subparsers = parser._subparsers._group_actions[0].choices
    for name, sub in subparsers.items():
        opts = {opt for a in sub._actions for opt in a.option_strings}
        if "--record-telemetry" in opts:
            assert "--agent-feedback" in opts
            assert "--srs-id" in opts
            tmpdir = tmp_path_factory.mktemp(name.replace("/", "_"))
            cwd = os.getcwd()
            os.chdir(tmpdir)
            try:
                argv = [name]
                if name == "emit-warnings":
                    argv += ["--pr", "1", "--agent-feedback", "x"]
                elif name == "run-workflow":
                    argv += ["--results-path", "r", "--agent-feedback", "x"]
                else:
                    argv += ["--agent-feedback", "x"]
                with pytest.raises(SystemExit) as cm:
                    cli.main(argv, storage_cls=InMemoryStorage)
                assert cm.value.code == 2
            finally:
                os.chdir(cwd)


class TelemetryTests(unittest.TestCase):
    @pytest.mark.external_dep("git")
    def test_run_workflow_records_ci_logs_and_tests(self) -> None:
        with TemporaryDirectory() as tmpdir:
            repo = Path(tmpdir)
            run(["git", "init"], cwd=repo)
            run(["git", "config", "user.email", "test@example.com"], cwd=repo)
            run(["git", "config", "user.name", "Test"], cwd=repo)

            (repo / "README.md").write_text("init")
            run(["git", "add", "README.md"], cwd=repo)
            run(["git", "commit", "-m", "init"], cwd=repo)

            (repo / "files.json").write_text("[]")
            (repo / "results.xml").write_text("<testsuite></testsuite>")

            orig = os.getcwd()
            feedback = "nice"
            os.chdir(repo)
            try:
                importlib.reload(cli)
                cli.main(
                    [
                        "run-workflow",
                        "--pr",
                        "1",
                        "--files-json",
                        "files.json",
                        "--results-path",
                        "results.xml",
                        "--record-telemetry",
                        "--agent-feedback",
                        feedback,
                        "--srs-id",
                        "FGC-REQ-TEL-001",
                        "--ci-log-path",
                        "ci.log",
                        "--ci-log-path",
                        "other.log",
                        "--failing-test",
                        "tests.A::B",
                        "--failing-test",
                        "tests.C::D",
                    ],
                    storage_cls=InMemoryStorage,
                )
            finally:
                os.chdir(orig)

            data = json.loads((repo / ".codex" / "telemetry.json").read_text())
            entry = data["entries"][-1]
            self.assertEqual(entry["ci_log_paths"], ["ci.log", "other.log"])
            self.assertEqual(entry["failing_tests"], ["tests.A::B", "tests.C::D"])
            self.assertEqual(entry["agent_feedback"], feedback)
            self.assertEqual(entry["srs_ids"], ["FGC-REQ-TEL-001"])
            self.assertFalse(entry["srs_omitted"])

    @pytest.mark.external_dep("git")
    def test_run_workflow_records_srs_omission(self) -> None:
        """run-workflow without SRS IDs records omission."""
        with TemporaryDirectory() as tmpdir:
            repo = Path(tmpdir)
            run(["git", "init"], cwd=repo)
            run(["git", "config", "user.email", "test@example.com"], cwd=repo)
            run(["git", "config", "user.name", "Test"], cwd=repo)

            (repo / "README.md").write_text("init")
            run(["git", "add", "README.md"], cwd=repo)
            run(["git", "commit", "-m", "init"], cwd=repo)

            (repo / "files.json").write_text("[]")
            (repo / "results.xml").write_text("<testsuite></testsuite>")

            orig = os.getcwd()
            os.chdir(repo)
            try:
                importlib.reload(cli)
                cli.main(
                    [
                        "run-workflow",
                        "--pr",
                        "1",
                        "--files-json",
                        "files.json",
                        "--results-path",
                        "results.xml",
                        "--record-telemetry",
                    ],
                    storage_cls=InMemoryStorage,
                )
            finally:
                os.chdir(orig)

            data = json.loads((repo / ".codex" / "telemetry.json").read_text())
            entry = data["entries"][-1]
            self.assertEqual(entry["srs_ids"], [])
            self.assertTrue(entry["srs_omitted"])

    def test_append_telemetry_entry_records_agent_feedback(self) -> None:
        with TemporaryDirectory() as tmpdir:
            orig = os.getcwd()
            os.chdir(tmpdir)
            try:
                append_telemetry_entry(
                    {"modules_inspected": [], "checks_skipped": []},
                    agent_feedback="great",
                )
            finally:
                os.chdir(orig)

            data = json.loads((Path(tmpdir) / ".codex" / "telemetry.json").read_text())
            entry = data["entries"][-1]
            self.assertEqual(entry["agent_feedback"], "great")
            self.assertEqual(entry["srs_ids"], [])
            self.assertTrue(entry["srs_omitted"])

    def test_append_telemetry_entry_records_exception(self) -> None:
        with TemporaryDirectory() as tmpdir:
            orig = os.getcwd()
            os.chdir(tmpdir)
            try:
                append_telemetry_entry(
                    {"modules_inspected": [], "checks_skipped": []},
                    exception_type="ValueError",
                    exception_message="boom",
                )
            finally:
                os.chdir(orig)

            data = json.loads((Path(tmpdir) / ".codex" / "telemetry.json").read_text())
            entry = data["entries"][-1]
            self.assertEqual(entry["exception_type"], "ValueError")
            self.assertEqual(entry["exception_message"], "boom")
            self.assertEqual(entry["srs_ids"], [])
            self.assertTrue(entry["srs_omitted"])

    def test_append_telemetry_entry_records_srs_ids(self) -> None:
        with TemporaryDirectory() as tmpdir:
            orig = os.getcwd()
            os.chdir(tmpdir)
            try:
                append_telemetry_entry(
                    {"modules_inspected": [], "checks_skipped": []},
                    srs_ids=["FGC-REQ-TEL-001"],
                )
            finally:
                os.chdir(orig)

            data = json.loads((Path(tmpdir) / ".codex" / "telemetry.json").read_text())
            entry = data["entries"][-1]
            self.assertEqual(entry["srs_ids"], ["FGC-REQ-TEL-001"])
            self.assertFalse(entry["srs_omitted"])

    def test_append_telemetry_entry_records_command_context(self) -> None:
        with TemporaryDirectory() as tmpdir:
            orig = os.getcwd()
            os.chdir(tmpdir)
            try:
                append_telemetry_entry(
                    {"modules_inspected": [], "checks_skipped": []},
                    command=["ls", "-l"],
                    exit_status=1,
                )
            finally:
                os.chdir(orig)

            data = json.loads((Path(tmpdir) / ".codex" / "telemetry.json").read_text())
            entry = data["entries"][-1]
            self.assertEqual(entry["command"], ["ls", "-l"])
            self.assertEqual(entry["exit_status"], 1)

    @pytest.mark.external_dep("git")
    def test_emit_warnings_records_agent_feedback(self) -> None:
        with TemporaryDirectory() as tmpdir:
            repo = Path(tmpdir)
            run(["git", "init"], cwd=repo)
            run(["git", "config", "user.email", "test@example.com"], cwd=repo)
            run(["git", "config", "user.name", "Test"], cwd=repo)

            (repo / "README.md").write_text("init")
            run(["git", "add", "README.md"], cwd=repo)
            run(["git", "commit", "-m", "init"], cwd=repo)

            storage = InMemoryStorage()
            storage.record_pr(pr_id=1, branch="", base="", labels=[], files=[])

            orig = os.getcwd()
            os.chdir(repo)
            try:
                importlib.reload(cli)
                cli.main(
                    [
                        "emit-warnings",
                        "--pr",
                        "1",
                        "--record-telemetry",
                        "--agent-feedback",
                        "hello",
                    ],
                    storage=storage,
                )
            finally:
                os.chdir(orig)

            data = json.loads((repo / ".codex" / "telemetry.json").read_text())
            entry = data["entries"][-1]
            self.assertEqual(entry["agent_feedback"], "hello")
            self.assertEqual(entry["srs_ids"], [])
            self.assertTrue(entry["srs_omitted"])

    @pytest.mark.external_dep("git")
    def test_emit_warnings_records_srs_ids(self) -> None:
        """emit-warnings records provided SRS identifiers."""
        with TemporaryDirectory() as tmpdir:
            repo = Path(tmpdir)
            run(["git", "init"], cwd=repo)
            run(["git", "config", "user.email", "test@example.com"], cwd=repo)
            run(["git", "config", "user.name", "Test"], cwd=repo)

            (repo / "README.md").write_text("init")
            run(["git", "add", "README.md"], cwd=repo)
            run(["git", "commit", "-m", "init"], cwd=repo)

            storage = InMemoryStorage()
            storage.record_pr(pr_id=1, branch="", base="", labels=[], files=[])

            orig = os.getcwd()
            os.chdir(repo)
            try:
                importlib.reload(cli)
                cli.main(
                    [
                        "emit-warnings",
                        "--pr",
                        "1",
                        "--record-telemetry",
                        "--srs-id",
                        "FGC-REQ-TEL-001",
                    ],
                    storage=storage,
                )
            finally:
                os.chdir(orig)

            data = json.loads((repo / ".codex" / "telemetry.json").read_text())
            entry = data["entries"][-1]
            self.assertEqual(entry["srs_ids"], ["FGC-REQ-TEL-001"])
            self.assertFalse(entry["srs_omitted"])

    @pytest.mark.external_dep("git")
    def test_emit_warnings_agent_feedback_requires_record(self) -> None:
        with TemporaryDirectory() as tmpdir:
            repo = Path(tmpdir)
            run(["git", "init"], cwd=repo)
            run(["git", "config", "user.email", "test@example.com"], cwd=repo)
            run(["git", "config", "user.name", "Test"], cwd=repo)

            (repo / "README.md").write_text("init")
            run(["git", "add", "README.md"], cwd=repo)
            run(["git", "commit", "-m", "init"], cwd=repo)

            storage = InMemoryStorage()
            storage.record_pr(pr_id=1, branch="", base="", labels=[], files=[])

            orig = os.getcwd()
            os.chdir(repo)
            try:
                importlib.reload(cli)
                with self.assertRaises(SystemExit) as cm:
                    cli.main(
                        [
                            "emit-warnings",
                            "--pr",
                            "1",
                            "--agent-feedback",
                            "oops",
                        ],
                        storage=storage,
                    )
                self.assertEqual(cm.exception.code, 2)
            finally:
                os.chdir(orig)

    @pytest.mark.external_dep("git")
    def test_run_workflow_agent_feedback_requires_record(self) -> None:
        with TemporaryDirectory() as tmpdir:
            repo = Path(tmpdir)
            run(["git", "init"], cwd=repo)
            run(["git", "config", "user.email", "test@example.com"], cwd=repo)
            run(["git", "config", "user.name", "Test"], cwd=repo)

            (repo / "README.md").write_text("init")
            run(["git", "add", "README.md"], cwd=repo)
            run(["git", "commit", "-m", "init"], cwd=repo)

            (repo / "files.json").write_text("[]")
            (repo / "results.xml").write_text("<testsuite></testsuite>")

            orig = os.getcwd()
            os.chdir(repo)
            try:
                importlib.reload(cli)
                with self.assertRaises(SystemExit) as cm:
                    cli.main(
                        [
                            "run-workflow",
                            "--pr",
                            "1",
                            "--files-json",
                            "files.json",
                            "--results-path",
                            "results.xml",
                            "--agent-feedback",
                            "oops",
                        ],
                        storage_cls=InMemoryStorage,
                    )
                self.assertEqual(cm.exception.code, 2)
            finally:
                os.chdir(orig)


def test_run_slow_records_hang_telemetry(tmp_path):
    cmd = [sys.executable, "-c", "import time; time.sleep(0.2)"]
    orig = os.getcwd()
    os.chdir(tmp_path)
    env = {"PATH": os.environ.get("PATH", ""), "FOO": "BAR", "SECRET": "hide"}
    try:
        run(cmd, hang_threshold=0.1, env=env)
    finally:
        os.chdir(orig)
    data = json.loads((tmp_path / ".codex" / "telemetry.json").read_text())
    entry = data["entries"][-1]
    assert entry["event"] == "command_slow"
    assert entry["threshold"] == 0.1
    assert "stack_trace" in entry
    snap = entry["env_snapshot"]
    assert snap["FOO"] == "BAR"
    assert "SECRET" not in snap


def test_run_timeout_records_hang_telemetry(tmp_path):
    cmd = [sys.executable, "-c", "import time; time.sleep(0.2)"]
    orig = os.getcwd()
    os.chdir(tmp_path)
    try:
        with pytest.raises(subprocess.TimeoutExpired):
            run(cmd, timeout=0.05)
    finally:
        os.chdir(orig)
    data = json.loads((tmp_path / ".codex" / "telemetry.json").read_text())
    entry = data["entries"][-1]
    assert entry["event"] == "command_timeout"
    assert entry["timeout"] == 0.05
    assert "stack_trace" in entry
    assert entry["exception_type"] == "TimeoutExpired"
    assert "time.sleep" in entry["exception_message"]
    snap = entry["env_snapshot"]
    assert isinstance(snap, dict)
    assert "PATH" in snap


def test_run_failure_records_exception(tmp_path):
    cmd = [sys.executable, "-c", "import sys; sys.exit(2)"]
    orig = os.getcwd()
    os.chdir(tmp_path)
    try:
        with pytest.raises(subprocess.CalledProcessError):
            run(cmd)
    finally:
        os.chdir(orig)
    data = json.loads((tmp_path / ".codex" / "telemetry.json").read_text())
    entry = data["entries"][-1]
    assert entry["event"] == "command_failed"
    assert entry["exit_status"] == 2
    assert entry["command"] == cmd
    assert entry["exception_type"] == "CalledProcessError"
    assert "returned non-zero exit status" in entry["exception_message"]
    

if __name__ == "__main__":
    unittest.main()

