// ModuleIndex: model for telemetry summary output.
namespace XCli.Telemetry.Models;

public sealed class TelemetrySummary
{
    public Dictionary<string, int> Counts { get; init; } = new();
    public Dictionary<string, int> FailureCounts { get; init; } = new();
    public Dictionary<string, long> DurationsMs { get; init; } = new();
    public int Total { get; init; }
    public int TotalFailures { get; init; }
    public DateTime GeneratedAtUtc { get; init; } = DateTime.UtcNow;
}
