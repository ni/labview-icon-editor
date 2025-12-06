using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using XCli.Tests.TestInfra;
using Xunit;

public class EndToEndTests
{
    private static Task<ProcessRunner.CliResult> RunAsync(string sub, IDictionary<string, string>? env = null, params string[] payload)
        => ProcessRunner.RunAsync(sub, payload, env);

    [Fact]
    public async Task PayloadAndLogging()
    {
        var path = Path.GetTempFileName();
        var env = new Dictionary<string, string> { ["XCLI_LOG_PATH"] = path };
        var r = await RunAsync("vitester", env, "a", "b");
        Assert.Equal(0, r.ExitCode);
        var lines = File.ReadAllLines(path);
        Assert.Single(lines);
    }

    [Fact]
    public async Task NoSideEffectsExceptLog()
    {
        var tmp = Directory.CreateTempSubdirectory();
        var logPath = Path.Combine(tmp.FullName, "log.jsonl");
        var env = new Dictionary<string, string> { ["XCLI_LOG_PATH"] = logPath };
        var r = await RunAsync("vitester", env, "../../../../../../../tmp/evil");
        Assert.Equal(0, r.ExitCode);
        var files = Directory.GetFiles(tmp.FullName);
        Assert.Single(files);
        Assert.Equal(logPath, files[0]);
    }
}
