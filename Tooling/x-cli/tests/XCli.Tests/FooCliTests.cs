using System.Linq;
using XCli.Tests.TestInfra;
using Xunit;

public class FooCliTests
{
    private static ProcessRunner.CliResult Run(params string[] payload)
        => ProcessRunner.RunAsync("foo", payload).GetAwaiter().GetResult();

    [Fact]
    public void FooSubcommandPrintsAndLogs()
    {
        var r = Run("baz");
        Assert.Equal(0, r.ExitCode);
        Assert.Equal("baz!", r.StdOut);
        Assert.NotNull(r.LogJson);
        var root = r.LogJson!.RootElement;
        Assert.Equal("foo", root.GetProperty("subcommand").GetString());
        var args = root.GetProperty("args").EnumerateArray().Select(e => e.GetString()).ToArray();
        Assert.Single(args);
        Assert.Equal("baz", args[0]);
        Assert.Equal("success", root.GetProperty("result").GetString());
    }
}
