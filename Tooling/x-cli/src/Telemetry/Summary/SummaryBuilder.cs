// ModuleIndex: builds telemetry summaries from JSONL event streams.
using System.Buffers;
using System.Text.Json;
using XCli.Telemetry.Models;

namespace XCli.Telemetry.Summary;

public static class SummaryBuilder
{
    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web);

    public static TelemetrySummary BuildFromJsonl(string path)
    {
        var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var failures = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var durations = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
        int total = 0;
        int totalFail = 0;
        foreach (var line in File.ReadLines(path))
        {
            var ln = line.Trim();
            if (ln.Length == 0) continue;
            try
            {
                using var doc = JsonDocument.Parse(ln);
                var root = doc.RootElement;
                var step = root.TryGetProperty("step", out var pStep) ? pStep.GetString() ?? string.Empty : string.Empty;
                var status = root.TryGetProperty("status", out var pStatus) ? pStatus.GetString() ?? string.Empty : string.Empty;
                long dur = 0;
                if (root.TryGetProperty("duration_ms", out var pDurMs) && pDurMs.TryGetInt64(out var v1)) dur = v1;
                else if (root.TryGetProperty("durationMs", out var pDurMs2) && pDurMs2.TryGetInt64(out var v2)) dur = v2;
                if (string.IsNullOrEmpty(step)) continue;
                total++;
                counts[step] = counts.TryGetValue(step, out var c) ? c + 1 : 1;
                durations[step] = durations.TryGetValue(step, out var d) ? d + dur : dur;
                var failed = string.Equals(status, "fail", StringComparison.OrdinalIgnoreCase);
                if (failed)
                {
                    totalFail++;
                    failures[step] = failures.TryGetValue(step, out var f) ? f + 1 : 1;
                }
            }
            catch
            {
                // ignore malformed lines to be robust
            }
        }
        return new TelemetrySummary
        {
            Counts = counts,
            FailureCounts = failures,
            DurationsMs = durations,
            Total = total,
            TotalFailures = totalFail,
            GeneratedAtUtc = DateTime.UtcNow
        };
    }

    public static void AppendHistory(string historyPath, TelemetrySummary summary, string? runId = null)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(historyPath))!);
        using var fs = new FileStream(historyPath, FileMode.Append, FileAccess.Write, FileShare.Read);
        using var writer = new StreamWriter(fs, new System.Text.UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        var record = new
        {
            run_id = runId,
            generated_at_utc = summary.GeneratedAtUtc,
            total = summary.Total,
            total_failures = summary.TotalFailures,
            failure_counts = summary.FailureCounts,
            counts = summary.Counts,
            durations_ms = summary.DurationsMs
        };
        writer.WriteLine(JsonSerializer.Serialize(record, JsonOpts));
    }
}
