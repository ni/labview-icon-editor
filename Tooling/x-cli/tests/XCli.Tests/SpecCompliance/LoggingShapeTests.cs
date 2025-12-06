using System.Text.Json;
using System.Linq;
using XCli.Tests.TestInfra;
using XCli.Tests.Utilities;
using Xunit;

namespace XCli.Tests.SpecCompliance;

[ExternalDependency("dotnet CLI")]
public class LoggingShapeTests
{
    [Fact(DisplayName = "FGC-REQ-LOG-001/002: Log is JSON on stderr with required keys; stdout contains only simulated user message")]
    public async Task LogJsonOnStderr_WithRequiredKeys()
    {
        var res = await ProcessRunner.RunAsync(
            "lvbuildspec",
            new[] { "-p", "My.lvproj", "-b", "MyApp" });

        // stdout contains only user-facing message
        Assert.Contains("[x-cli] lvbuildspec: success (simulated)", res.StdOut);
        Assert.DoesNotContain("\"timestampUtc\"", res.StdOut);

        var log = res.LogJson;
        Assert.NotNull(log);
        var root = log!.RootElement;
        AssertHas(root, "timestampUtc");
        AssertHas(root, "pid");
        AssertHas(root, "os");
        AssertHas(root, "subcommand");
        AssertHas(root, "args");
        AssertHas(root, "env");
        AssertHas(root, "result");
        AssertHas(root, "exitCode");
        AssertHas(root, "message");
        AssertHas(root, "durationMs");

        Assert.Equal("lvbuildspec", root.GetProperty("subcommand").GetString());
        Assert.Equal("success", root.GetProperty("result").GetString());
        Assert.Equal(string.Empty, root.GetProperty("message").GetString());

        var args = root.GetProperty("args").EnumerateArray().Select(e => e.GetString()).ToArray();
        Assert.Equal(new[] { "-p", "My.lvproj", "-b", "MyApp" }, args);

        var envObj = root.GetProperty("env");
        Assert.Equal(JsonValueKind.Object, envObj.ValueKind);
    }

    private static void AssertHas(JsonElement obj, string prop)
    {
        Assert.True(obj.TryGetProperty(prop, out _), $"Missing log property: {prop}");
    }
}

