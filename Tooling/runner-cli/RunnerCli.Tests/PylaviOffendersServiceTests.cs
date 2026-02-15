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

    [Fact]
    public void SortOffenders_orders_by_count_desc_then_item_asc_case_insensitive()
    {
        var sorted = PylaviOffendersService.SortOffenders(new[]
        {
            new PylaviOffenderEntry { Item = "zeta.vi", Count = 2 },
            new PylaviOffenderEntry { Item = "alpha.vi", Count = 2 },
            new PylaviOffenderEntry { Item = "beta.vi", Count = 2 },
            new PylaviOffenderEntry { Item = "omega.vi", Count = 3 }
        });

        Assert.Collection(sorted,
            item => Assert.Equal("omega.vi", item.Item),
            item => Assert.Equal("alpha.vi", item.Item),
            item => Assert.Equal("beta.vi", item.Item),
            item => Assert.Equal("zeta.vi", item.Item));
    }

    [Fact]
    public void SortOffenders_handles_mixed_case_ties_consistently()
    {
        var sorted = PylaviOffendersService.SortOffenders(new[]
        {
            new PylaviOffenderEntry { Item = "Gamma.vi", Count = 1 },
            new PylaviOffenderEntry { Item = "beta.vi", Count = 1 },
            new PylaviOffenderEntry { Item = "Alpha.vi", Count = 1 }
        });

        Assert.Collection(sorted,
            item => Assert.Equal("Alpha.vi", item.Item),
            item => Assert.Equal("beta.vi", item.Item),
            item => Assert.Equal("Gamma.vi", item.Item));
    }
}
