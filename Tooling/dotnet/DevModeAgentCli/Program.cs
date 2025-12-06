using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

internal static class Program
{
    private record Options(
        string Phrase,
        string RepoPath,
        string SummaryPath,
        bool Execute,
        bool AllowStaleSummary,
        int MaxIntents,
        string? ExpectedVersion,
        bool AckVersionMismatch,
        string PwshPath);

    private record Intent(string Mode, string Year, string Bitness, bool ForceRequested);

    private record SummaryEntry(
        string? bitness,
        string? expected_path,
        string? current_path,
        string? post_path,
        string? status,
        string? message,
        bool? available);

    private record Plan
    {
        public string Mode { get; init; } = string.Empty;
        public string Year { get; init; } = string.Empty;
        public string Bitness { get; init; } = string.Empty;
        public List<string> BitnessTargets { get; init; } = new();
        public bool ForceRequested { get; init; }
        public bool ForceApplied { get; init; }
        public string Action { get; set; } = "pending"; // pending | skip | blocked | failed | completed
        public string Reason { get; set; } = string.Empty;
        public int? BinderExitCode { get; set; }
        public string? BinderError { get; set; }
        public string SummaryPath { get; init; } = string.Empty;
        public string RepositoryPath { get; init; } = string.Empty;
    }

    private static int Main(string[] args)
    {
        if (args.Length > 0 && string.Equals(args[0], "requirements-summary", StringComparison.OrdinalIgnoreCase))
        {
            return RunRequirementsSummarySubcommand(args.Skip(1).ToArray());
        }

        if (args.Any(a => a.Equals("--print-provenance", StringComparison.OrdinalIgnoreCase)))
        {
            PrintProvenance();
            return 0;
        }

        var parse = ParseArgs(args);
        if (parse.Error != null)
        {
            Console.Error.WriteLine(parse.Error);
            PrintUsage();
            return 1;
        }

        var options = parse.Value!;
        var intents = ParseIntents(options.Phrase, options.MaxIntents);
        if (intents.Count == 0)
        {
            Console.Error.WriteLine("No intents parsed. Ensure phrase starts with /devmode or agent: and includes bind|unbind YEAR BITNESS-bit.");
            return 1;
        }

        var summaryEntries = LoadSummary(options.SummaryPath, options.AllowStaleSummary, out var summaryError);
        if (summaryError != null)
        {
            Console.Error.WriteLine(summaryError);
            return 1;
        }

        var plans = BuildPlans(intents, summaryEntries, options);
        var hints = BuildHints(intents, summaryEntries);
        var blocked = plans.Where(p => p.Action == "blocked").ToList();
        if (blocked.Count > 0)
        {
            Console.Error.WriteLine("Blocked intents:");
            foreach (var b in blocked)
            {
                Console.Error.WriteLine($"- {b.Mode} {b.Year} {b.Bitness}-bit: {b.Reason}");
            }
        }
        if (hints.Count > 0)
        {
            Console.Error.WriteLine("Hints:");
            foreach (var h in hints.Distinct())
            {
                Console.Error.WriteLine($"- {h}");
            }
        }

        if (options.Execute)
        {
            var binderPath = Path.Combine(options.RepoPath, "scripts", "bind-development-mode", "BindDevelopmentMode.ps1");
            if (!File.Exists(binderPath))
            {
                binderPath = Path.Combine(options.RepoPath, ".github", "actions", "bind-development-mode", "BindDevelopmentMode.ps1");
            }
            if (!File.Exists(binderPath))
            {
                Console.Error.WriteLine($"Binder script not found at {binderPath}");
                return 1;
            }

            foreach (var plan in plans.Where(p => p.Action == "pending"))
            {
                var exit = RunBinder(options.PwshPath, binderPath, options.RepoPath, plan);
                plan.BinderExitCode = exit.ExitCode;
                plan.BinderError = exit.Error;
                plan.Action = exit.ExitCode == 0 ? "completed" : "failed";
                if (!string.IsNullOrWhiteSpace(exit.Error))
                {
                    plan.Reason = string.IsNullOrWhiteSpace(plan.Reason)
                        ? exit.Error
                        : $"{plan.Reason}; {exit.Error}";
                }
            }
        }

        var output = JsonSerializer.Serialize(plans, new JsonSerializerOptions
        {
            WriteIndented = true
        });
        Console.WriteLine(output);

        var exitCode = blocked.Count > 0 || plans.Any(p => p.Action == "failed") ? 1 : 0;
        return exitCode;
    }

    private static (Options? Value, string? Error) ParseArgs(string[] args)
    {
        string? phrase = null;
        string repo = ".";
        string? summary = null;
        bool execute = false;
        bool allowStale = false;
        int maxIntents = 3;
        string? expectedVersion = null;
        bool ackVersionMismatch = false;
        string pwsh = "pwsh";

        for (int i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            switch (arg)
            {
                case "--phrase":
                    phrase = TakeNext(args, ref i);
                    break;
                case "--repo":
                    repo = TakeNext(args, ref i) ?? repo;
                    break;
                case "--summary":
                    summary = TakeNext(args, ref i);
                    break;
                case "--execute":
                    execute = true;
                    break;
                case "--allow-stale-summary":
                    allowStale = true;
                    break;
                case "--max-intents":
                    var m = TakeNext(args, ref i);
                    if (int.TryParse(m, out var parsed))
                    {
                        maxIntents = Math.Max(1, parsed);
                    }
                    else
                    {
                        return (null, "Invalid --max-intents");
                    }
                    break;
                case "--expected-version":
                    expectedVersion = TakeNext(args, ref i);
                    break;
                case "--ack-version-mismatch":
                    ackVersionMismatch = true;
                    break;
                case "--pwsh":
                    pwsh = TakeNext(args, ref i) ?? pwsh;
                    break;
                case "--help":
                case "-h":
                    return (null, null);
                default:
                    return (null, $"Unknown argument: {arg}");
            }
        }

        if (phrase == null)
        {
            return (null, "Missing required --phrase.");
        }

        var repoFull = Path.GetFullPath(repo);
        var summaryPath = summary ?? Path.Combine(repoFull, "reports", "dev-mode-bind.json");

        return (new Options(
            Phrase: phrase,
            RepoPath: repoFull,
            SummaryPath: summaryPath,
            Execute: execute,
            AllowStaleSummary: allowStale,
            MaxIntents: maxIntents,
            ExpectedVersion: expectedVersion,
            AckVersionMismatch: ackVersionMismatch,
            PwshPath: pwsh), null);
    }

    private static string? TakeNext(string[] args, ref int index)
    {
        if (index + 1 >= args.Length) return null;
        index++;
        return args[index];
    }

    private static void PrintUsage()
    {
        Console.WriteLine("Usage:");
        Console.WriteLine("  DevModeAgentCli --phrase \"/devmode bind 2021 64-bit force\" [--repo <path>] [--summary <path>] [--execute]");
        Console.WriteLine("  Optional: --allow-stale-summary --max-intents 3 --expected-version 2021 --ack-version-mismatch --pwsh <path>");
        Console.WriteLine();
        Console.WriteLine("Advice:");
        Console.WriteLine("  - Worktrees of the same repo can look like 'OTHER-REPO' tokens; use 'force' if you need to overwrite");
        Console.WriteLine("    a token that points to a prior worktree.");
        Console.WriteLine("  - If you need to change the target LabVIEW year/bitness, update the repo's VIPB accordingly, then run the");
        Console.WriteLine("    VS Code tasks '06 DevMode: Bind (auto)' or '06b DevMode: Unbind (auto)' to refresh LocalHost.LibraryPaths.");
    }

    private static int RunRequirementsSummarySubcommand(string[] args)
    {
        var repoRoot = FindRepoRoot();
        var script = Path.Combine(repoRoot, "scripts", "run-requirements-summary-task.ps1");
        if (!File.Exists(script))
        {
            Console.Error.WriteLine($"Script not found: {script}");
            return 1;
        }

        var psi = new ProcessStartInfo
        {
            FileName = "pwsh",
            ArgumentList = { "-NoProfile", "-File", script },
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        var process = Process.Start(psi);
        if (process == null)
        {
            Console.Error.WriteLine("Failed to start pwsh process.");
            return 1;
        }

        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (!string.IsNullOrWhiteSpace(stdout))
        {
            Console.WriteLine(stdout);
        }

        if (!string.IsNullOrWhiteSpace(stderr))
        {
            Console.Error.WriteLine(stderr);
        }

        return process.ExitCode;
    }

    private static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
        while (dir != null)
        {
            if (Directory.Exists(Path.Combine(dir.FullName, ".git")))
            {
                return dir.FullName;
            }
            dir = dir.Parent;
        }
        throw new InvalidOperationException("Repository root not found.");
    }

    private static List<Intent> ParseIntents(string phrase, int maxIntents)
    {
        var intents = new List<Intent>();
        var prefix = Regex.Match(phrase, @"^(?is)\s*(/devmode|agent:)\s+(?<rest>.+)$");
        if (!prefix.Success) return intents;

        var rest = prefix.Groups["rest"].Value;
        var segments = Regex.Split(rest, @"(?i)\band\b|,")
            .Where(s => !string.IsNullOrWhiteSpace(s));

        foreach (var segment in segments)
        {
            var match = Regex.Match(segment, @"(?i)\b(?<mode>bind|unbind)\s+(?<year>20\d{2})\s+(?<bitness>32|64|both)(?:[ -]?bit)?\b");
            if (!match.Success) continue;

            var forceRequested = Regex.IsMatch(segment, @"(?i)\b(force|overwrite)\b");
            intents.Add(new Intent(
                match.Groups["mode"].Value.ToLowerInvariant(),
                match.Groups["year"].Value,
                match.Groups["bitness"].Value.ToLowerInvariant(),
                forceRequested));

            if (intents.Count >= maxIntents) break;
        }
        return intents;
    }

    private static List<SummaryEntry> LoadSummary(string path, bool allowStale, out string? error)
    {
        error = null;
        if (!File.Exists(path))
        {
            if (allowStale)
            {
                return new List<SummaryEntry>();
            }
            error = $"Summary file not found at {path}. Pass --allow-stale-summary to proceed without it.";
            return new List<SummaryEntry>();
        }

        try
        {
            var raw = File.ReadAllText(path, Encoding.UTF8);
            var entries = JsonSerializer.Deserialize<List<SummaryEntry>>(raw, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
            return entries ?? new List<SummaryEntry>();
        }
        catch (Exception ex)
        {
            if (allowStale)
            {
                Console.Error.WriteLine($"Failed to read summary {path}: {ex.Message}; proceeding with empty summary (--allow-stale-summary).");
                return new List<SummaryEntry>();
            }
            error = $"Failed to read summary {path}: {ex.Message}";
            return new List<SummaryEntry>();
        }
    }

    private static List<Plan> BuildPlans(IEnumerable<Intent> intents, IEnumerable<SummaryEntry> summary, Options options)
    {
        var plans = new List<Plan>();
        foreach (var intent in intents)
        {
            var bitnessTargets = intent.Bitness == "both"
                ? new List<string> { "32", "64" }
                : new List<string> { intent.Bitness };

            var blocked = false;
            var reasons = new List<string>();
            var skipCount = 0;

            foreach (var bit in bitnessTargets)
            {
                var entry = summary.FirstOrDefault(e => string.Equals(e.bitness, bit, StringComparison.OrdinalIgnoreCase));
                var current = entry?.current_path;
                var expected = entry?.expected_path;
                var status = entry?.status;
                var message = entry?.message;

                var repoPath = NormalizePath(options.RepoPath);
                var currentMatchesRepo = !string.IsNullOrWhiteSpace(current) && PathEquals(current, repoPath);
                var currentPointsElsewhere = !string.IsNullOrWhiteSpace(current) && !PathEquals(current, repoPath);
                var expectedMismatch = !string.IsNullOrWhiteSpace(expected) && !PathEquals(expected!, repoPath);
                var iniMissing = string.Equals(status, "skip", StringComparison.OrdinalIgnoreCase) && message != null && message.Contains("not found", StringComparison.OrdinalIgnoreCase);

                if (expectedMismatch)
                {
                    blocked = true;
                    reasons.Add($"bitness {bit} expected_path {expected} does not match repo {repoPath}");
                    continue;
                }

                if (iniMissing)
                {
                    blocked = true;
                    reasons.Add($"bitness {bit} LabVIEW.ini missing; install or fix INI before running");
                    continue;
                }

                if (!string.IsNullOrWhiteSpace(options.ExpectedVersion) &&
                    !string.Equals(options.ExpectedVersion, intent.Year, StringComparison.OrdinalIgnoreCase) &&
                    !options.AckVersionMismatch)
                {
                    blocked = true;
                    reasons.Add($"intent year {intent.Year} differs from expected version {options.ExpectedVersion}; rerun with --ack-version-mismatch to proceed");
                    continue;
                }

                if (intent.Mode == "bind")
                {
                    if (currentMatchesRepo)
                    {
                        skipCount++;
                        reasons.Add($"bitness {bit} already bound");
                    }
                    else if (currentPointsElsewhere && !intent.ForceRequested)
                    {
                        blocked = true;
                        reasons.Add($"bitness {bit} points to {current}; requires Force");
                    }
                }
                else // unbind
                {
                    if (currentPointsElsewhere && !intent.ForceRequested)
                    {
                        blocked = true;
                        reasons.Add($"bitness {bit} points to {current}; requires Force");
                    }
                    else if (string.IsNullOrWhiteSpace(current))
                    {
                        skipCount++;
                        reasons.Add($"bitness {bit} already unbound or missing");
                    }
                }
            }

            var action = "pending";
            if (blocked) action = "blocked";
            else if (skipCount == bitnessTargets.Count) action = "skip";

            plans.Add(new Plan
            {
                Mode = intent.Mode,
                Year = intent.Year,
                Bitness = intent.Bitness,
                BitnessTargets = bitnessTargets,
                ForceRequested = intent.ForceRequested,
                ForceApplied = intent.ForceRequested,
                Action = action,
                Reason = string.Join("; ", reasons.Where(r => !string.IsNullOrWhiteSpace(r))),
                SummaryPath = options.SummaryPath,
                RepositoryPath = options.RepoPath
            });
        }

        return plans;
    }

    private static List<string> BuildHints(IEnumerable<Intent> intents, IEnumerable<SummaryEntry> summary)
    {
        var hints = new List<string>();
        foreach (var intent in intents)
        {
            var bitnessTargets = intent.Bitness == "both"
                ? new List<string> { "32", "64" }
                : new List<string> { intent.Bitness };

            foreach (var bit in bitnessTargets)
            {
                var entry = summary.FirstOrDefault(e => string.Equals(e.bitness, bit, StringComparison.OrdinalIgnoreCase));
                if (entry == null) { continue; }

                // No LocalHost.LibraryPaths entry recorded for this bitness/version (tagged as NONE in script output).
                var noToken = string.IsNullOrWhiteSpace(entry.current_path) &&
                              string.IsNullOrWhiteSpace(entry.post_path) &&
                              !string.Equals(entry.status, "fail", StringComparison.OrdinalIgnoreCase) &&
                              (entry.available ?? true);
                if (noToken)
                {
                    hints.Add($"LabVIEW {intent.Year} ({bit}-bit) has no LocalHost.LibraryPaths entry; run dev-mode bind for that bitness to populate the INI token.");
                }
            }
        }
        return hints;
    }

    private static (int ExitCode, string? Error) RunBinder(string pwshPath, string binderPath, string repoPath, Plan plan)
    {
        var args = new List<string>
        {
            "-NoProfile",
            "-File",
            Quote(binderPath),
            "-RepositoryPath", Quote(repoPath),
            "-Mode", plan.Mode,
            "-Bitness", plan.Bitness
        };
        if (plan.ForceApplied)
        {
            args.Add("-Force");
        }

        var psi = new ProcessStartInfo
        {
            FileName = pwshPath,
            ArgumentList = { },
            RedirectStandardError = true,
            RedirectStandardOutput = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        foreach (var a in args)
        {
            psi.ArgumentList.Add(a);
        }

        var process = Process.Start(psi);
        if (process == null)
        {
            return (-1, "Failed to start PowerShell process");
        }

        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        var error = process.ExitCode != 0
            ? $"Binder exited {process.ExitCode}. Stdout: {stdout}. Stderr: {stderr}"
            : null;
        return (process.ExitCode, error);
    }

    private static string Quote(string value) => value.Contains(' ') ? $"\"{value}\"" : value;

    private static string NormalizePath(string path) => Path.GetFullPath(path.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));

    private static bool PathEquals(string a, string b) =>
        string.Equals(NormalizePath(a), NormalizePath(b), StringComparison.OrdinalIgnoreCase);

    private static void PrintProvenance()
    {
        var exePath = string.Empty;
        try { exePath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty; }
        catch { exePath = Environment.GetCommandLineArgs().FirstOrDefault() ?? string.Empty; }
        if (string.IsNullOrWhiteSpace(exePath))
        {
            exePath = "DevModeAgentCli";
        }
        var sha = GetGitSha();
        var rid = System.Runtime.InteropServices.RuntimeInformation.RuntimeIdentifier;
        var repoEnv = Environment.GetEnvironmentVariable("DEVMODE_REPO_PATH") ?? string.Empty;
        var envTier = Environment.GetEnvironmentVariable("PROVENANCE_TIER");
        var envCacheKey = Environment.GetEnvironmentVariable("PROVENANCE_CACHEKEY");
        var tier = !string.IsNullOrWhiteSpace(envTier) ? envTier : InferTierFromPath(exePath);
        var cacheKey = !string.IsNullOrWhiteSpace(envCacheKey) ? envCacheKey : $"DevModeAgentCli/{sha}/{rid}";

        Console.WriteLine($"cli=DevModeAgentCli");
        Console.WriteLine($"path={exePath}");
        Console.WriteLine($"cacheKey={cacheKey}");
        Console.WriteLine($"rid={rid}");
        Console.WriteLine($"tier={tier}");
        if (!string.IsNullOrWhiteSpace(repoEnv))
        {
            Console.WriteLine($"repo={repoEnv}");
        }
    }

    private static string InferTierFromPath(string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return "unknown";
        var lowered = path.Replace('\\', '/').ToLowerInvariant();
        if (lowered.Contains("/tooling-cache/")) return "cache";
        if (lowered.Contains("/tooling/dotnet/")) return "worktree";
        return "unknown";
    }

    private static string GetGitSha()
    {
        try
        {
            var psi = new ProcessStartInfo("git", "rev-parse HEAD")
            {
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using var p = Process.Start(psi);
            if (p == null) return "unknown";
            var stdout = p.StandardOutput.ReadToEnd().Trim();
            p.WaitForExit(2000);
            return string.IsNullOrWhiteSpace(stdout) ? "unknown" : stdout;
        }
        catch
        {
            return "unknown";
        }
    }
}
