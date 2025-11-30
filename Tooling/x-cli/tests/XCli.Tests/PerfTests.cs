using System.Diagnostics;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using XCli.Cli;
using XCli.Tests.TestInfra;
using XCli.Util;
using Xunit;
using Xunit.Abstractions;

/// <summary>
/// Exercises each subcommand and flags regressions. The failure threshold is
/// configurable via <c>XCLI_PERF_FAIL_MS</c> (default 8000 ms). A warning is
/// emitted when execution exceeds <c>XCLI_PERF_WARN_MS</c> (default half the
/// failure threshold, 4000 ms).
/// (FGC-REQ-QA-001)
/// </summary>
public class PerfTests
{
    private readonly ITestOutputHelper _output;
    public PerfTests(ITestOutputHelper output) => _output = output;

    private static Task<ProcessRunner.CliResult> RunAsync(string sub)
        => ProcessRunner.RunAsync(sub, Array.Empty<string>());

    private static readonly string[] PerfExclusions = new[] { "log-replay", "log-diff", "vip", "telemetry" };

    public static IEnumerable<object[]> Subcommands() =>
        Cli.Subcommands
            .Where(s => !PerfExclusions.Contains(s, StringComparer.OrdinalIgnoreCase))
            .OrderBy(s => s)
            .Select(s => new object[] { s });

    [Theory(DisplayName = "FGC-REQ-PERF-001: Subcommand completes within latency budget")]
    [MemberData(nameof(Subcommands))]
    public async Task CompletesQuickly(string sub)
    {
        var warmup = await RunAsync(sub);
        Assert.Equal(0, warmup.ExitCode);

        var failThresholdMs = Env.GetInt("XCLI_PERF_FAIL_MS", 8000);
        var warnThresholdMs = Env.GetInt("XCLI_PERF_WARN_MS", failThresholdMs / 2);

        var sw = Stopwatch.StartNew();
        var r = await RunAsync(sub);
        sw.Stop();
        Assert.Equal(0, r.ExitCode);
        if (sw.ElapsedMilliseconds > warnThresholdMs)
            _output.WriteLine($"::warning::{sub} took {sw.ElapsedMilliseconds}ms");
        Assert.True(sw.ElapsedMilliseconds < failThresholdMs, $"{sub} took {sw.ElapsedMilliseconds}ms");
    }
}
