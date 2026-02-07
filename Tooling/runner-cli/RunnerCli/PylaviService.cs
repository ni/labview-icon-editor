using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace RunnerCli;

public sealed record PylaviScanOptions(
    string RepoRoot,
    string ConfigPath,
    string Label,
    string? LabviewInput,
    bool SkipVersionGate,
    bool ReportOnly,
    string? AbsoluteRootsRaw,
    string? LogPath,
    string? OffendersPath,
    bool Quiet,
    bool Json
);

public sealed record PylaviScanResult(
    int ExitCode,
    PylaviOffendersReport? Report,
    string? LogPath,
    string? OffendersPath
);

public static class PylaviService
{
    private static readonly Regex PathLineRegex = new(@"^[\s]*(/|[A-Za-z]:|\\\\)", RegexOptions.Compiled);

    public static PylaviScanResult Run(PylaviScanOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.RepoRoot))
        {
            throw new ArgumentException("RepoRoot is required.", nameof(options));
        }

        var configPath = ResolveConfigPath(options.RepoRoot, options.ConfigPath);
        if (!File.Exists(configPath))
        {
            throw new FileNotFoundException($"vi_validate config not found: {configPath}");
        }

        string? numericVersion = null;
        if (!options.SkipVersionGate)
        {
            var info = LabVIEWVersionService.GetVersionInfo(options.LabviewInput, options.RepoRoot);
            numericVersion = info.NumericVersion;
        }

        var args = new List<string> { "--config", configPath };
        if (!options.SkipVersionGate && !string.IsNullOrWhiteSpace(numericVersion))
        {
            args.Add("--eq");
            args.Add(numericVersion);
        }

        var commandLine = $"vi_validate {string.Join(' ', args.Select(QuoteIfNeeded))}";
        Console.WriteLine($"vi_validate command ({options.Label}): {commandLine}");

        var (exitCode, lines) = RunProcess("vi_validate", args);

        var roots = ParseRoots(options.AbsoluteRootsRaw);
        var redaction = BuildRedactionRegex(roots);
        var redactedLines = redaction is null ? lines : lines.Select(l => Redact(l, redaction)).ToList();

        if (!string.IsNullOrWhiteSpace(options.LogPath))
        {
            var logDir = Path.GetDirectoryName(options.LogPath);
            if (!string.IsNullOrWhiteSpace(logDir) && !Directory.Exists(logDir))
            {
                Directory.CreateDirectory(logDir);
            }
            File.WriteAllLines(options.LogPath, redactedLines, Encoding.UTF8);
        }

        var failDetails = ExtractFailDetails(lines);
        EmitWarnings(options.Label, failDetails, redaction, options.Quiet);
        EmitAbsoluteRootWarnings(options.Label, roots, lines, redaction, options.Quiet);

        var report = BuildOffendersReport(options.Label, roots, failDetails, redaction);
        if (!string.IsNullOrWhiteSpace(options.OffendersPath))
        {
            var offendersDir = Path.GetDirectoryName(options.OffendersPath);
            if (!string.IsNullOrWhiteSpace(offendersDir) && !Directory.Exists(offendersDir))
            {
                Directory.CreateDirectory(offendersDir);
            }
            var json = JsonSerializer.Serialize(report, RunnerCliJsonContext.Default.PylaviOffendersReport);
            File.WriteAllText(options.OffendersPath, json);
        }

        if (!options.Quiet && options.Json)
        {
            var summary = new PylaviScanSummary
            {
                Label = report.Label,
                TotalFails = report.TotalFails,
                ConfiguredRootCount = report.ConfiguredRootCount,
                HasFindings = report.TotalFails > 0,
                OffendersPath = options.OffendersPath,
                LogPath = options.LogPath
            };
            Console.WriteLine(JsonSerializer.Serialize(summary, RunnerCliJsonContext.Default.PylaviScanSummary));
        }
        else if (!options.Quiet)
        {
            Console.WriteLine($"Total FAILs: {report.TotalFails}");
        }

        var finalExit = exitCode;
        if (options.ReportOnly && finalExit != 0)
        {
            Console.WriteLine($"vi_validate exit code {finalExit} (report-only, {options.Label})");
            finalExit = 0;
        }

        return new PylaviScanResult(finalExit, report, options.LogPath, options.OffendersPath);
    }

    private static string ResolveConfigPath(string repoRoot, string configPath)
    {
        if (string.IsNullOrWhiteSpace(configPath))
        {
            throw new ArgumentException("Config path is required.", nameof(configPath));
        }
        return Path.IsPathRooted(configPath) ? configPath : Path.Combine(repoRoot, configPath);
    }

    private static string QuoteIfNeeded(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return "\"\"";
        return value.Contains(' ') ? $"\"{value}\"" : value;
    }

    private static (int ExitCode, List<string> Lines) RunProcess(string fileName, List<string> args)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        foreach (var arg in args)
        {
            psi.ArgumentList.Add(arg);
        }

        using var process = Process.Start(psi);
        if (process is null)
        {
            throw new InvalidOperationException("Failed to start vi_validate.");
        }

        var outputTask = process.StandardOutput.ReadToEndAsync();
        var errorTask = process.StandardError.ReadToEndAsync();
        process.WaitForExit();
        var output = outputTask.GetAwaiter().GetResult();
        var error = errorTask.GetAwaiter().GetResult();

        var lines = new List<string>();
        if (!string.IsNullOrWhiteSpace(output))
        {
            lines.AddRange(SplitLines(output));
        }
        if (!string.IsNullOrWhiteSpace(error))
        {
            lines.AddRange(SplitLines(error));
        }

        return (process.ExitCode, lines);
    }

    private static List<string> SplitLines(string value)
    {
        return value
            .Split(new[] { "\r\n", "\n", "\r" }, StringSplitOptions.RemoveEmptyEntries)
            .Select(line => line.TrimEnd())
            .ToList();
    }

    private static List<string> ParseRoots(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return new List<string>();
        return raw
            .Split(';', StringSplitOptions.RemoveEmptyEntries)
            .Select(r => r.Trim())
            .Where(r => r.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static Regex? BuildRedactionRegex(List<string> roots)
    {
        if (roots.Count == 0)
            return null;
        var pattern = string.Join("|", roots.Select(Regex.Escape));
        return new Regex(pattern, RegexOptions.IgnoreCase | RegexOptions.Compiled);
    }

    private static string Redact(string value, Regex? regex)
    {
        if (regex is null)
            return value;
        return regex.Replace(value, "<redacted>");
    }

    private static List<(string Reason, string? File)> ExtractFailDetails(List<string> lines)
    {
        var details = new List<(string Reason, string? File)>();
        for (var i = 0; i < lines.Count; i++)
        {
            var line = lines[i];
            if (line.StartsWith("FAIL:", StringComparison.OrdinalIgnoreCase))
            {
                string? pathValue = null;
                if (i + 1 < lines.Count && PathLineRegex.IsMatch(lines[i + 1]))
                {
                    pathValue = lines[i + 1].Trim();
                }
                details.Add((line, pathValue));
            }
        }
        return details;
    }

    private static void EmitWarnings(string label, List<(string Reason, string? File)> details, Regex? redaction, bool quiet)
    {
        if (quiet)
            return;

        foreach (var detail in details)
        {
            var message = detail.Reason;
            if (!string.IsNullOrWhiteSpace(detail.File))
            {
                message = $"{message} | {detail.File}";
            }
            message = Redact(message, redaction);
            WriteWarning(label, message);
        }
    }

    private static void EmitAbsoluteRootWarnings(string label, List<string> roots, List<string> lines, Regex? redaction, bool quiet)
    {
        if (quiet || roots.Count == 0 || lines.Count == 0)
            return;

        var hits = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var root in roots)
        {
            foreach (var line in lines)
            {
                if (line.Contains(root, StringComparison.OrdinalIgnoreCase))
                {
                    hits.Add(line);
                }
            }
        }

        if (hits.Count == 0)
            return;

        WriteWarning(label, $"Absolute linker paths referencing configured roots detected (count: {hits.Count}).");
        var preview = hits.Take(20).ToList();
        foreach (var hit in preview)
        {
            WriteWarning(label, Redact(hit, redaction));
        }
        if (hits.Count > preview.Count)
        {
            WriteWarning(label, $"... {hits.Count - preview.Count} more");
        }
    }

    private static PylaviOffendersReport BuildOffendersReport(
        string label,
        List<string> roots,
        List<(string Reason, string? File)> details,
        Regex? redaction
    )
    {
        var offenderCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var offenderReasons = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var absoluteCounts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        foreach (var detail in details)
        {
            var key = !string.IsNullOrWhiteSpace(detail.File) ? detail.File! : detail.Reason;
            if (!offenderCounts.ContainsKey(key))
            {
                offenderCounts[key] = 0;
                offenderReasons[key] = detail.Reason;
            }
            offenderCounts[key]++;

            var isAbsolute = false;
            if (!string.IsNullOrWhiteSpace(detail.File) && roots.Count > 0)
            {
                isAbsolute = roots.Any(root => detail.File!.Contains(root, StringComparison.OrdinalIgnoreCase));
            }
            if (!isAbsolute && detail.Reason.Contains("Absolute linker path found", StringComparison.OrdinalIgnoreCase))
            {
                isAbsolute = true;
            }
            if (isAbsolute)
            {
                if (!absoluteCounts.ContainsKey(key))
                {
                    absoluteCounts[key] = 0;
                }
                absoluteCounts[key]++;
            }
        }

        var topOffenders = offenderCounts
            .OrderByDescending(kv => kv.Value)
            .Take(20)
            .Select(kv => new PylaviOffenderEntry
            {
                Item = Redact(kv.Key, redaction),
                Count = kv.Value,
                SampleReason = Redact(offenderReasons[kv.Key], redaction)
            })
            .ToList();

        var topAbsolute = absoluteCounts
            .OrderByDescending(kv => kv.Value)
            .Take(20)
            .Select(kv => new PylaviOffenderEntry
            {
                Item = Redact(kv.Key, redaction),
                Count = kv.Value
            })
            .ToList();

        var report = new PylaviOffendersReport
        {
            Label = string.IsNullOrWhiteSpace(label) ? "pylavi" : label,
            GeneratedUtc = DateTime.UtcNow.ToString("o"),
            TotalFails = details.Count,
            ConfiguredRoots = roots.Count > 0 ? "<redacted>" : string.Empty,
            ConfiguredRootCount = roots.Count,
            TopOffenders = topOffenders,
            TopAbsoluteOffenders = topAbsolute
        };

        var sha = Environment.GetEnvironmentVariable("GITHUB_SHA");
        if (!string.IsNullOrWhiteSpace(sha))
        {
            report.SourceSha = sha.Trim();
        }

        return report;
    }

    private static void WriteWarning(string label, string message)
    {
        var useGitHub = string.Equals(Environment.GetEnvironmentVariable("GITHUB_ACTIONS"), "true", StringComparison.OrdinalIgnoreCase);
        if (useGitHub)
        {
            Console.WriteLine($"::warning::[{label}] {message}");
        }
        else
        {
            Console.WriteLine($"WARNING: [{label}] {message}");
        }
    }

}
