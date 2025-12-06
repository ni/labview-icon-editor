using System.Collections.Generic;

namespace XCli.Srs;

public record Requirement
{
    public string Id { get; init; } = string.Empty;
    public string Section { get; init; } = string.Empty;
    public string Text { get; init; } = string.Empty;
    public string Type { get; init; } = string.Empty;
    public string Priority { get; init; } = string.Empty;
    public Verification Verification { get; init; } = new();
    public string Acceptance { get; init; } = string.Empty;
    public string? Owner { get; init; }
    public string? Phase { get; init; }
    public string? Status { get; init; }
    public Trace? Trace { get; init; }
    public List<string>? Evidence { get; init; }
    public string? Risk { get; init; }
    public List<string>? Constraints { get; init; }
    public string? Notes { get; init; }
    public string? Rationale { get; init; }
    public string? Version { get; init; }
    public string? AcceptanceCriteria { get; init; }
    public string? VerificationDetail { get; init; }
    public string? VerificationLevel { get; init; }
}

public record Verification
{
    public List<string> Methods { get; init; } = new();
    public string Primary { get; init; } = string.Empty;
    public string? Detail { get; init; }
    public string? Level { get; init; }
}

public record Trace
{
    public List<string>? Upstream { get; init; }
    public List<string>? Downstream { get; init; }
}
