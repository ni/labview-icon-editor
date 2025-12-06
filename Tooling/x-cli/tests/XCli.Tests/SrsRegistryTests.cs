using System.IO;
using System.Linq;
using SrsApi;
using Xunit;

public class SrsRegistryTests
{
    private static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (int i = 0; i < 10 && dir is not null; i++, dir = dir.Parent!)
        {
            if (File.Exists(Path.Combine(dir.FullName, "XCli.sln")))
                return dir.FullName;
        }
        throw new DirectoryNotFoundException("Could not locate repository root.");
    }

    [Fact]
    public void RegistryLoadsAndLooksUpIds()
    {
        var root = Path.Combine(FindRepoRoot(), "docs", "srs");
        var registry = new FileSrsRegistry(root);
        var expected = Directory.GetFiles(root, "FGC-REQ-*.md").Length;
        Assert.Equal(expected, registry.Documents.Count);
        Assert.NotNull(registry.Get("FGC-REQ-SPEC-001"));
        Assert.NotNull(registry.Get("FGC-REQ-DEV-001"));
        Assert.NotNull(registry.Get("FGC-REQ-DEV-002"));
        Assert.NotNull(registry.Get("FGC-REQ-DEV-003"));
        Assert.NotNull(registry.Get("FGC-REQ-DEV-004"));
        Assert.NotNull(registry.Get("FGC-REQ-DEV-005"));
        Assert.NotNull(registry.Get("FGC-REQ-DEV-006"));
        Assert.NotNull(registry.Get("FGC-REQ-DEV-007"));
        Assert.NotNull(registry.Get("FGC-REQ-TEL-001"));
        Assert.NotNull(registry.Get("FGC-REQ-NOT-001"));
        Assert.NotNull(registry.Get("FGC-REQ-NOT-002"));
        Assert.NotNull(registry.Get("FGC-REQ-NOT-003"));
        Assert.NotNull(registry.Get("FGC-REQ-NOT-004"));
        Assert.NotNull(registry.Get("FGC-REQ-CI-001"));
        Assert.NotNull(registry.Get("FGC-REQ-CI-019"));
        Assert.NotNull(registry.Get("FGC-REQ-CI-020"));
    }

    [Fact]
    public void DetectsDuplicateIds()
    {
        var dir1 = Directory.CreateTempSubdirectory();
        var dir2 = Directory.CreateTempSubdirectory();
        try
        {
            // TEST-REQ-TEST-001 is a placeholder requirement ID used to test collision detection.
            var id = "TEST-REQ-TEST-001";
            var path1 = Path.Combine(dir1.FullName, $"{id}.md");
            var path2 = Path.Combine(dir2.FullName, $"{id}.md");
            File.WriteAllText(path1, "# one\nVersion: 1.0\n");
            File.WriteAllText(path2, "# two\nVersion: 1.0\n");
            var docs = new ISrsDocument[]
            {
                new SrsDocument(id, "1.0", path1),
                new SrsDocument(id, "1.0", path2)
            };
            var dupes = SrsValidation.FindCollisions(docs).ToList();
            Assert.Contains(id, dupes);
        }
        finally
        {
            dir1.Delete(true);
            dir2.Delete(true);
        }
    }
}
