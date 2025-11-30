using SrsApi;
using Xunit;
using System.IO;

public class SrsRegistryTests
{
    [Fact]
    public void LoadsDocumentsFromDisk()
    {
        var root = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "docs", "srs"));
        var registry = new FileSrsRegistry(root);
        var doc = registry.Get("FGC-REQ-SPEC-001");
        Assert.NotNull(doc);
        Assert.Equal("1.0", doc!.Version);
    }

    [Fact]
    public void ThrowsOnDuplicateIds()
    {
        var root = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            // TEST-REQ-DUP-001 is a placeholder requirement ID used to test duplicate detection.
            File.WriteAllText(Path.Combine(root, "TEST-REQ-DUP-001.md"), "# TEST-REQ-DUP-001\nVersion: 1.0\n");
            File.WriteAllText(Path.Combine(root, "TEST-REQ-DUP-001-copy.md"), "# TEST-REQ-DUP-001\nVersion: 1.0\n");
            Assert.Throws<InvalidDataException>(() => new FileSrsRegistry(root));
        }
        finally
        {
            Directory.Delete(root, true);
        }
    }

    [Fact]
    public void ThrowsOnMissingId()
    {
        var root = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            // TEST-REQ-BAD-ABC is a placeholder requirement ID used to test missing IDs.
            File.WriteAllText(Path.Combine(root, "TEST-REQ-BAD-ABC.md"), "# Missing ID\n");
            Assert.Throws<InvalidDataException>(() => new FileSrsRegistry(root));
        }
        finally
        {
            Directory.Delete(root, true);
        }
    }

    [Fact]
    public void ThrowsOnMissingVersion()
    {
        var root = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            // TEST-REQ-NOVERS-001 is a placeholder requirement ID used to test missing versions.
            var path = Path.Combine(root, "TEST-REQ-NOVERS-001.md");
            File.WriteAllText(path, "# TEST-REQ-NOVERS-001\n");
            Assert.Throws<InvalidDataException>(() => new FileSrsRegistry(root));
        }
        finally
        {
            Directory.Delete(root, true);
        }
    }

    [Fact]
    public void ParsesExplicitVersion()
    {
        var root = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            // TEST-REQ-VERS-001 is a placeholder requirement ID used to test explicit versions.
            var path = Path.Combine(root, "TEST-REQ-VERS-001.md");
            File.WriteAllText(path, "# TEST-REQ-VERS-001\nVersion: 2.7\n");
            var registry = new FileSrsRegistry(root);
            var doc = registry.Get("TEST-REQ-VERS-001");
            Assert.NotNull(doc);
            Assert.Equal("2.7", doc!.Version);
        }
        finally
        {
            Directory.Delete(root, true);
        }
    }
}
