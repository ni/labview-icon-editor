using System.Text;
using System.Text.Json;

namespace RunnerCli;

public static class PylaviOffendersService
{
    public static string ResolveReportPath(string repoRoot, string? path, string? label, string? sha)
    {
        if (!string.IsNullOrWhiteSpace(path))
        {
            return Path.GetFullPath(path);
        }

        var logRoot = Path.Combine(repoRoot, "TestResults", "agent-logs");
        if (!string.IsNullOrWhiteSpace(sha) && !string.IsNullOrWhiteSpace(label))
        {
            return Path.Combine(logRoot, $"pylavi-offenders.{label}.{sha}.json");
        }
        if (!string.IsNullOrWhiteSpace(sha))
        {
            return Path.Combine(logRoot, $"pylavi-offenders.{sha}.json");
        }
        if (!string.IsNullOrWhiteSpace(label))
        {
            return Path.Combine(logRoot, $"pylavi-offenders.latest.{label}.json");
        }
        return Path.Combine(logRoot, "pylavi-offenders.latest.json");
    }

    public static string? NormalizeSha(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;
        var trimmed = value.Trim();
        if (trimmed.Length is >= 7 and <= 40 && trimmed.All(Uri.IsHexDigit))
        {
            return trimmed.ToLowerInvariant();
        }
        return null;
    }

    public static string? ResolveShaFromPath(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return null;
        var name = Path.GetFileName(path);
        var parts = name.Split('.', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length >= 3 && string.Equals(parts[0], "pylavi-offenders", StringComparison.OrdinalIgnoreCase))
        {
            var last = parts[^2] == "json" ? parts[^3] : parts[^2];
            var normalized = NormalizeSha(last);
            if (!string.IsNullOrWhiteSpace(normalized))
                return normalized;
        }

        if (parts.Length >= 2 && string.Equals(parts[0], "pylavi-offenders", StringComparison.OrdinalIgnoreCase))
        {
            var maybeSha = parts[^2];
            var normalized = NormalizeSha(maybeSha);
            if (!string.IsNullOrWhiteSpace(normalized))
                return normalized;
        }

        return null;
    }

    public static string? ResolveSha(string? provided, string? path, PylaviOffendersReport? report)
    {
        var normalized = NormalizeSha(provided);
        if (!string.IsNullOrWhiteSpace(normalized))
            return normalized;

        var fromPath = ResolveShaFromPath(path);
        if (!string.IsNullOrWhiteSpace(fromPath))
            return fromPath;

        if (report is not null)
        {
            var fromReport = NormalizeSha(report.SourceSha);
            if (!string.IsNullOrWhiteSpace(fromReport))
                return fromReport;
        }

        return null;
    }

    public static PylaviOffendersReport LoadReport(string path)
    {
        var json = File.ReadAllText(path);
        var report = JsonSerializer.Deserialize(json, RunnerCliJsonContext.Default.PylaviOffendersReport);
        if (report is null)
            throw new InvalidOperationException($"Failed to parse report at {path}");
        return report;
    }

    public static void WriteSummary(
        string label,
        PylaviOffendersReport report,
        int top,
        string? shaValue,
        string? summaryPath
    )
    {
        if (string.IsNullOrWhiteSpace(summaryPath))
            return;

        var lines = new List<string>
        {
            "## Pylavi Offenders",
            $"- Label: {label}",
            $"- Generated (UTC): {report.GeneratedUtc}",
            $"- Total FAILs: {report.TotalFails}"
        };
        if (!string.IsNullOrWhiteSpace(shaValue))
        {
            lines.Add($"- Source SHA: {shaValue}");
        }
        lines.Add($"- Configured roots: <redacted> (count: {report.ConfiguredRootCount})");
        lines.Add("");

        if (report.TopOffenders.Count > 0)
        {
            lines.Add("### Top offenders");
            lines.Add("");
            lines.Add("| Item | Count |");
            lines.Add("|---|---:|");
            foreach (var entry in report.TopOffenders.Take(top))
            {
                lines.Add($"| {EscapeMarkdown(entry.Item)} | {entry.Count} |");
            }
            lines.Add("");
        }

        if (report.TopAbsoluteOffenders.Count > 0)
        {
            lines.Add("### Top absolute-path offenders");
            lines.Add("");
            lines.Add("| Item | Count |");
            lines.Add("|---|---:|");
            foreach (var entry in report.TopAbsoluteOffenders.Take(top))
            {
                lines.Add($"| {EscapeMarkdown(entry.Item)} | {entry.Count} |");
            }
            lines.Add("");
        }

        File.AppendAllLines(summaryPath, lines, Encoding.UTF8);
    }

    public static void WriteMachineLines(string file, string label, string? sha, bool hasFindings, int totalFails, int exitCode)
    {
        Console.WriteLine($"PYLAVI_OFFENDERS_FILE={file}");
        Console.WriteLine($"PYLAVI_OFFENDERS_LABEL={label}");
        if (!string.IsNullOrWhiteSpace(sha))
        {
            Console.WriteLine($"PYLAVI_OFFENDERS_SHA={sha}");
        }
        Console.WriteLine($"PYLAVI_OFFENDERS_TOTAL_FAILS={totalFails}");
        Console.WriteLine($"PYLAVI_OFFENDERS_HAS_FINDINGS={hasFindings.ToString().ToLowerInvariant()}");
        Console.WriteLine($"PYLAVI_OFFENDERS_EXIT_CODE={exitCode}");
    }

    public static string EscapeMarkdown(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return string.Empty;
        var safe = value.Replace("\r", " ").Replace("\n", " ");
        safe = safe.Replace("|", "\\|");
        safe = safe.Replace("`", "\\`");
        return safe;
    }

}
