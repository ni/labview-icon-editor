using System.Linq;
using XCli.Tests.TestInfra;
using Xunit;

public class EchoCliTests
{
    private static ProcessRunner.CliResult Run(params string[] payload)
        => ProcessRunner.RunAsync("echo", payload).GetAwaiter().GetResult();

    [Fact]
    public void EchoSubcommandPrintsAndLogs()
    {
        var r = Run("hello");
        Assert.Equal(0, r.ExitCode);
        Assert.Equal("hello", r.StdOut);
        Assert.NotNull(r.LogJson);
        var root = r.LogJson!.RootElement;
        Assert.Equal("echo", root.GetProperty("subcommand").GetString());
        var args = root.GetProperty("args").EnumerateArray().Select(e => e.GetString()).ToArray();
        Assert.Single(args);
        Assert.Equal("hello", args[0]);
        Assert.Equal("success", root.GetProperty("result").GetString());
    }
}
