using System.Linq;
using XCli.Tests.TestInfra;
using Xunit;

public class UpperCliTests
{
    private static ProcessRunner.CliResult Run(params string[] payload)
        => ProcessRunner.RunAsync("upper", payload).GetAwaiter().GetResult();

    [Fact]
    public void UpperSubcommandPrintsAndLogs()
    {
        var r = Run("hello");
        Assert.Equal(0, r.ExitCode);
        Assert.Equal("HELLO", r.StdOut);
        Assert.NotNull(r.LogJson);
        var root = r.LogJson!.RootElement;
        Assert.Equal("upper", root.GetProperty("subcommand").GetString());
        var args = root.GetProperty("args").EnumerateArray().Select(e => e.GetString()).ToArray();
        Assert.Single(args);
        Assert.Equal("hello", args[0]);
        Assert.Equal("success", root.GetProperty("result").GetString());
    }
}

