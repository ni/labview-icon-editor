using System;
using System.IO;
using System.Text.Json;
using TestUtil;
using Xunit;

public class TelemetryCliTests
{
    private static string ProjectDir => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../src/XCli"));

    private static ProcRunner.Result Run(string args) =>
        ProcRunner.Run("dotnet", $"run --no-build -c Release -- {args}", null, ProjectDir);

    [Fact]
    [Trait("Category","Telemetry")]
    [Trait("TestCategory","Telemetry")]
    public void Write_Appends_Event_Line()
    {
        var tmp = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".jsonl");
        try
        {
            var r = Run($"telemetry write --out {tmp} --step build --status pass --duration-ms 123");
            Assert.Equal(0, r.ExitCode);
            var text = File.ReadAllText(tmp).Trim();
            Assert.NotEmpty(text);
            using var doc = JsonDocument.Parse(text);
            var root = doc.RootElement;
            Assert.Equal("build", root.GetProperty("step").GetString());
            Assert.Equal("pass", root.GetProperty("status").GetString());
            Assert.True(root.TryGetProperty("duration_ms", out var dur) || root.TryGetProperty("durationMs", out dur));
        }
        finally { try { File.Delete(tmp); } catch { } }
    }

    [Fact]
    [Trait("Category","Telemetry")]
    [Trait("TestCategory","Telemetry")]
    public void Summarize_Builds_Summary_And_History()
    {
        var events = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".jsonl");
        var summary = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".json");
        var history = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".jsonl");
        try
        {
            File.WriteAllLines(events, new[]
            {
                "{\"step\":\"build\",\"status\":\"pass\",\"duration_ms\":10}",
                "{\"step\":\"test\",\"status\":\"fail\",\"duration_ms\":20}"
            });
            var r = Run($"telemetry summarize --in {events} --out {summary} --history {history}");
            Assert.Equal(0, r.ExitCode);
            Assert.True(File.Exists(summary));
            using (var doc = JsonDocument.Parse(File.ReadAllText(summary)))
            {
                var root = doc.RootElement;
                Assert.Equal(2, root.GetProperty("total").GetInt32());
                Assert.Equal(1, root.GetProperty("totalFailures").GetInt32());
                Assert.True(root.TryGetProperty("counts", out _));
                Assert.True(root.TryGetProperty("failureCounts", out _));
                Assert.True(root.TryGetProperty("durationsMs", out _));
            }
            var histLines = File.ReadAllLines(history);
            Assert.True(histLines.Length > 0);
            var histLine = histLines[^1];
            using (var hdoc = JsonDocument.Parse(histLine))
            {
                var hroot = hdoc.RootElement;
                Assert.Equal(2, hroot.GetProperty("total").GetInt32());
                int tf = hroot.TryGetProperty("total_failures", out var tfElem)
                    ? tfElem.GetInt32()
                    : (hroot.TryGetProperty("totalFailures", out var tf2) ? tf2.GetInt32() : -1);
                Assert.Equal(1, tf);
            }
        }
        finally
        {
            try { File.Delete(events); } catch { }
            try { File.Delete(summary); } catch { }
            try { File.Delete(history); } catch { }
        }
    }

    [Fact]
    [Trait("Category","Telemetry")]
    [Trait("TestCategory","Telemetry")]
    public void Summarize_Ignores_Malformed_Lines()
    {
        var events = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".jsonl");
        var summary = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".json");
        try
        {
            File.WriteAllLines(events, new[]
            {
                "{\"step\":\"a\",\"status\":\"pass\"}",
                "not-json",
                "{\"step\":\"b\",\"status\":\"fail\"}"
            });
            var r = Run($"telemetry summarize --in {events} --out {summary}");
            Assert.Equal(0, r.ExitCode);
            using var doc = System.Text.Json.JsonDocument.Parse(File.ReadAllText(summary));
            var root = doc.RootElement;
            // Only 2 valid lines are counted
            Assert.Equal(2, root.GetProperty("total").GetInt32());
            Assert.Equal(1, root.GetProperty("totalFailures").GetInt32());
        }
        finally
        {
            try { File.Delete(events); } catch { }
            try { File.Delete(summary); } catch { }
        }
    }

    [Fact]
    [Trait("Category","Telemetry")]
    [Trait("TestCategory","Telemetry")]
    public void Check_Gates_On_Total_And_PerStep()
    {
        var summary = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("n") + ".json");
        try
        {
            // summary with totalFailures=2 and per-step failures: build=1, test=1
            var json = "{\n  \"counts\": { \"build\": 1, \"test\": 1 },\n  \"failureCounts\": { \"build\": 1, \"test\": 1 },\n  \"durationsMs\": { \"build\": 10, \"test\": 20 },\n  \"total\": 2,\n  \"totalFailures\": 2,\n  \"generatedAtUtc\": \"2025-01-01T00:00:00Z\"\n}\n";
            File.WriteAllText(summary, json);

            // Gate passes when max-failures=2
            var ok = Run($"telemetry check --summary {summary} --max-failures 2");
            Assert.Equal(0, ok.ExitCode);

            // Gate fails when max-failures=1
            var fail = Run($"telemetry check --summary {summary} --max-failures 1");
            Assert.Equal(1, fail.ExitCode);

            // Per-step gate: build<=1, test<=0 should fail
            var stepFail = Run($"telemetry check --summary {summary} --max-failures-step build=1 --max-failures-step test=0");
            Assert.Equal(1, stepFail.ExitCode);

            // Per-step gate: build<=1, test<=1 should pass
            var stepOk = Run($"telemetry check --summary {summary} --max-failures-step build=1 --max-failures-step test=1");
            Assert.Equal(0, stepOk.ExitCode);
        }
        finally { try { File.Delete(summary); } catch { } }
    }
}
