import json
import sys
import time
from pathlib import Path

from tests.TestUtil.run import run

SCRIPT_SRC = Path(__file__).resolve().parent.parent / "scripts" / "generate-traceability.py"


def create_repo(tmp_path: Path) -> Path:
    repo = tmp_path / "repo"
    (repo / "docs" / "srs").mkdir(parents=True)
    (repo / "tests" / "XCli.Tests").mkdir(parents=True)
    (repo / "tests" / "extras").mkdir(parents=True)
    (repo / "scripts").mkdir()
    spec = repo / "docs" / "srs" / "FGC-REQ-DEV-001.md"
    spec.write_text("# FGC-REQ-DEV-001 — Traceability\n", encoding="utf-8")
    test_file = repo / "tests" / "XCli.Tests" / "Dummy.cs"
    test_file.write_text("// FGC-REQ-DEV-001\n", encoding="utf-8")
    extra_test = repo / "tests" / "extras" / "dummy.txt"
    extra_test.write_text("FGC-REQ-DEV-001\n", encoding="utf-8")
    (repo / "scripts" / "generate-traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    run(["git", "init"], cwd=repo)
    run(["git", "config", "user.email", "test@example.com"], cwd=repo)
    run(["git", "config", "user.name", "Tester"], cwd=repo)
    run(["git", "add", "."], cwd=repo)
    run(["git", "commit", "-m", "init"], cwd=repo)
    run(["git", "commit", "--allow-empty", "-m", "Ref FGC-REQ-DEV-001"], cwd=repo)
    return repo


def test_generates_traceability(tmp_path):
    repo = create_repo(tmp_path)
    script = repo / "scripts" / "generate-traceability.py"
    run([sys.executable, str(script)], cwd=repo)
    out = repo / "telemetry" / "traceability.json"
    data = json.loads(out.read_text(encoding="utf-8"))
    entry = next(e for e in data["requirements"] if e["id"] == "FGC-REQ-DEV-001")
    assert entry["spec"] == "docs/srs/FGC-REQ-DEV-001.md"
    assert entry["tests"] == [
        "tests/XCli.Tests/Dummy.cs",
        "tests/extras/dummy.txt",
    ]
    assert len(entry["commits"]) >= 1


def test_exclude_pattern(tmp_path):
    repo = create_repo(tmp_path)
    script = repo / "scripts" / "generate-traceability.py"
    run([sys.executable, str(script), "--exclude", "extras/**"], cwd=repo)
    out = repo / "telemetry" / "traceability.json"
    data = json.loads(out.read_text(encoding="utf-8"))
    entry = next(e for e in data["requirements"] if e["id"] == "FGC-REQ-DEV-001")
    assert entry["tests"] == ["tests/XCli.Tests/Dummy.cs"]


def test_include_pattern(tmp_path):
    repo = create_repo(tmp_path)
    script = repo / "scripts" / "generate-traceability.py"
    run([sys.executable, str(script), "--include", "XCli.Tests/**"], cwd=repo)
    out = repo / "telemetry" / "traceability.json"
    data = json.loads(out.read_text(encoding="utf-8"))
    entry = next(e for e in data["requirements"] if e["id"] == "FGC-REQ-DEV-001")
    assert entry["tests"] == ["tests/XCli.Tests/Dummy.cs"]


def test_large_repo_performance(tmp_path):
    repo = create_repo(tmp_path)
    tests_dir = repo / "tests" / "bulk"
    tests_dir.mkdir()
    for i in range(2000):
        (tests_dir / f"t{i}.txt").write_text("FGC-REQ-DEV-001\n", encoding="utf-8")
    script = repo / "scripts" / "generate-traceability.py"
    start = time.perf_counter()
    run([sys.executable, str(script)], cwd=repo)
    duration = time.perf_counter() - start
    assert duration < 5.0


def test_ignores_gitignored_files(tmp_path):
    repo = tmp_path / "repo"
    (repo / "docs" / "srs").mkdir(parents=True)
    (repo / "tests" / "XCli.Tests").mkdir(parents=True)
    (repo / "tests" / "extras").mkdir(parents=True)
    (repo / "scripts").mkdir()
    spec = repo / "docs" / "srs" / "FGC-REQ-DEV-001.md"
    spec.write_text("# FGC-REQ-DEV-001 — Traceability\n", encoding="utf-8")
    test_file = repo / "tests" / "XCli.Tests" / "Dummy.cs"
    test_file.write_text("// FGC-REQ-DEV-001\n", encoding="utf-8")
    ignored_test = repo / "tests" / "extras" / "dummy.txt"
    ignored_test.write_text("FGC-REQ-DEV-001\n", encoding="utf-8")
    (repo / ".gitignore").write_text("tests/extras/\n", encoding="utf-8")
    (repo / "scripts" / "generate-traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    run(["git", "init"], cwd=repo)
    run(["git", "config", "user.email", "test@example.com"], cwd=repo)
    run(["git", "config", "user.name", "Tester"], cwd=repo)
    run(["git", "add", "docs", "tests/XCli.Tests", "scripts", ".gitignore"], cwd=repo)
    run(["git", "commit", "-m", "init"], cwd=repo)
    run(["git", "commit", "--allow-empty", "-m", "Ref FGC-REQ-DEV-001"], cwd=repo)
    script = repo / "scripts" / "generate-traceability.py"
    run([sys.executable, str(script)], cwd=repo)
    out = repo / "telemetry" / "traceability.json"
    data = json.loads(out.read_text(encoding="utf-8"))
    entry = next(e for e in data["requirements"] if e["id"] == "FGC-REQ-DEV-001")
    assert entry["tests"] == ["tests/XCli.Tests/Dummy.cs"]


def test_without_git_repository(tmp_path):
    repo = tmp_path / "repo"
    (repo / "docs" / "srs").mkdir(parents=True)
    (repo / "tests").mkdir(parents=True)
    (repo / "scripts").mkdir()
    spec = repo / "docs" / "srs" / "FGC-REQ-DEV-001.md"
    spec.write_text("# FGC-REQ-DEV-001 — Traceability\n", encoding="utf-8")
    test_file = repo / "tests" / "dummy.txt"
    test_file.write_text("FGC-REQ-DEV-001\n", encoding="utf-8")
    (repo / "scripts" / "generate-traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    script = repo / "scripts" / "generate-traceability.py"
    run([sys.executable, str(script)], cwd=repo)
    out = repo / "telemetry" / "traceability.json"
    data = json.loads(out.read_text(encoding="utf-8"))
    entry = next(e for e in data["requirements"] if e["id"] == "FGC-REQ-DEV-001")
    assert entry["tests"] == ["tests/dummy.txt"]
    assert entry["commits"] == []
