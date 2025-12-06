"""Validate telemetry captures failed tests (FGC-REQ-TEL-001)."""

import json
import shutil
import subprocess
from pathlib import Path


def test_failed_tests_log_exception(tmp_path):
    work = tmp_path / "nested"
    work.mkdir()
    subprocess.run(["dotnet", "new", "xunit", "-n", "XCli.Tests"], cwd=work, check=True)
    proj_dir = work / "XCli.Tests"

    (proj_dir / "UnitTest1.cs").write_text(
        """
using System;
using Xunit;

public class Failing
{
    [Fact]
    public void Boom() => throw new InvalidOperationException("boom");
}
"""
    )

    source = Path(__file__).resolve().parent / "XCli.Tests" / "TestTelemetry.cs"
    shutil.copyfile(source, proj_dir / "TestTelemetry.cs")
    util_dir = Path(__file__).resolve().parent / "XCli.Tests" / "Utilities"
    shutil.copytree(util_dir, proj_dir / "Utilities")

    result = subprocess.run(["dotnet", "test", "-c", "Release"], cwd=proj_dir)
    assert result.returncode != 0

    telemetry_path = tmp_path / "artifacts" / "test-telemetry.jsonl"
    entry = json.loads(telemetry_path.read_text().splitlines()[-1])
    assert entry["exception_type"] == "InvalidOperationException"
    assert entry["exception_message"] == "boom"

