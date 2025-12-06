import json
from pathlib import Path

from scripts.check_test_durations import main


def write_telemetry(dir: Path, entries: list[tuple[str, float]]) -> None:
    dir.mkdir(parents=True, exist_ok=True)
    with (dir / "test-telemetry.jsonl").open("w", encoding="utf-8") as f:
        for i, (lang, d) in enumerate(entries):
            entry = {
                "test": f"t{i}",
                "language": lang,
                "duration": d,
                "outcome": "passed",
                "dependencies": [],
            }
            f.write(json.dumps(entry) + "\n")


def test_duration_within_baseline(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    write_telemetry(tmp_path / "artifacts", [("python", 1.0), ("python", 2.0)])
    baseline = {"total_duration": 5.0}
    (tmp_path / "tests").mkdir()
    (tmp_path / "tests" / "test-duration-benchmark.json").write_text(
        json.dumps(baseline)
    )
    monkeypatch.setenv("TEST_LANGUAGES", "python")
    assert main() == 0


def test_duration_exceeds_baseline(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    write_telemetry(tmp_path / "artifacts", [("python", 4.0)])
    baseline = {"total_duration": 2.0}
    (tmp_path / "tests").mkdir()
    (tmp_path / "tests" / "test-duration-benchmark.json").write_text(
        json.dumps(baseline)
    )
    monkeypatch.setenv("TEST_LANGUAGES", "python")
    assert main() == 1


def test_missing_language_fails(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    write_telemetry(tmp_path / "artifacts", [("python", 1.0)])
    baseline = {"total_duration": 5.0}
    (tmp_path / "tests").mkdir()
    (tmp_path / "tests" / "test-duration-benchmark.json").write_text(
        json.dumps(baseline)
    )
    # Expect default python,dotnet requirement to fail since dotnet missing
    assert main() == 1
