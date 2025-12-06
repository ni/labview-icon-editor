import os
from pathlib import Path
import pytest
import re
from tests.TestUtil.run import run
import sys


@pytest.mark.skip(reason="flaky under parallel execution")
def test_parallel_roots(tmp_path):
    """Ensure parallel test processes use distinct repo roots."""
    mod = tmp_path / "probe_mod.py"
    mod.write_text(
        """
import os
from pathlib import Path

def test_one():
    root = os.environ['FAKEG_REPO_ROOT']
    print(root)
    (Path(root) / 'docs' / 'parallel_probe.txt').write_text('one', encoding='utf-8')

def test_two():
    root = os.environ['FAKEG_REPO_ROOT']
    print(root)
    (Path(root) / 'docs' / 'parallel_probe.txt').write_text('two', encoding='utf-8')
""",
        encoding="utf-8",
    )

    printer = tmp_path / "printer.py"
    printer.write_text(
        """
import os, sys

def pytest_runtest_logreport(report):
    if os.environ.get('PYTEST_XDIST_WORKER'):
        return
    if report.when == 'call':
        sys.stdout.write(report.capstdout)
""",
        encoding="utf-8",
    )

    repo_root = Path(__file__).resolve().parents[1]
    env = os.environ.copy()
    env.pop("FAKEG_REPO_ROOT", None)
    env["PYTHONPATH"] = (
        str(repo_root)
        + os.pathsep
        + str(tmp_path)
        + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
    )
    # ensure subprocess uses project virtual environment for pytest-xdist
    env["PATH"] = str(repo_root / ".venv" / "bin") + os.pathsep + env.get("PATH", "")

    result = run(
        [
            "pytest",
            "-q",
            "-n",
            "2",
            str(mod),
            "-p",
            "tests.conftest",
            "-p",
            "printer",
        ],
        cwd=tmp_path,
        env=env,
    )

    ansi = re.compile(r"\x1b\[[0-9;]*m")
    roots = []
    for line in result.stdout.splitlines():
        clean = ansi.sub("", line).strip()
        if Path(clean).is_absolute():
            roots.append(clean)

    assert len(roots) == 2
    assert len(set(roots)) == 2

    marker_name = "parallel_probe.txt"
    for root in roots:
        assert (Path(root) / "docs" / marker_name).exists()

    assert not (repo_root / "docs" / marker_name).exists()

