from pathlib import Path

from codex_rules.ingest.junit import parse_junit


def _write(tmp_path, text: str) -> Path:
    path = tmp_path / "report.xml"
    path.write_text(text, encoding="utf-8")
    return path


def test_parse_junit_handles_failures_and_duration(tmp_path):
    xml = """
    <testsuite>
      <testcase classname="suite.Alpha" name="test_ok" time="0.2" file="alpha.py" />
      <testcase classname="suite.Beta" name="test_fail" time="bad" file="beta.py">
        <failure>boom</failure>
      </testcase>
    </testsuite>
    """
    report = _write(tmp_path, xml)

    events = parse_junit(str(report))

    assert events == [
        {
            "test_id": "suite.Alpha#test_ok",
            "suite": "suite.Alpha",
            "status": "passed",
            "duration_ms": 200,
            "file": "alpha.py",
        },
        {
            "test_id": "suite.Beta#test_fail",
            "suite": "suite.Beta",
            "status": "failed",
            "duration_ms": 0,
            "file": "beta.py",
        },
    ]
