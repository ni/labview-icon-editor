import json
from pathlib import Path

from codex_rules.ingest.jest_json import parse_jest_json


def test_parse_jest_json_extracts_assertions(tmp_path):
    payload = {
        "testResults": [
            {
                "name": "/root/project/sum.test.js",
                "assertionResults": [
                    {"title": "adds numbers", "status": "passed", "duration": 7},
                    {"title": "subtracts", "status": "failed", "duration": 4},
                ],
            }
        ]
    }
    path = tmp_path / "report.json"
    path.write_text(json.dumps(payload), encoding="utf-8")

    events = parse_jest_json(str(path))

    assert events == [
        {
            "test_id": "sum.test.js#adds numbers",
            "suite": "sum.test.js",
            "status": "passed",
            "duration_ms": 7,
            "file": "/root/project/sum.test.js",
        },
        {
            "test_id": "sum.test.js#subtracts",
            "suite": "sum.test.js",
            "status": "failed",
            "duration_ms": 4,
            "file": "/root/project/sum.test.js",
        },
    ]


def test_parse_jest_json_returns_empty_on_invalid(tmp_path):
    path = tmp_path / "bad.json"
    path.write_text(json.dumps({"testResults": None}), encoding="utf-8")

    assert parse_jest_json(str(path)) == []
