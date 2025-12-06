import importlib.util
import json
import sys
from pathlib import Path

from contextlib import contextmanager

from tests.TestUtil.run import run


@contextmanager
def temporary_spec(content: str, name: str = "tmp_spec.md"):
    srs_dir = Path(__file__).resolve().parent.parent / "docs" / "srs"
    tmp = srs_dir / name
    tmp.touch(exist_ok=True)
    tmp.write_text(content, encoding="utf-8")
    try:
        yield
    finally:
        if tmp.exists():
            tmp.unlink()
        assert not tmp.exists()

def run_check(msg: str) -> int:
    tmp = Path(__file__).with_name('tmp_msg.txt')
    tmp.write_text(msg, encoding="utf-8")
    script = Path(__file__).resolve().parent.parent / 'scripts' / 'check-commit-msg.py'
    proc = run([sys.executable, str(script), str(tmp)], check=False)
    try:
        tmp.unlink(missing_ok=True)
    except Exception:
        pass
    return proc.returncode


def run_check_with_output(msg: str):
    tmp = Path(__file__).with_name('tmp_msg.txt')
    tmp.write_text(msg, encoding="utf-8")
    script = Path(__file__).resolve().parent.parent / 'scripts' / 'check-commit-msg.py'
    proc = run([sys.executable, str(script), str(tmp)], check=False)
    try:
        tmp.unlink(missing_ok=True)
    except Exception:
        pass
    return proc


def run_check_with_result(msg: str):
    tmp = Path(__file__).with_name('tmp_msg.txt')
    tmp.write_text(msg, encoding="utf-8")
    script = Path(__file__).resolve().parent.parent / 'scripts' / 'check-commit-msg.py'
    proc = run([sys.executable, str(script), str(tmp)], check=False)
    text = tmp.read_text()
    try:
        tmp.unlink(missing_ok=True)
    except Exception:
        pass
    return proc.returncode, text


def run_check_from_scripts(msg: str):
    tmp = Path(__file__).resolve().with_name('tmp_msg.txt')
    tmp.write_text(msg, encoding="utf-8")
    repo_root = Path(__file__).resolve().parent.parent
    script = repo_root / 'scripts' / 'check-commit-msg.py'
    proc = run(
        [sys.executable, str(script), str(tmp)],
        check=False,
        cwd=repo_root / 'scripts',
    )
    try:
        tmp.unlink(missing_ok=True)
    except Exception:
        pass
    return proc

def test_valid_message():
    assert run_check('Valid\n\ncodex: impl | SRS: FGC-REQ-DEV-005 | issue: #123\n') == 0

def test_invalid_message():
    assert run_check('Bad message\nNoBlank\nmeta\n') != 0


def test_unknown_id_fails():
    assert run_check('Valid\n\ncodex: impl | SRS: FGC-REQ-XYZ-999\n') != 0


def test_test_req_ids_rejected():
    proc = run_check_with_output('Valid\n\ncodex: impl | SRS: TEST-REQ-XYZ-999\n')
    assert proc.returncode != 0
    assert 'third line must match' in proc.stderr


def test_issue_reference_allowed():
    assert run_check('Valid\n\ncodex: impl | SRS: FGC-REQ-DEV-005 | issue: #42\n') == 0


def test_missing_srs_id_fails():
    assert run_check('Valid\n\ncodex: impl | SRS:\n') != 0


def test_nonbreaking_hyphen_valid():
    nb = '\u2011'
    msg = f'Valid\n\ncodex: impl | SRS: FGC{nb}REQ{nb}DEV{nb}005 | issue: #1\n'
    assert run_check(msg) == 0


def test_nonbreaking_hyphen_unknown_normalized_output():
    nb = '\u2011'
    msg = f'Valid\n\ncodex: impl | SRS: FGC{nb}REQ{nb}XYZ{nb}999 | issue: #1\n'
    proc = run_check_with_output(msg)
    assert proc.returncode != 0
    assert 'FGC-REQ-XYZ-999' in proc.stderr


def test_duplicate_id_auto_versioned():
    with temporary_spec('Version: 2.0\n\nFGC-REQ-NOT-001\n', name='tmp_spec_commit_msg.md'):
        code, text = run_check_with_result('Valid\n\ncodex: impl | SRS: FGC-REQ-NOT-001 | issue: #1\n')
        assert code == 0
        assert 'FGC-REQ-NOT-001@2.0' in text


def test_version_disambiguates_duplicate():
    with temporary_spec('Version: 2.0\n\nFGC-REQ-NOT-001\n', name='tmp_spec_commit_msg.md'):
        assert run_check('Valid\n\ncodex: impl | SRS: FGC-REQ-NOT-001@1.0 | issue: #1\n') == 0


def test_duplicate_id_with_version_selects_new_spec():
    with temporary_spec('Version: 2.0\n\nFGC-REQ-NOT-001\n', name='tmp_spec_commit_msg.md'):
        assert run_check('Valid\n\ncodex: impl | SRS: FGC-REQ-NOT-001@2.0 | issue: #1\n') == 0


def test_duplicate_id_with_wrong_version_fails():
    with temporary_spec('Version: 2.0\n\nFGC-REQ-NOT-001\n', name='tmp_spec_commit_msg.md'):
        assert run_check('Valid\n\ncodex: impl | SRS: FGC-REQ-NOT-001@3.0 | issue: #1\n') != 0


def test_multiple_ids_with_versions():
    assert (
        run_check(
            'Valid\n\ncodex: impl | SRS: FGC-REQ-NOT-001@1.0, FGC-REQ-SPEC-001@1.0 | issue: #1\n'
        )
        == 0
    )


def test_template_regex_allows_versioned_ids():
    repo_root = Path(__file__).resolve().parent.parent
    spec = importlib.util.spec_from_file_location(
        'check_commit_msg', repo_root / 'scripts' / 'check-commit-msg.py'
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    template = mod._load_template(repo_root)
    pattern = mod._pattern_from_template(template)
    line = 'codex: impl | SRS: FGC-REQ-NOT-001@1.0, FGC-REQ-SPEC-001@1.0 | issue: #1'
    assert pattern.match(line)


def test_short_message_records_telemetry(restore_repo_telemetry):
    repo_root = Path(__file__).resolve().parent.parent
    telemetry = repo_root / '.codex' / 'telemetry.json'
    assert run_check('Summary only\n') != 0
    data = json.loads(telemetry.read_text(encoding='utf-8'))
    entry = data['entries'][-1]
    assert entry['source'] == 'commit-msg'
    assert entry['failure_reason'] == 'commit message must have at least three lines'
    assert entry['srs_ids'] == []
    assert entry['modules_inspected'] == []


def test_summary_too_long_records_telemetry(restore_repo_telemetry):
    repo_root = Path(__file__).resolve().parent.parent
    telemetry = repo_root / '.codex' / 'telemetry.json'
    msg = 'x' * 51 + '\n\ncodex: impl | SRS: FGC-REQ-NOT-001\n'
    assert run_check(msg) != 0
    data = json.loads(telemetry.read_text(encoding='utf-8'))
    entry = data['entries'][-1]
    assert entry['source'] == 'commit-msg'
    assert entry['failure_reason'] == 'summary line must be 1-50 characters'
    assert entry['srs_ids'] == []
    assert entry['modules_inspected'] == []


def test_second_line_not_blank_records_telemetry(restore_repo_telemetry):
    repo_root = Path(__file__).resolve().parent.parent
    telemetry = repo_root / '.codex' / 'telemetry.json'
    msg = 'Valid\nno-blank\ncodex: impl | SRS: FGC-REQ-NOT-001\n'
    assert run_check(msg) != 0
    data = json.loads(telemetry.read_text(encoding='utf-8'))
    entry = data['entries'][-1]
    assert entry['source'] == 'commit-msg'
    assert entry['failure_reason'] == 'second line must be blank'
    assert entry['srs_ids'] == []
    assert entry['modules_inspected'] == []


def test_unknown_id_records_telemetry(restore_repo_telemetry):
    repo_root = Path(__file__).resolve().parent.parent
    telemetry = repo_root / '.codex' / 'telemetry.json'
    proc = run_check('Valid\n\ncodex: impl | SRS: FGC-REQ-XYZ-999\n')
    assert proc != 0
    data = json.loads(telemetry.read_text(encoding='utf-8'))
    entry = data['entries'][-1]
    assert entry['source'] == 'commit-msg'
    assert entry['srs_ids'] == []
    assert entry['srs_omitted']


def test_malformed_template_records_exception(restore_repo_telemetry):
    repo_root = Path(__file__).resolve().parent.parent
    telemetry = repo_root / '.codex' / 'telemetry.json'
    template_snippet = repo_root / 'commit-template.snippet.md'
    orig = template_snippet.read_text(encoding='utf-8')
    template_snippet.write_text('broken template', encoding='utf-8')
    try:
        proc = run_check('Valid\n\ncodex: impl | SRS: FGC-REQ-NOT-001\n')
        assert proc != 0
        data = json.loads(telemetry.read_text(encoding='utf-8'))
        entry = data['entries'][-1]
        assert entry['source'] == 'commit-msg'
        assert entry['exception_type'] == 'RuntimeError'
        assert 'template' in entry['exception_message'].lower()
    finally:
        template_snippet.write_text(orig, encoding='utf-8')


def test_missing_message_file_records_exception(restore_repo_telemetry):
    repo_root = Path(__file__).resolve().parent.parent
    telemetry = repo_root / '.codex' / 'telemetry.json'
    script = repo_root / 'scripts' / 'check-commit-msg.py'
    proc = run([sys.executable, str(script), 'nope.txt'], check=False)
    assert proc.returncode != 0
    data = json.loads(telemetry.read_text(encoding='utf-8'))
    entry = data['entries'][-1]
    assert entry['source'] == 'commit-msg'
    assert entry['exception_type'] == 'FileNotFoundError'
