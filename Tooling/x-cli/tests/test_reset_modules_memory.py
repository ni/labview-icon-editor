from pathlib import Path

import pytest


@pytest.mark.usefixtures("reset_modules")
def test_memory_state_can_be_mutated(tmp_path):
    """Modify codex_rules.memory globals and write a file."""
    from codex_rules import memory

    memory.REPO_ROOT = tmp_path
    memory.MEMORY_PATH = tmp_path / "memory.json"
    memory.append_entry({"summary": "first"})
    assert memory.MEMORY_PATH.exists()


@pytest.mark.usefixtures("reset_modules")
def test_memory_state_isolated_between_tests():
    """Default module state should be restored between tests."""
    from codex_rules import memory

    repo_root = Path(__file__).resolve().parents[1]
    assert memory.REPO_ROOT == repo_root
    assert memory.MEMORY_PATH == repo_root / ".codex" / "memory.json"
