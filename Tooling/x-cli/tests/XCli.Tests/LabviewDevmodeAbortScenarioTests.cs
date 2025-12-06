using System.Collections.Generic;
using XCli.Tests.TestInfra;
using Xunit;

public class LabviewDevmodeAbortScenarioTests
{
    private static ProcessRunner.CliResult Run(string sub, IDictionary<string, string>? env = null, params string[] payload)
        => ProcessRunner.RunAsync(sub, payload, env).GetAwaiter().GetResult();

    public LabviewDevmodeAbortScenarioTests() => XCli.Util.Env.ResetCacheForTests();

    [Fact]
    public void AbortScenarioSimulatesUserCancellation()
    {
        var r = Run(
            "labview-devmode-enable",
            null,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--script", "AddTokenToLabVIEW.ps1",
            "--scenario", "abort");

        Assert.Equal(130, r.ExitCode);
        Assert.Contains("operation aborted by user", r.StdErr);
    }
}

