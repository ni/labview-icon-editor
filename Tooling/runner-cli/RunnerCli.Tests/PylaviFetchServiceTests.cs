using System.IO.Compression;
using System.Text;
using RunnerCli;

namespace RunnerCli.Tests;

public class PylaviFetchServiceTests
{
    [Fact]
    public void ExtractOffendersJson_reads_nested_entry()
    {
        var payload = """
            {
              "label": "pylavi",
              "generated_utc": "2026-02-06T12:00:00Z",
              "total_fails": 1,
              "configured_root_count": 0,
              "top_offenders": [],
              "top_absolute_offenders": []
            }
            """;

        var zipBytes = BuildZip(("artifacts/vi_validate_offenders.json", payload));
        var extracted = PylaviFetchService.ExtractOffendersJson(zipBytes);

        Assert.Contains("\"label\"", extracted, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("pylavi", extracted, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ExtractOffendersJson_throws_when_missing()
    {
        var zipBytes = BuildZip(("artifacts/readme.txt", "missing"));

        var ex = Assert.Throws<InvalidOperationException>(() => PylaviFetchService.ExtractOffendersJson(zipBytes));
        Assert.Contains("vi_validate_offenders.json", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    private static byte[] BuildZip(params (string Path, string Content)[] entries)
    {
        using var ms = new MemoryStream();
        using (var archive = new ZipArchive(ms, ZipArchiveMode.Create, true))
        {
            foreach (var entry in entries)
            {
                var zipEntry = archive.CreateEntry(entry.Path, CompressionLevel.Fastest);
                using var stream = zipEntry.Open();
                var bytes = Encoding.UTF8.GetBytes(entry.Content);
                stream.Write(bytes, 0, bytes.Length);
            }
        }
        return ms.ToArray();
    }
}
