using System.Text.Json.Serialization;

namespace RunnerCli;

/// <summary>
/// Represents the LVIE runner contract JSON schema.
/// </summary>
public sealed class RunnerContract
{
    [JsonPropertyName("version")]
    public int Version { get; set; } = 1;

    [JsonPropertyName("runner_root")]
    public string RunnerRoot { get; set; } = string.Empty;

    [JsonPropertyName("work_root")]
    public string WorkRoot { get; set; } = string.Empty;

    [JsonPropertyName("worktree_root")]
    public string WorktreeRoot { get; set; } = string.Empty;

    [JsonPropertyName("artifact_root")]
    public string ArtifactRoot { get; set; } = string.Empty;

    [JsonPropertyName("lock_root")]
    public string LockRoot { get; set; } = string.Empty;

    [JsonPropertyName("log_root")]
    public string LogRoot { get; set; } = string.Empty;

    [JsonPropertyName("runner_label")]
    public string RunnerLabel { get; set; } = string.Empty;

    [JsonPropertyName("runner_labels")]
    public List<string> RunnerLabels { get; set; } = new();

    [JsonPropertyName("canonical_runner_label")]
    public string CanonicalRunnerLabel { get; set; } = string.Empty;

    [JsonPropertyName("updated_at_utc")]
    public string UpdatedAtUtc { get; set; } = "0001-01-01T00:00:00Z";

    [JsonPropertyName("created_at_utc")]
    public string CreatedAtUtc { get; set; } = "0001-01-01T00:00:00Z";
}
