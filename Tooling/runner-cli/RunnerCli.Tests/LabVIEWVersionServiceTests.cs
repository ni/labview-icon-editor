using RunnerCli;

namespace RunnerCli.Tests;

public class LabVIEWVersionServiceTests
{
    [Fact]
    public void Parse_accepts_year_only()
    {
        var info = LabVIEWVersionService.Parse("2021");
        Assert.Equal("2021", info.Year);
        Assert.Equal(0, info.MinorRevision);
        Assert.Equal("21.0", info.NumericVersion);
    }

    [Fact]
    public void Parse_accepts_numeric_version()
    {
        var info = LabVIEWVersionService.Parse("21.1");
        Assert.Equal("2021", info.Year);
        Assert.Equal(1, info.MinorRevision);
        Assert.Equal("21.1", info.NumericVersion);
    }

    [Fact]
    public void Parse_rejects_invalid_value()
    {
        Assert.ThrowsAny<Exception>(() => LabVIEWVersionService.Parse("abc"));
    }

    [Fact]
    public void GetVersionInfo_throws_when_repo_missing()
    {
        var temp = Path.Combine(Path.GetTempPath(), $"lvie-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(temp);
        Assert.Throws<FileNotFoundException>(() => LabVIEWVersionService.GetVersionInfo(null, temp));
    }

    [Fact]
    public void GetVersionInfo_throws_on_mismatch()
    {
        var temp = Path.Combine(Path.GetTempPath(), $"lvie-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(temp);
        File.WriteAllText(Path.Combine(temp, ".lvversion"), "2021");

        Assert.ThrowsAny<Exception>(() => LabVIEWVersionService.GetVersionInfo("2022", temp));
    }
}
