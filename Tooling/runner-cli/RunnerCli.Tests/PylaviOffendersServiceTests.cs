using RunnerCli;

namespace RunnerCli.Tests;

public class PylaviOffendersServiceTests
{
    [Fact]
    public void ResolveReportPath_prefers_sha_and_label()
    {
        var repoRoot = Path.Combine(Path.GetTempPath(), "lvie-repo");
        var path = PylaviOffendersService.ResolveReportPath(repoRoot, null, "strict", "abcdef1");
        Assert.EndsWith("pylavi-offenders.strict.abcdef1.json", path.Replace('\\', '/'));
    }

    [Fact]
    public void ResolveSha_prefers_input_over_report()
    {
        var report = new PylaviOffendersReport { SourceSha = "deadbeef" };
        var sha = PylaviOffendersService.ResolveSha("abc1234", "pylavi-offenders.latest.json", report);
        Assert.Equal("abc1234", sha);
    }

    [Fact]
    public void ResolveSha_uses_report_when_missing()
    {
        var report = new PylaviOffendersReport { SourceSha = "deadbeef" };
        var sha = PylaviOffendersService.ResolveSha(null, "pylavi-offenders.latest.json", report);
        Assert.Equal("deadbeef", sha);
    }
}
