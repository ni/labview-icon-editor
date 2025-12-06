using System.Linq;
using XCli.Tests.TestInfra;
using Xunit;

public class ReverseCliTests
{
    private static ProcessRunner.CliResult Run(params string[] payload)
        => ProcessRunner.RunAsync("reverse", payload).GetAwaiter().GetResult();

    [Fact]
    public void ReverseSubcommandPrintsAndLogs()
    {
        var r = Run("abcd");
        Assert.Equal(0, r.ExitCode);
        Assert.Equal("dcba", r.StdOut);
        Assert.NotNull(r.LogJson);
        var root = r.LogJson!.RootElement;
        Assert.Equal("reverse", root.GetProperty("subcommand").GetString());
        var args = root.GetProperty("args").EnumerateArray().Select(e => e.GetString()).ToArray();
        Assert.Single(args);
        Assert.Equal("abcd", args[0]);
        Assert.Equal("success", root.GetProperty("result").GetString());
    }
}

