using System;
using System.IO;
using System.Linq;
using TestUtil;
using Xunit;

public class LogReplayTests
{
    private static string ProjectDir => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../src/XCli"));

    [Fact]
    public void Replay_PrintsVerbatimMessages_WithOriginalOrdering()
    {
        var tmp = Path.GetTempFileName();
        try
        {
            File.WriteAllLines(tmp, new[]
            {
                "{\"t\":0,\"s\":\"stdout\",\"m\":\"Starting suite A\"}",
                "{\"t\":10,\"s\":\"stdout\",\"m\":\"Test A1 ... ok\"}",
                "{\"t\":5,\"s\":\"stderr\",\"m\":\"[warn] slow op\"}"
            });

            var r = ProcRunner.Run("dotnet", $"run --no-build -c Release -- log-replay --from \"{tmp}\" --max-delay-ms 0", null, ProjectDir);
            Assert.Equal(0, r.ExitCode);

            var outLines = r.StdOut.Replace("\r", string.Empty).Split('\n', StringSplitOptions.RemoveEmptyEntries);
            Assert.Equal("Starting suite A", outLines.ElementAtOrDefault(0));
            Assert.Equal("Test A1 ... ok", outLines.ElementAtOrDefault(1));
            Assert.Contains("[warn] slow op", r.StdErr);
        }
        finally
        {
            try { File.Delete(tmp); } catch { /* ignore */ }
        }
    }

    [Fact]
    public void Replay_RespectsMaxDelayCap_WhenConfigured()
    {
        var tmp = Path.GetTempFileName();
        try
        {
            File.WriteAllLines(tmp, new[]
            {
                "{\"t\":0,\"s\":\"stdout\",\"m\":\"start\"}",
                "{\"t\":5000,\"s\":\"stdout\",\"m\":\"after long delay\"}"
            });

            var begin = DateTime.UtcNow;
            var r = ProcRunner.Run("dotnet", $"run --no-build -c Release -- log-replay --from \"{tmp}\" --max-delay-ms 50", null, ProjectDir);
            var durMs = (int)(DateTime.UtcNow - begin).TotalMilliseconds;

            Assert.Equal(0, r.ExitCode);
            Assert.Contains("after long delay", r.StdOut);
            // Allow a wider margin on Windows self-hosted runners where scheduling jitter can be higher
            var capMs = OperatingSystem.IsWindows() ? 2500 : 1500;
            Assert.True(durMs < capMs, $"Replay took too long: {durMs}ms");
        }
        finally
        {
            try { File.Delete(tmp); } catch { /* ignore */ }
        }
    }
}
