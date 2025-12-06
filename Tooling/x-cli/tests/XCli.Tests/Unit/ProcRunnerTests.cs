using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using TestUtil;
using Xunit;

namespace XCli.Tests.Unit;

public sealed class ProcRunnerTests
{
    [Fact(DisplayName = "ProcRunner terminates processes exceeding timeout quickly")]
    public void Run_KillsProcessAfterTimeout()
    {
        var helper = Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "..", "..", "..", "..",
            "TestUtil", "sleep_forever.py"));

        var sw = Stopwatch.StartNew();
        // Explicitly invoke "python3" to avoid environments where the
        // unversioned "python" shim is missing.
        var result = ProcRunner.Run("python3", $"\"{helper}\"", timeout: TimeSpan.FromMilliseconds(100));
        sw.Stop();

        Assert.NotEqual(0, result.ExitCode);
        Assert.True(sw.Elapsed < TimeSpan.FromSeconds(3));
    }

    [Fact(DisplayName = "ProcRunner returns environment snapshot")]
    public void Run_CapturesEnvironment()
    {
        var env = new Dictionary<string, string> { { "FGC_TEST_VAR", "1" } };
        var result = ProcRunner.Run("dotnet", "--info", env);
        Assert.Equal("1", result.Environment["FGC_TEST_VAR"]);
    }
}
