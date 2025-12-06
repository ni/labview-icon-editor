"""Tests for codex_rules.memory path resolution."""

from pathlib import Path
import unittest

from codex_rules import memory


class MemoryPathTests(unittest.TestCase):
    def test_memory_path_uses_repo_root(self) -> None:
        repo_root = Path(__file__).resolve().parent.parent
        self.assertEqual(memory.REPO_ROOT, repo_root)
        self.assertEqual(
            memory.MEMORY_PATH, repo_root / ".codex" / "memory.json"
        )


if __name__ == "__main__":
    unittest.main()

