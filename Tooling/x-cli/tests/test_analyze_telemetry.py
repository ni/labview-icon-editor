"""Unit tests for telemetry append helper (FGC-REQ-TEL-001)."""

import json
import os

import pytest

from codex_rules.telemetry import append_telemetry_entry


def test_missing_required_field_raises(tmp_path):
    cwd = os.getcwd()
    os.chdir(tmp_path)
    try:
        with pytest.raises(ValueError):
            append_telemetry_entry({"modules_inspected": []})
        with pytest.raises(ValueError):
            append_telemetry_entry({"checks_skipped": []})
    finally:
        os.chdir(cwd)


def test_list_fields_normalized(tmp_path):
    cwd = os.getcwd()
    os.chdir(tmp_path)
    try:
        append_telemetry_entry(
            {
                "modules_inspected": [],
                "checks_skipped": [],
                "ci_log_paths": "ci.log",
                "failing_tests": "tests.A::B",
            }
        )
        data = json.loads((tmp_path / ".codex" / "telemetry.json").read_text())
        entry = data["entries"][-1]
        assert entry["ci_log_paths"] == ["ci.log"]
        assert entry["failing_tests"] == ["tests.A::B"]
    finally:
        os.chdir(cwd)


def test_non_string_values_rejected(tmp_path):
    cwd = os.getcwd()
    os.chdir(tmp_path)
    try:
        with pytest.raises(ValueError):
            append_telemetry_entry({"modules_inspected": [1], "checks_skipped": []})
        with pytest.raises(ValueError):
            append_telemetry_entry({"modules_inspected": [], "checks_skipped": [2]})
    finally:
        os.chdir(cwd)
