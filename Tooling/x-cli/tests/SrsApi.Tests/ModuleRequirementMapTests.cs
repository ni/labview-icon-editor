using SrsApi;
using Xunit;
using System.IO;

public class ModuleRequirementMapTests
{
    private static string MapPath => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "docs", "module-srs-map.yaml"));

    [Fact]
    public void FindsRequirementsForNotifications()
    {
        var map = new ModuleRequirementMap(MapPath);
        var reqs = map.GetRequirementsForModule("notifications/send.cs");
        Assert.Contains("FGC-REQ-NOT-001", reqs);
        Assert.Contains("FGC-REQ-NOT-002", reqs);
        Assert.Contains("FGC-REQ-NOT-003", reqs);
        Assert.Contains("FGC-REQ-NOT-004", reqs);
    }

    [Fact]
    public void ReturnsEmptyForUnknownModule()
    {
        var map = new ModuleRequirementMap(MapPath);
        var reqs = map.GetRequirementsForModule("unknown/path/file.cs");
        Assert.Empty(reqs);
    }

    [Fact]
    public void MatchesNestedPaths()
    {
        var map = new ModuleRequirementMap(MapPath);
        var reqs = map.GetRequirementsForModule("src/XCli/Sub/File.cs");
        Assert.Contains("FGC-REQ-CLI-001", reqs);
    }

    [Fact]
    public void RejectsInvalidRequirementId()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "module/:\n  - not-an-id\n");
        Assert.Throws<InvalidDataException>(() => new ModuleRequirementMap(path));
    }
}
