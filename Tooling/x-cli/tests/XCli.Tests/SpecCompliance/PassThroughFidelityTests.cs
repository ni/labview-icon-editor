using XCli.Tests.TestInfra;
using System.Linq;
using Xunit;

namespace XCli.Tests.SpecCompliance;

public class PassThroughFidelityTests
{
    [Fact(DisplayName = "FGC-REQ-CLI-001: Tokens after -- are logged exactly in args array")]
    public async Task PassThrough_TokensLoggedExactly()
    {
        // complex payload to exercise spacing and equals signs
        var payload = new[]
        {
            "-r", "Report File.xml",
            "--flag=with=equals",
            "spaced arg",
            "C:\\Path With Spaces\\file.txt"
        };

        var res = await ProcessRunner.RunAsync("vitester", payload);
        var log = res.LogJson;
        Assert.NotNull(log);

        var args = log!.RootElement.GetProperty("args").EnumerateArray().Select(e => e.GetString()).ToArray();
        var expected = payload;
        Assert.Equal(expected, args);
    }
}

