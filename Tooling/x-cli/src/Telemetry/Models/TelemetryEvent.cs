// ModuleIndex: model for telemetry event lines.
namespace XCli.Telemetry.Models;

public sealed class TelemetryEvent
{
    public string Step { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty; // pass|fail
    public long DurationMs { get; init; }
    public long Start { get; init; }
    public long End { get; init; }
    public Dictionary<string, string>? Meta { get; init; }
}
