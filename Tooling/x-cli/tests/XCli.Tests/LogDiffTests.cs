using System;
using System.IO;
using System.Text.Json;
using TestUtil;
using Xunit;

public class LogDiffTests
{
    private static string ProjectDir => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../src/XCli"));

    [Fact]
    public void Diff_PrintsPerTestTimingDeltas()
    {
        var baseline = Path.GetTempFileName();
        var candidate = Path.GetTempFileName();
        try
        {
            File.WriteAllLines(baseline, new[]
            {
                "{\"t\":0,\"s\":\"stdout\",\"m\":\"A1 start\",\"test\":\"A1\"}",
                "{\"t\":100,\"s\":\"stdout\",\"m\":\"A1 ok\",   \"test\":\"A1\"}",
                "{\"t\":0,\"s\":\"stdout\",\"m\":\"A2 start\",\"test\":\"A2\"}",
                "{\"t\":200,\"s\":\"stdout\",\"m\":\"A2 ok\",   \"test\":\"A2\"}"
            });
            File.WriteAllLines(candidate, new[]
            {
                "{\"t\":0,\"s\":\"stdout\",\"m\":\"A1 start\",\"test\":\"A1\"}",
                "{\"t\":150,\"s\":\"stdout\",\"m\":\"A1 ok\",   \"test\":\"A1\"}",
                "{\"t\":0,\"s\":\"stdout\",\"m\":\"A2 start\",\"test\":\"A2\"}",
                "{\"t\":180,\"s\":\"stdout\",\"m\":\"A2 ok\",   \"test\":\"A2\"}"
            });

            var r = ProcRunner.Run(
                "dotnet",
                $"run --no-build -c Release -- log-diff --baseline \"{baseline}\" --candidate \"{candidate}\" --format text --by test",
                null,
                ProjectDir);

            Assert.Equal(0, r.ExitCode);
            Assert.Contains("Diff by test", r.StdOut);
            Assert.Contains("A1", r.StdOut);
            Assert.Contains("A2", r.StdOut);
            Assert.Contains("+50ms", r.StdOut);
        }
        finally
        {
            try { File.Delete(baseline); } catch { /* ignore */ }
            try { File.Delete(candidate); } catch { /* ignore */ }
        }
    }

    [Fact]
    public void Diff_JsonFormatProducesStructuredOutput()
    {
        var baseline = Path.GetTempFileName();
        var candidate = Path.GetTempFileName();
        try
        {
            File.WriteAllLines(baseline, new[]
            {
                "{\"t\":0,\"s\":\"stdout\",\"m\":\"B1 start\",\"test\":\"B1\"}",
                "{\"t\":80,\"s\":\"stdout\",\"m\":\"B1 ok\",   \"test\":\"B1\"}"
            });
            File.WriteAllLines(candidate, new[]
            {
                "{\"t\":0,\"s\":\"stdout\",\"m\":\"B1 start\",\"test\":\"B1\"}",
                "{\"t\":100,\"s\":\"stdout\",\"m\":\"B1 ok\",   \"test\":\"B1\"}"
            });

            var r = ProcRunner.Run(
                "dotnet",
                $"run --no-build -c Release -- log-diff --baseline \"{baseline}\" --candidate \"{candidate}\" --format json --by test",
                null,
                ProjectDir);

            Assert.Equal(0, r.ExitCode);
            using var doc = JsonDocument.Parse(r.StdOut);
            Assert.Equal("test", doc.RootElement.GetProperty("by").GetString());
            var rows = doc.RootElement.GetProperty("rows");
            Assert.True(rows.GetArrayLength() >= 1);
            var first = rows[0];
            Assert.Equal("B1", first.GetProperty("key").GetString());
            Assert.Equal(80, first.GetProperty("baselineMs").GetInt32());
            Assert.Equal(100, first.GetProperty("candidateMs").GetInt32());
            Assert.Equal(20, first.GetProperty("deltaMs").GetInt32());
        }
        finally
        {
            try { File.Delete(baseline); } catch { /* ignore */ }
            try { File.Delete(candidate); } catch { /* ignore */ }
        }
    }
}

