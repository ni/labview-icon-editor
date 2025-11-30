using System;
using System.IO;
using TestUtil;
using Xunit;

public class TelemetryValidateTests
{
    private static string ProjectDir => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../src/XCli"));
    private static string RepoRoot => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../.."));
    private static ProcRunner.Result Run(string args) =>
        ProcRunner.Run("dotnet", $"run --no-build -c Release -- {args}", null, ProjectDir);

    [Fact]
    [Trait("Category","Telemetry")]
    [Trait("TestCategory","Telemetry")]
    public void Summary_Validate_WithSchema_Valid()
    {
        var schema = Path.Combine(RepoRoot, "docs/schemas/v1/telemetry.summary.v1.schema.json");
        var tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".json");
        try
        {
            File.WriteAllText(tmp, "{\n  \"counts\": { \"build\": 1 },\n  \"failureCounts\": { \"build\": 0 },\n  \"durationsMs\": { \"build\": 10 },\n  \"total\": 1,\n  \"totalFailures\": 0,\n  \"generatedAtUtc\": \"2025-01-01T00:00:00Z\"\n}\n");
            var r = Run($"telemetry validate --summary {tmp} --schema {schema}");
            Assert.Equal(0, r.ExitCode);
            Assert.Contains("telemetry: validation OK", r.StdOut);
        }
        finally { try { File.Delete(tmp); } catch { } }
    }

    [Fact]
    [Trait("Category","Telemetry")]
    [Trait("TestCategory","Telemetry")]
    public void Summary_Validate_WithSchema_Invalid()
    {
        var schema = Path.Combine(RepoRoot, "docs/schemas/v1/telemetry.summary.v1.schema.json");
        var tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".json");
        try
        {
            // missing totalFailures
            File.WriteAllText(tmp, "{\n  \"counts\": { \"build\": 1 },\n  \"failureCounts\": { \"build\": 0 },\n  \"durationsMs\": { \"build\": 10 },\n  \"total\": 1,\n  \"generatedAtUtc\": \"2025-01-01T00:00:00Z\"\n}\n");
            var r = Run($"telemetry validate --summary {tmp} --schema {schema}");
            Assert.Equal(2, r.ExitCode);
            Assert.Contains("schema validation failed", r.StdErr);
        }
        finally { try { File.Delete(tmp); } catch { } }
    }

    [Fact]
    [Trait("Category","Telemetry")]
    [Trait("TestCategory","Telemetry")]
    public void Events_Validate_WithSchema_Valid()
    {
        var schema = Path.Combine(RepoRoot, "docs/schemas/v1/telemetry.events.v1.schema.json");
        var tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".jsonl");
        try
        {
            File.WriteAllText(tmp, "{\"step\":\"build\",\"status\":\"pass\",\"duration_ms\":10}\n");
            var r = Run($"telemetry validate --events {tmp} --schema {schema}");
            Assert.Equal(0, r.ExitCode);
            Assert.Contains("telemetry: validation OK", r.StdOut);
        }
        finally { try { File.Delete(tmp); } catch { } }
    }

    [Fact]
    [Trait("Category","Telemetry")]
    [Trait("TestCategory","Telemetry")]
    public void Events_Validate_WithSchema_Invalid()
    {
        var schema = Path.Combine(RepoRoot, "docs/schemas/v1/telemetry.events.v1.schema.json");
        var tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".jsonl");
        try
        {
            // invalid status value (violates enum)
            File.WriteAllText(tmp, "{\"step\":\"build\",\"status\":\"oops\",\"duration_ms\":10}\n");
            var r = Run($"telemetry validate --events {tmp} --schema {schema}");
            Assert.Equal(2, r.ExitCode);
            Assert.Contains("schema validation failed", r.StdErr);
        }
        finally { try { File.Delete(tmp); } catch { } }
    }
}
