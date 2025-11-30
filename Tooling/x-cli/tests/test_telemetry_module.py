import json

import pytest

from codex_rules import telemetry


@pytest.fixture
def telemetry_cwd(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    return tmp_path


def test_load_telemetry_missing_file_returns_empty(telemetry_cwd):
    assert telemetry.load_telemetry() == []


def test_load_telemetry_handles_corrupt_file(telemetry_cwd, capsys):
    telemetry.TELEMETRY_PATH.parent.mkdir(parents=True, exist_ok=True)
    telemetry.TELEMETRY_PATH.write_text("not json", encoding="utf-8")

    assert telemetry.load_telemetry() == []
    err = capsys.readouterr().err
    assert "failed to load telemetry" in err.lower()


def test_append_telemetry_entry_normalises_lists(telemetry_cwd):
    entry = {
        "modules_inspected": "cli",
        "checks_skipped": [],
        "ci_log_paths": "logs/run.txt",
        "failing_tests": ("tests::slow",),
    }

    telemetry.append_telemetry_entry(
        entry,
        agent_feedback="all good",
        srs_ids=["FGC-1"],
        command="pytest -q",
        exit_status=0,
    )

    data = json.loads(telemetry.TELEMETRY_PATH.read_text(encoding="utf-8"))
    stored = data["entries"][0]

    assert stored["modules_inspected"] == ["cli"]
    assert stored["failing_tests"] == ["tests::slow"]
    assert stored["ci_log_paths"] == ["logs/run.txt"]
    assert stored["command"] == ["pytest -q"]
    assert stored["exit_status"] == 0
    assert stored["srs_ids"] == ["FGC-1"]
    assert stored["srs_omitted"] is False
    assert "timestamp" in stored


def test_append_telemetry_entry_validates_types(telemetry_cwd):
    with pytest.raises(ValueError):
        telemetry.append_telemetry_entry({"checks_skipped": []})

    with pytest.raises(ValueError):
        telemetry.append_telemetry_entry(
            {"modules_inspected": [], "checks_skipped": []}, command=[123]
        )

    with pytest.raises(ValueError):
        telemetry.append_telemetry_entry(
            {"modules_inspected": [], "checks_skipped": []}, exit_status="bad"
        )



def test_record_telemetry_entry_updates_summary(telemetry_cwd):
    telemetry.record_telemetry_entry(
        {"modules_inspected": ["cli"], "checks_skipped": []},
        srs_ids=["REQ-2", "REQ-1"],
    )

    summary = json.loads(telemetry.SUMMARY_PATH.read_text(encoding="utf-8"))

    assert summary["total_entries"] == 1
    assert summary["srs_omitted_count"] == 0
    assert summary["srs_ids"] == ["REQ-1", "REQ-2"]
