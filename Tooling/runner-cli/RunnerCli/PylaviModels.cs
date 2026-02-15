using System.Text.Json.Serialization;

namespace RunnerCli;

public sealed class PylaviOffenderEntry
{
    [JsonPropertyName("item")]
    public string Item { get; set; } = string.Empty;

    [JsonPropertyName("count")]
    public int Count { get; set; }

    [JsonPropertyName("sample_reason")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? SampleReason { get; set; }
}

public sealed class PylaviOffendersReport
{
    [JsonPropertyName("label")]
    public string Label { get; set; } = string.Empty;

    [JsonPropertyName("generated_utc")]
    public string GeneratedUtc { get; set; } = string.Empty;

    [JsonPropertyName("source_sha")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? SourceSha { get; set; }

    [JsonPropertyName("total_fails")]
    public int TotalFails { get; set; }

    [JsonPropertyName("configured_roots")]
    public string ConfiguredRoots { get; set; } = string.Empty;

    [JsonPropertyName("configured_root_count")]
    public int ConfiguredRootCount { get; set; }

    [JsonPropertyName("top_offenders")]
    public List<PylaviOffenderEntry> TopOffenders { get; set; } = new();

    [JsonPropertyName("top_absolute_offenders")]
    public List<PylaviOffenderEntry> TopAbsoluteOffenders { get; set; } = new();
}

public sealed class PylaviScanSummary
{
    [JsonPropertyName("label")]
    public string Label { get; set; } = string.Empty;

    [JsonPropertyName("total_fails")]
    public int TotalFails { get; set; }

    [JsonPropertyName("configured_root_count")]
    public int ConfiguredRootCount { get; set; }

    [JsonPropertyName("has_findings")]
    public bool HasFindings { get; set; }

    [JsonPropertyName("offenders_path")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? OffendersPath { get; set; }

    [JsonPropertyName("log_path")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? LogPath { get; set; }
}

public sealed class PylaviSummarizeOutput
{
    [JsonPropertyName("label")]
    public string Label { get; set; } = string.Empty;

    [JsonPropertyName("generated_utc")]
    public string GeneratedUtc { get; set; } = string.Empty;

    [JsonPropertyName("total_fails")]
    public int TotalFails { get; set; }

    [JsonPropertyName("configured_root_count")]
    public int ConfiguredRootCount { get; set; }

    [JsonPropertyName("has_findings")]
    public bool HasFindings { get; set; }

    [JsonPropertyName("file")]
    public string File { get; set; } = string.Empty;

    [JsonPropertyName("top_offenders")]
    public List<PylaviOffenderEntry> TopOffenders { get; set; } = new();

    [JsonPropertyName("top_absolute_offenders")]
    public List<PylaviOffenderEntry> TopAbsoluteOffenders { get; set; } = new();

    [JsonPropertyName("source_sha")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? SourceSha { get; set; }

    [JsonPropertyName("baseline_file")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? BaselineFile { get; set; }

    [JsonPropertyName("baseline_total_fails")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? BaselineTotalFails { get; set; }

    [JsonPropertyName("baseline_configured_root_count")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? BaselineConfiguredRootCount { get; set; }

    [JsonPropertyName("baseline_has_findings")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? BaselineHasFindings { get; set; }

    [JsonPropertyName("has_delta")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? HasDelta { get; set; }

    [JsonPropertyName("delta_total_fails")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? DeltaTotalFails { get; set; }

    [JsonPropertyName("delta_offenders")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<PylaviOffenderEntry>? DeltaOffenders { get; set; }

    [JsonPropertyName("delta_absolute_offenders")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<PylaviOffenderEntry>? DeltaAbsoluteOffenders { get; set; }
}
