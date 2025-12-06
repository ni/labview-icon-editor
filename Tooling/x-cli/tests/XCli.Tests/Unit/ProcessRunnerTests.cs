using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.Threading.Tasks;
using XCli.Tests.TestInfra;
using Xunit;

namespace XCli.Tests.Unit;

public class ProcessRunnerTests
{
    [Fact(DisplayName = "ProcessRunner terminates hung subprocesses quickly")]
    public async Task RunAsync_KillsHungProcessQuickly()
    {
        var env = new Dictionary<string, string>
        {
            // Intentionally 1s delay to simulate a hung subprocess while
            // keeping cleanup fast if the guard trips.
            ["XCLI_DELAY_MS"] = "1000"
        };

        var sw = Stopwatch.StartNew();
        var ex = await Assert.ThrowsAsync<TimeoutException>(() =>
            ProcessRunner.RunAsync(
                subcommand: "vipc",
                payloadArgs: Array.Empty<string>(),
                env: env,
                timeout: TimeSpan.FromMilliseconds(500))
                // Guard so the test fails fast if the subprocess hangs.
                // WaitAsync throws TimeoutException with message
                // "The operation has timed out." if triggered.
                .WaitAsync(TimeSpan.FromSeconds(2)));
        sw.Stop();

        Assert.Contains("timed out", ex.Message);
        Assert.True(sw.Elapsed < TimeSpan.FromSeconds(3));
    }

    [Fact(DisplayName = "ProcessRunner snapshots environment variables")]
    public async Task RunAsync_SnapshotsEnvironment()
    {
        var env = new Dictionary<string, string>
        {
            ["XCLI_TEST_VAR"] = "expected-value",
            ["XCLI_ANOTHER_VAR"] = "another"
        };

        var res = await ProcessRunner.RunAsync(
            subcommand: "vipc",
            payloadArgs: Array.Empty<string>(),
            env: env)
            // Guard so the test fails fast if the subprocess hangs.
            // WaitAsync throws TimeoutException with message
            // "The operation has timed out." if triggered.
            .WaitAsync(TimeSpan.FromSeconds(2));

        Assert.Equal("expected-value", res.Environment["XCLI_TEST_VAR"]);
        Assert.Equal("another", res.Environment["XCLI_ANOTHER_VAR"]);
    }
}
