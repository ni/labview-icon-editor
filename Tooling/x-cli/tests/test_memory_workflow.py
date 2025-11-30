import argparse
import importlib
import io
import json
import os
import subprocess
from contextlib import redirect_stderr
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

import pytest

from codex_rules import cli, memory
from codex_rules.storage import InMemoryStorage

from tests.TestUtil.run import run, check_output


class MemoryWorkflowTests(unittest.TestCase):
    @pytest.mark.external_dep("git")
    def test_memory_summary_and_append_stage_file(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
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

            orig_cwd = os.getcwd()
            os.chdir(repo)
            try:
                importlib.reload(memory)
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
                        "--memory-summary",
                        "first",
                    ],
                    storage_cls=InMemoryStorage,
                )
            finally:
                os.chdir(orig_cwd)

            mem_file = repo / ".codex" / "memory.json"
            self.assertTrue(mem_file.exists())
            status = check_output(["git", "status", "--short"], cwd=repo)
            self.assertIn(".codex/memory.json", status)

            run(["git", "commit", "-am", "add memory"], cwd=repo)

            orig_cwd = os.getcwd()
            os.chdir(repo)
            try:
                importlib.reload(memory)
                importlib.reload(cli)
                cli.main(
                    ["memory", "append", "--summary", "second"],
                    storage_cls=InMemoryStorage,
                )
            finally:
                os.chdir(orig_cwd)

            status2 = check_output(["git", "status", "--short"], cwd=repo)
            self.assertIn(".codex/memory.json", status2)

            data = json.loads(mem_file.read_text())
            self.assertEqual(len(data.get("entries", [])), 2)

            orig_cwd = os.getcwd()
            os.chdir(repo_root)
            importlib.reload(memory)
            importlib.reload(cli)
            os.chdir(orig_cwd)

    def test_memory_append_exit_code_on_stage_failure(self) -> None:
        # When staging the memory file fails, the command should exit non-zero.
        args = argparse.Namespace(summary="no git", author=None)
        with patch(
            "codex_rules.cli.subprocess.run",
            side_effect=subprocess.CalledProcessError(1, ["git"]),
        ):
            with self.assertRaises(SystemExit) as cm:
                cli.memory_append(args, {})
            self.assertNotEqual(cm.exception.code, 0)

    def test_memory_append_exit_code_on_append_failure(self) -> None:
        # When writing memory fails, the command should exit with the underlying code.
        import errno

        args = argparse.Namespace(summary="oops", author=None)
        with patch("codex_rules.memory.append_entry", side_effect=OSError(errno.EIO, "io")):
            with self.assertRaises(SystemExit) as cm:
                cli.memory_append(args, {})
            self.assertEqual(cm.exception.code, errno.EIO)

    def test_memory_append_error_message_on_append_failure(self) -> None:
        """CLI should report errors when memory cannot be written."""
        import errno

        args = argparse.Namespace(summary="deny", author=None)
        buf = io.StringIO()
        with patch(
            "codex_rules.memory.append_entry",
            side_effect=PermissionError(errno.EACCES, "denied"),
        ), redirect_stderr(buf):
            with self.assertRaises(SystemExit) as cm:
                cli.memory_append(args, {})
        self.assertNotEqual(cm.exception.code, 0)
        msg = buf.getvalue()
        self.assertIn("failed to write .codex/memory.json", msg)
        self.assertIn("denied", msg)

    def test_memory_append_from_subdir_stages_file(self) -> None:
        # Running the CLI from a nested directory should still stage memory.
        repo_root = Path(__file__).resolve().parents[1]
        with TemporaryDirectory() as tmpdir:
            repo = Path(tmpdir)
            run(["git", "init"], cwd=repo)
            run(["git", "config", "user.email", "test@example.com"], cwd=repo)
            run(["git", "config", "user.name", "Test"], cwd=repo)

            (repo / "README.md").write_text("init")
            run(["git", "add", "README.md"], cwd=repo)
            run(["git", "commit", "-m", "init"], cwd=repo)

            subdir = repo / "sub"
            subdir.mkdir()
            orig_cwd = os.getcwd()
            os.chdir(subdir)
            try:
                importlib.reload(memory)
                importlib.reload(cli)
                cli.main(
                    ["memory", "append", "--summary", "from subdir"],
                    storage_cls=InMemoryStorage,
                )
            finally:
                os.chdir(orig_cwd)

            mem_file = repo / ".codex" / "memory.json"
            self.assertTrue(mem_file.exists())
            status = check_output(["git", "status", "--short"], cwd=repo)
            self.assertIn(".codex/memory.json", status)

            orig_cwd = os.getcwd()
            os.chdir(repo_root)
            importlib.reload(memory)
            importlib.reload(cli)
            os.chdir(orig_cwd)


if __name__ == "__main__":
    unittest.main()
