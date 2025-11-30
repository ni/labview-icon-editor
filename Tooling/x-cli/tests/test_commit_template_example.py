from pathlib import Path
from tests.test_check_commit_msg import run_check


def test_commit_template_example_valid():
    repo_root = Path(__file__).resolve().parent.parent
    lines = (repo_root / 'scripts' / 'commit-template.txt').read_text(encoding='utf-8').splitlines()
    idx = lines.index('# Example:')
    summary = lines[idx + 1].lstrip('# ').rstrip()
    meta = lines[idx + 3].lstrip('# ').rstrip()
    msg = f'{summary}\n\n{meta}\n'
    assert run_check(msg) == 0
