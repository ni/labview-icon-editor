using System.Text.Json;
using RunnerCli;

namespace RunnerCli.Tests;

public class PylaviJsonContextTests
{
    [Fact]
    public void PylaviScanSummary_serializes_expected_properties_and_omits_nulls()
    {
        var summary = new PylaviScanSummary
        {
            Label = "pylavi",
            TotalFails = 2,
            ConfiguredRootCount = 1,
            HasFindings = true,
            OffendersPath = null,
            LogPath = null
        };

        var json = JsonSerializer.Serialize(summary, RunnerCliJsonContext.Default.PylaviScanSummary);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("pylavi", root.GetProperty("label").GetString());
        Assert.Equal(2, root.GetProperty("total_fails").GetInt32());
        Assert.Equal(1, root.GetProperty("configured_root_count").GetInt32());
        Assert.True(root.GetProperty("has_findings").GetBoolean());
        Assert.False(root.TryGetProperty("offenders_path", out _));
        Assert.False(root.TryGetProperty("log_path", out _));
    }

    [Fact]
    public void PylaviScanSummary_serializes_paths_when_provided()
    {
        var summary = new PylaviScanSummary
        {
            Label = "pylavi",
            TotalFails = 0,
            ConfiguredRootCount = 0,
            HasFindings = false,
            OffendersPath = "TestResults/agent-logs/offenders.json",
            LogPath = "TestResults/agent-logs/vi_validate.log"
        };

        var json = JsonSerializer.Serialize(summary, RunnerCliJsonContext.Default.PylaviScanSummary);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("TestResults/agent-logs/offenders.json", root.GetProperty("offenders_path").GetString());
        Assert.Equal("TestResults/agent-logs/vi_validate.log", root.GetProperty("log_path").GetString());
    }

    [Fact]
    public void PylaviSummarizeOutput_serializes_expected_payload()
    {
        var output = new PylaviSummarizeOutput
        {
            Label = "strict",
            GeneratedUtc = "2026-02-06T12:00:00Z",
            TotalFails = 3,
            ConfiguredRootCount = 2,
            HasFindings = true,
            File = "TestResults/agent-logs/pylavi-offenders.latest.json",
            SourceSha = "deadbeef",
            TopOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "foo.vi", Count = 2 }
            },
            TopAbsoluteOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "C:\\Users\\DevUser\\Projects\\bar.vi", Count = 1 }
            }
        };

        var json = JsonSerializer.Serialize(output, RunnerCliJsonContext.Default.PylaviSummarizeOutput);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("strict", root.GetProperty("label").GetString());
        Assert.Equal("2026-02-06T12:00:00Z", root.GetProperty("generated_utc").GetString());
        Assert.Equal(3, root.GetProperty("total_fails").GetInt32());
        Assert.Equal(2, root.GetProperty("configured_root_count").GetInt32());
        Assert.True(root.GetProperty("has_findings").GetBoolean());
        Assert.Equal("TestResults/agent-logs/pylavi-offenders.latest.json", root.GetProperty("file").GetString());
        Assert.Equal("deadbeef", root.GetProperty("source_sha").GetString());

        var topOffenders = root.GetProperty("top_offenders");
        Assert.Equal(1, topOffenders.GetArrayLength());
        Assert.Equal("foo.vi", topOffenders[0].GetProperty("item").GetString());
        Assert.Equal(2, topOffenders[0].GetProperty("count").GetInt32());

        var topAbsolute = root.GetProperty("top_absolute_offenders");
        Assert.Equal(1, topAbsolute.GetArrayLength());
        Assert.Equal("C:\\Users\\DevUser\\Projects\\bar.vi", topAbsolute[0].GetProperty("item").GetString());
        Assert.Equal(1, topAbsolute[0].GetProperty("count").GetInt32());
    }

    [Fact]
    public void PylaviOffendersReport_deserializes_case_insensitive_json()
    {
        var json = """
            {
              "LABEL": "pylavi",
              "GENERATED_UTC": "2026-02-06T12:00:00Z",
              "TOTAL_FAILS": 2,
              "CONFIGURED_ROOTS": "<redacted>",
              "CONFIGURED_ROOT_COUNT": 1,
              "TOP_OFFENDERS": [
                { "ITEM": "foo.vi", "COUNT": 2 }
              ],
              "TOP_ABSOLUTE_OFFENDERS": [
                { "ITEM": "bar.vi", "COUNT": 1 }
              ]
            }
            """;

        var report = JsonSerializer.Deserialize(json, RunnerCliJsonContext.Default.PylaviOffendersReport);
        Assert.NotNull(report);
        Assert.Equal("pylavi", report!.Label);
        Assert.Equal("2026-02-06T12:00:00Z", report.GeneratedUtc);
        Assert.Equal(2, report.TotalFails);
        Assert.Equal(1, report.ConfiguredRootCount);
        Assert.Single(report.TopOffenders);
        Assert.Equal("foo.vi", report.TopOffenders[0].Item);
        Assert.Single(report.TopAbsoluteOffenders);
        Assert.Equal("bar.vi", report.TopAbsoluteOffenders[0].Item);
    }
}
