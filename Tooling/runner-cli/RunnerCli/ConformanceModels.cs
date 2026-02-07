using System.Text.Json.Serialization;

namespace RunnerCli;

public sealed class RunnerCliManifest
{
    [JsonPropertyName("spec_document_id")]
    public string SpecDocumentId { get; set; } = "LVIE-RC-REQ-v5";

    [JsonPropertyName("spec_version")]
    public string SpecVersion { get; set; } = "v5.1";

    [JsonPropertyName("supported_commands")]
    public List<string> SupportedCommands { get; set; } = new();

    [JsonPropertyName("supported_profiles")]
    public List<string> SupportedProfiles { get; set; } = new();

    [JsonPropertyName("build_version")]
    public string BuildVersion { get; set; } = string.Empty;

    [JsonPropertyName("generated_utc")]
    public string GeneratedUtc { get; set; } = string.Empty;
}

public sealed class ConformanceCheckSummary
{
    [JsonPropertyName("total")]
    public int Total { get; set; }

    [JsonPropertyName("pass")]
    public int Pass { get; set; }

    [JsonPropertyName("warn")]
    public int Warn { get; set; }

    [JsonPropertyName("fail")]
    public int Fail { get; set; }
}

public sealed class ConformanceCheckEntry
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = string.Empty;

    [JsonPropertyName("severity")]
    public string Severity { get; set; } = string.Empty;

    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;

    [JsonPropertyName("evidence")]
    public string Evidence { get; set; } = string.Empty;
}

public sealed class ConformanceCheckResult
{
    [JsonPropertyName("profile")]
    public string Profile { get; set; } = string.Empty;

    [JsonPropertyName("generated_utc")]
    public string GeneratedUtc { get; set; } = string.Empty;

    [JsonPropertyName("summary")]
    public ConformanceCheckSummary Summary { get; set; } = new();

    [JsonPropertyName("checks")]
    public List<ConformanceCheckEntry> Checks { get; set; } = new();
}
