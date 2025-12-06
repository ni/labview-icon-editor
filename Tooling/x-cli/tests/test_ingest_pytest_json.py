import json
from pathlib import Path

from codex_rules.ingest.pytest_json import parse_pytest_json


def test_parse_pytest_json_supports_dict_format(tmp_path):
    payload = {
        "tests": [
            {"nodeid": "tests/test_sample.py::test_ok", "outcome": "passed", "duration": 0.03},
            {
                "nodeid": "tests/test_sample.py::TestCase::test_fail",
                "outcome": "failed",
                "call": {"duration": 0.1},
            },
        ]
    }
    path = tmp_path / "report.json"
    path.write_text(json.dumps(payload), encoding="utf-8")

    events = parse_pytest_json(str(path))

    assert events[0]["status"] == "passed"
    assert events[0]["duration_ms"] == 30
    assert events[0]["file"] == "tests/test_sample.py"

    assert events[1]["status"] == "failed"
    assert events[1]["suite"] == "tests/test_sample.py"
    assert events[1]["test_id"].endswith("#test_fail")


def test_parse_pytest_json_accepts_list_format(tmp_path):
    payload = [
        {"id": "api::test_api", "outcome": "failed", "duration": "0.5"},
        {"nodeid": "api::test_second", "outcome": "other", "duration": "bad"},
    ]
    path = tmp_path / "list.json"
    path.write_text(json.dumps(payload), encoding="utf-8")

    events = parse_pytest_json(str(path))

    assert len(events) == 2
    assert events[0]["status"] == "failed"
    assert events[0]["duration_ms"] == 500
    assert events[1]["duration_ms"] == 0


def test_parse_pytest_json_returns_empty_for_unknown(tmp_path):
    path = tmp_path / "empty.json"
    path.write_text(json.dumps({"tests": None}), encoding="utf-8")

    assert parse_pytest_json(str(path)) == []
