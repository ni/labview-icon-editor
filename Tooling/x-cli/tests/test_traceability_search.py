import time
from pathlib import Path
import importlib.util
from tests.TestUtil.run import run

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "generate-traceability.py"
spec = importlib.util.spec_from_file_location("generate_traceability", SCRIPT)
gt = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(gt)
_tests_for = gt._tests_for

REQ = "FGC-REQ-DEV-001"

def test_patterns(tmp_path):
    repo = tmp_path
    tests_dir = repo / "tests"
    tests_dir.mkdir()
    (tests_dir / "keep.txt").write_text(f"{REQ}\n", encoding="utf-8")
    (tests_dir / "skip.txt").write_text(f"{REQ}\n", encoding="utf-8")
    result = _tests_for(repo, REQ, include=["*.txt"], exclude=["skip.*"])
    assert result == ["tests/keep.txt"]


def test_nested_patterns(tmp_path):
    repo = tmp_path
    tests_dir = repo / "tests" / "sub"
    tests_dir.mkdir(parents=True)
    (repo / "tests" / "root.txt").write_text(f"{REQ}\n", encoding="utf-8")
    (tests_dir / "keep.txt").write_text(f"{REQ}\n", encoding="utf-8")
    (tests_dir / "skip.txt").write_text(f"{REQ}\n", encoding="utf-8")
    result = _tests_for(
        repo,
        REQ,
        include=["sub/*.txt"],
        exclude=["*/skip.*"],
    )
    assert result == ["tests/sub/keep.txt"]


def test_missing_tests_dir(tmp_path):
    repo = tmp_path
    assert _tests_for(repo, REQ) == []

def test_ignores_files_without_requirement(tmp_path):
    repo = tmp_path
    tests_dir = repo / "tests"
    tests_dir.mkdir()
    (tests_dir / "match.txt").write_text(f"{REQ}\n", encoding="utf-8")
    (tests_dir / "nomatch.txt").write_text("unrelated\n", encoding="utf-8")
    result = _tests_for(repo, REQ)
    assert result == ["tests/match.txt"]

def test_performance_large(tmp_path):
    repo = tmp_path
    tests_dir = repo / "tests"
    tests_dir.mkdir()
    for i in range(2000):
        (tests_dir / f"t{i}.txt").write_text(f"{REQ}\n", encoding="utf-8")
    start = time.perf_counter()
    result = _tests_for(repo, REQ)
    duration = time.perf_counter() - start
    assert len(result) == 2000
    assert duration < 5.0


def test_performance_nested_exclude(tmp_path):
    repo = tmp_path
    for d in range(40):
        sub = repo / "tests" / f"dir{d}"
        sub.mkdir(parents=True)
        for i in range(50):
            (sub / f"t{i}.txt").write_text(f"{REQ}\n", encoding="utf-8")
        (sub / "skip.txt").write_text(f"{REQ}\n", encoding="utf-8")
    start = time.perf_counter()
    result = _tests_for(repo, REQ, include=["**/*.txt"], exclude=["**/skip.txt"])
    duration = time.perf_counter() - start
    assert len(result) == 40 * 50
    assert duration < 5.0


def test_respects_gitignore(tmp_path):
    repo = tmp_path / "repo"
    tests_dir = repo / "tests"
    tests_dir.mkdir(parents=True)
    (tests_dir / "keep.txt").write_text(f"{REQ}\n", encoding="utf-8")
    (tests_dir / "ignored.txt").write_text(f"{REQ}\n", encoding="utf-8")
    (repo / ".gitignore").write_text("tests/ignored.txt\n", encoding="utf-8")
    run(["git", "init"], cwd=repo)
    run(["git", "config", "user.email", "test@example.com"], cwd=repo)
    run(["git", "config", "user.name", "Tester"], cwd=repo)
    run(["git", "add", "tests/keep.txt", ".gitignore"], cwd=repo)
    run(["git", "commit", "-m", "init"], cwd=repo)
    result = _tests_for(repo, REQ)
    assert result == ["tests/keep.txt"]
