using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;

internal static class Program
{
    private sealed record Options
    {
        public string RepoPath { get; init; } = ".";
        public string? Branch { get; init; }
        public string? RepoSlugOverride { get; init; }
        public long? RunId { get; init; }
        public bool WaitForHeadRun { get; init; }
        public int WaitTimeoutSeconds { get; init; } = 60;
        public int WaitIntervalSeconds { get; init; } = 5;
        public string StatusFilter { get; init; } = ""; // comma-separated
        public bool DownloadLogs { get; init; }
        public string LogOutputDir { get; init; } = "artifacts/ci-logs";
        public string? TestCommand { get; init; }
        public string? TestCommandFile { get; init; }
        public bool DryRun { get; init; }
        public string? JsonOutput { get; init; }
        public bool ForceOverwrite { get; init; }
        public int LogDownloadRetries { get; init; } = 6;
        public int LogDownloadBackoffSeconds { get; init; } = 10;
        public int LogDownloadMaxWaitSeconds { get; init; } = 200;
        public int RunListLimit { get; init; } = 25;
    }

    private sealed record RunListItem(
        [property: JsonPropertyName("databaseId")] long DatabaseId,
        [property: JsonPropertyName("headSha")] string HeadSha,
        [property: JsonPropertyName("status")] string? Status,
        [property: JsonPropertyName("conclusion")] string? Conclusion,
        [property: JsonPropertyName("headBranch")] string HeadBranch,
        [property: JsonPropertyName("updatedAt")] string? UpdatedAt,
        [property: JsonPropertyName("url")] string? Url
    );

    private sealed record JobSummary(
        [property: JsonPropertyName("id")] long Id,
        [property: JsonPropertyName("name")] string Name,
        [property: JsonPropertyName("status")] string Status,
        [property: JsonPropertyName("conclusion")] string? Conclusion,
        [property: JsonPropertyName("runner_name")] string? RunnerName,
        [property: JsonPropertyName("runner_group_name")] string? RunnerGroupName
    );

    private sealed record JobList([property: JsonPropertyName("jobs")] JobSummary[] Jobs);

    private sealed record RunView(
        [property: JsonPropertyName("url")] string Url,
        [property: JsonPropertyName("status")] string Status,
        [property: JsonPropertyName("conclusion")] string? Conclusion,
        [property: JsonPropertyName("headBranch")] string HeadBranch,
        [property: JsonPropertyName("headSha")] string HeadSha,
        [property: JsonPropertyName("name")] string Name,
        [property: JsonPropertyName("jobs")] JobSummary[] Jobs
    );

    private static int Main(string[] args)
    {
        args = NormalizeArgs(args);
        var parseResult = ParseArgs(args);
        if (parseResult.Error != null)
        {
            Console.Error.WriteLine(parseResult.Error);
            PrintUsage();
            return 1;
        }

        var opts = parseResult.Value!;

        if (!CheckTool("gh"))
        {
            Console.Error.WriteLine("GitHub CLI 'gh' is required on PATH.");
            return 1;
        }
        if (!CheckTool("git"))
        {
            Console.Error.WriteLine("git is required on PATH.");
            return 1;
        }

        var repoPath = Path.GetFullPath(opts.RepoPath);
        var branch = string.IsNullOrWhiteSpace(opts.Branch) ? RunGit(repoPath, "rev-parse", "--abbrev-ref", "HEAD") : opts.Branch;
        if (string.IsNullOrWhiteSpace(branch))
        {
            Console.Error.WriteLine("Unable to resolve branch.");
            return 1;
        }
        var headSha = RunGit(repoPath, "rev-parse", "HEAD");
        if (string.IsNullOrWhiteSpace(headSha))
        {
            Console.Error.WriteLine("Unable to resolve HEAD SHA.");
            return 1;
        }

        var originUrl = RunGit(repoPath, "remote", "get-url", "origin");
        var repoSlug = string.IsNullOrWhiteSpace(opts.RepoSlugOverride) ? ParseRepoSlug(originUrl) : opts.RepoSlugOverride;
        if (repoSlug == null)
        {
            Console.Error.WriteLine($"Cannot parse GitHub repo slug from origin URL: {originUrl}");
            return 1;
        }

        if (!CheckGhAuth(repoSlug))
        {
            Console.Error.WriteLine("gh auth status failed or token missing actions:read scope.");
            return 1;
        }

        var run = opts.RunId.HasValue
            ? GetRunById(repoSlug, opts.RunId.Value)
            : SelectRun(repoSlug, branch, headSha, opts.WaitForHeadRun, opts.WaitTimeoutSeconds, opts.WaitIntervalSeconds, opts.StatusFilter, opts.RunListLimit);
        if (run == null)
        {
            Console.Error.WriteLine("No workflow run found to summarize.");
            return 1;
        }

        var view = ViewRun(repoSlug, run.DatabaseId);
        if (view == null)
        {
            Console.Error.WriteLine($"Failed to view run {run.DatabaseId}");
            return 1;
        }

        var jobs = GetRunJobs(repoSlug, run.DatabaseId);
        if (jobs.Length == 0 && view.Jobs is { Length: > 0 })
        {
            jobs = view.Jobs;
        }

        WithColor(ConsoleColor.Cyan, () =>
        {
            Console.WriteLine($"Run: {view.Name} | Status={view.Status} | Conclusion={view.Conclusion ?? "n/a"} | Branch={view.HeadBranch} | SHA={view.HeadSha}");
            Console.WriteLine($"URL: {view.Url}");
        });

        var failing = jobs.Where(j => !string.Equals(j.Conclusion, "success", StringComparison.OrdinalIgnoreCase)).ToArray();
        if (failing.Length == 0)
        {
            WithColor(ConsoleColor.Green, () => Console.WriteLine("All jobs succeeded; nothing to refine."));
            EmitJsonSummary(opts.JsonOutput, repoSlug, view, Array.Empty<JobSummary>(), Array.Empty<string>(), testResult: null, null);
            return 0;
        }

        WithColor(ConsoleColor.Yellow, () => Console.WriteLine($"Failing jobs (count={failing.Length}):"));
        foreach (var job in failing)
        {
            var runner = string.IsNullOrWhiteSpace(job.RunnerName) ? "n/a" : job.RunnerName;
            var runnerGroup = string.IsNullOrWhiteSpace(job.RunnerGroupName) ? "n/a" : job.RunnerGroupName;
            Console.WriteLine($"- {job.Name} | id={job.Id} | status={job.Status} | conclusion={job.Conclusion} | runner={runner} | group={runnerGroup}");
        }

        if (opts.DownloadLogs)
        {
            var outDir = Path.GetFullPath(opts.LogOutputDir, repoPath);
            Directory.CreateDirectory(outDir);
            var saved = new List<string>();
            foreach (var job in failing)
            {
                if (job.Id == 0)
                {
                    Console.Error.WriteLine($"Skipping log download for job with missing id: {job.Name}");
                    continue;
                }
                var logPath = Path.Combine(outDir, $"run-{run.DatabaseId}-job-{job.Id}.log");
                if (File.Exists(logPath) && !opts.ForceOverwrite)
                {
                    Console.WriteLine($"Skipping existing log {logPath} (use --force to overwrite)");
                    saved.Add(logPath);
                    continue;
                }
                var attempt = 0;
                var delay = opts.LogDownloadBackoffSeconds;
                var start = DateTime.UtcNow;
                while (true)
                {
                    attempt++;
                    Console.WriteLine($"Downloading log for job {job.Name} (attempt {attempt}) to {logPath}");
                    var (code, stdout, stderr) = Exec("gh", $"run view -R {repoSlug} {run.DatabaseId} --job {job.Id} --log");
                    if (code == 0 && !string.IsNullOrWhiteSpace(stdout))
                    {
                        File.WriteAllText(logPath, stdout);
                        saved.Add(logPath);
                        break;
                    }

                    var elapsed = (int)(DateTime.UtcNow - start).TotalSeconds;
                    if (elapsed >= opts.LogDownloadMaxWaitSeconds || attempt >= opts.LogDownloadRetries)
                    {
                        Console.Error.WriteLine($"Failed to download log for job {job.Id} after {attempt} attempts: {stderr}");
                        break;
                    }
                    Console.WriteLine($"Retrying in {delay}s...");
                    Thread.Sleep(TimeSpan.FromSeconds(delay));
                    delay += opts.LogDownloadBackoffSeconds;
                }
            }
            WithColor(ConsoleColor.Green, () => Console.WriteLine($"Logs saved under {opts.LogOutputDir}"));
            EmitJsonSummary(opts.JsonOutput, repoSlug, view, failing, saved, testResult: null, null);
        }

        string? testCmd = opts.TestCommand;
        if (string.IsNullOrWhiteSpace(testCmd) && !string.IsNullOrWhiteSpace(opts.TestCommandFile))
        {
            testCmd = File.Exists(opts.TestCommandFile) ? File.ReadAllText(opts.TestCommandFile) : null;
            if (testCmd == null)
            {
                Console.Error.WriteLine($"Test command file not found: {opts.TestCommandFile}");
                return 2;
            }
        }

        if (!string.IsNullOrWhiteSpace(testCmd))
        {
            WithColor(ConsoleColor.Cyan, () => Console.WriteLine($"Running local test command: {testCmd}"));
            if (!opts.DryRun)
            {
                var (code, stdout, stderr) = Exec("pwsh", $"-NoProfile -Command {testCmd}", repoPath, timeoutSeconds: 900);
                if (code != 0)
                {
                    Console.Error.WriteLine($"Local test command failed with exit code {code}: {Tail(stderr)}");
                    EmitJsonSummary(opts.JsonOutput, repoSlug, view, failing, Array.Empty<string>(), (code, stdout, stderr), null);
                    return code;
                }
                EmitJsonSummary(opts.JsonOutput, repoSlug, view, failing, Array.Empty<string>(), (code, stdout, stderr), null);
            }
            else
            {
                EmitJsonSummary(opts.JsonOutput, repoSlug, view, failing, Array.Empty<string>(), testResult: null, null);
            }
        }
        else
        {
            EmitJsonSummary(opts.JsonOutput, repoSlug, view, failing, Array.Empty<string>(), testResult: null, null);
        }

        return 0;
    }

    private static (Options? Value, string? Error) ParseArgs(string[] args)
    {
        var opts = new Options();
        for (int i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            switch (arg)
            {
                case "-h":
                case "--help":
                    return (opts, "");
                case "--repo":
                case "--repo-path":
                    if (i + 1 >= args.Length) return (null, "--repo-path requires a value");
                    opts = opts with { RepoPath = args[++i] };
                    break;
                case "--branch":
                    if (i + 1 >= args.Length) return (null, "--branch requires a value");
                    opts = opts with { Branch = args[++i] };
                    break;
                case "--repo-slug":
                    if (i + 1 >= args.Length) return (null, "--repo-slug requires a value");
                    opts = opts with { RepoSlugOverride = args[++i] };
                    break;
                case "--run-id":
                    if (!TryReadLong(args, ref i, out var runId)) return (null, "--run-id requires an integer");
                    opts = opts with { RunId = runId };
                    break;
                case "--wait":
                case "--wait-for-head-run":
                    opts = opts with { WaitForHeadRun = true };
                    break;
                case "--wait-timeout":
                    if (!TryReadInt(args, ref i, out var timeout)) return (null, "--wait-timeout requires an integer");
                    opts = opts with { WaitTimeoutSeconds = timeout };
                    break;
                case "--wait-interval":
                    if (!TryReadInt(args, ref i, out var interval)) return (null, "--wait-interval requires an integer");
                    opts = opts with { WaitIntervalSeconds = interval };
                    break;
                case "--status-filter":
                    if (i + 1 >= args.Length) return (null, "--status-filter requires a value (comma-separated)");
                    opts = opts with { StatusFilter = args[++i] };
                    break;
                case "--download-logs":
                    opts = opts with { DownloadLogs = true };
                    break;
                case "--log-dir":
                    if (i + 1 >= args.Length) return (null, "--log-dir requires a value");
                    opts = opts with { LogOutputDir = args[++i] };
                    break;
                case "--log-retries":
                    if (!TryReadInt(args, ref i, out var retries)) return (null, "--log-retries requires an integer");
                    opts = opts with { LogDownloadRetries = retries };
                    break;
                case "--log-retry-delay":
                    if (!TryReadInt(args, ref i, out var backoff)) return (null, "--log-retry-delay requires an integer");
                    opts = opts with { LogDownloadBackoffSeconds = backoff };
                    break;
                case "--log-max-wait":
                    if (!TryReadInt(args, ref i, out var maxWait)) return (null, "--log-max-wait requires an integer");
                    opts = opts with { LogDownloadMaxWaitSeconds = maxWait };
                    break;
                case "--test-cmd":
                    if (i + 1 >= args.Length) return (null, "--test-cmd requires a command string");
                    opts = opts with { TestCommand = args[++i] };
                    break;
                case "--test-cmd-file":
                    if (i + 1 >= args.Length) return (null, "--test-cmd-file requires a path");
                    opts = opts with { TestCommandFile = args[++i] };
                    break;
                case "--run-list-limit":
                    if (!TryReadInt(args, ref i, out var limit)) return (null, "--run-list-limit requires an integer");
                    opts = opts with { RunListLimit = limit };
                    break;
                case "--dry-run":
                    opts = opts with { DryRun = true };
                    break;
                case "--json-output":
                    if (i + 1 >= args.Length) return (null, "--json-output requires a path");
                    opts = opts with { JsonOutput = args[++i] };
                    break;
                case "--force":
                    opts = opts with { ForceOverwrite = true };
                    break;
                default:
                    return (null, $"Unknown argument: {arg}");
            }
        }
        return (opts, null);
    }

    private static string[] NormalizeArgs(string[] args)
    {
        // Some callers may pass a single comma-delimited blob (e.g., '--repo-slug,owner/repo,--run-id,123').
        // Normalize by splitting on commas when the token appears to contain multiple flags, but preserve
        // legitimate comma-bearing values like --status-filter.
        var list = new List<string>();
        foreach (var raw in args)
        {
            if (raw.Contains("--") && raw.Contains(',') && !raw.StartsWith("--status-filter", StringComparison.OrdinalIgnoreCase))
            {
                var parts = raw.Split(',', StringSplitOptions.RemoveEmptyEntries)
                               .Select(p => p.Trim().Trim('\'', '"'))
                               .Where(p => !string.IsNullOrWhiteSpace(p));
                list.AddRange(parts);
            }
            else
            {
                list.Add(raw);
            }
        }
        return list.ToArray();
    }

    private static bool TryReadInt(string[] args, ref int index, out int value)
    {
        if (index + 1 >= args.Length)
        {
            value = 0;
            return false;
        }
        if (!int.TryParse(args[++index], out value))
        {
            return false;
        }
        return true;
    }

    private static bool TryReadLong(string[] args, ref int index, out long value)
    {
        if (index + 1 >= args.Length)
        {
            value = 0;
            return false;
        }
        if (!long.TryParse(args[++index], out value))
        {
            return false;
        }
        return true;
    }

    private static void PrintUsage()
    {
        Console.WriteLine("ci-refine-cli options:");
        Console.WriteLine("  --repo-path <path>        Repository path (default .)");
        Console.WriteLine("  --branch <name>           Branch to inspect (default: git rev-parse --abbrev-ref HEAD)");
        Console.WriteLine("  --repo-slug <owner/repo>  Override repo slug (default: parse from origin)");
        Console.WriteLine("  --run-id <id>             Use a specific workflow run id");
        Console.WriteLine("  --wait-for-head-run       Wait for a run matching HEAD to appear");
        Console.WriteLine("  --wait-timeout <sec>      Timeout while waiting (default 60)");
        Console.WriteLine("  --wait-interval <sec>     Poll interval while waiting (default 5)");
        Console.WriteLine("  --run-list-limit <n>      Max runs to fetch during selection (default 25)");
        Console.WriteLine("  --status-filter <list>    Optional status filter (comma-separated, e.g., completed,queued,in_progress)");
        Console.WriteLine("  --download-logs           Download failing job logs to artifacts/ci-logs");
        Console.WriteLine("  --log-dir <path>          Override log output directory");
        Console.WriteLine("  --log-retries <n>         Log download retry attempts (default 6)");
        Console.WriteLine("  --log-retry-delay <sec>   Delay/backoff between log retries (default 10)");
        Console.WriteLine("  --log-max-wait <sec>      Maximum cumulative wait for logs (default 200)");
        Console.WriteLine("  --test-cmd <command>      Optional local test command (executed via pwsh -NoProfile -Command)");
        Console.WriteLine("  --test-cmd-file <path>    Read test command text from file");
        Console.WriteLine("  --dry-run                 Skip executing the test command (still report failing jobs)");
        Console.WriteLine("  --json-output <path>      Write a JSON summary to path");
        Console.WriteLine("  --force                   Allow overwrite of existing JSON/log files");
        Console.WriteLine("  --help                    Show this message");
    }

    private static bool CheckTool(string tool)
    {
        var (code, _, _) = Exec(tool, "--version");
        return code == 0;
    }

    private static string RunGit(string repoPath, params string[] gitArgs)
    {
        var (code, stdout, _) = Exec("git", string.Join(' ', gitArgs), repoPath);
        return code == 0 ? stdout.Trim() : string.Empty;
    }

    private static (int ExitCode, string Stdout, string Stderr) Exec(string fileName, string arguments, string? workingDir = null, int? timeoutSeconds = null)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            WorkingDirectory = workingDir ?? Directory.GetCurrentDirectory(),
            RedirectStandardError = true,
            RedirectStandardOutput = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        var proc = Process.Start(psi);
        if (proc == null)
        {
            return (1, string.Empty, "Failed to start process");
        }
        var stdout = proc.StandardOutput.ReadToEnd();
        var stderr = proc.StandardError.ReadToEnd();
        if (timeoutSeconds.HasValue)
        {
            if (!proc.WaitForExit(timeoutSeconds.Value * 1000))
            {
                try { proc.Kill(true); } catch { }
                return (124, stdout, "Process timed out");
            }
        }
        else
        {
            proc.WaitForExit();
        }
        return (proc.ExitCode, stdout, stderr);
    }

    private static string? ParseRepoSlug(string? originUrl)
    {
        if (string.IsNullOrWhiteSpace(originUrl)) return null;
        var url = originUrl.Trim();
        var sep = url.IndexOf('@') >= 0 ? url[(url.IndexOf(':') + 1)..] : url;
        var cleaned = sep.Replace("https://", string.Empty).Replace("http://", string.Empty);
        var parts = cleaned.Split(new[] { '/', ':' }, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length < 2) return null;
        var owner = parts[^2].Replace(".git", string.Empty);
        var repo = parts[^1].Replace(".git", string.Empty);
        return $"{owner}/{repo}";
    }

    private static bool CheckGhAuth(string repoSlug)
    {
        var (code, stdout, stderr) = Exec("gh", "auth status --hostname github.com");
        if (code != 0)
        {
            Console.Error.WriteLine(stderr);
            return false;
        }
        // Basic ping to actions scope
        // Minimal ping to confirm token works; avoid extra header to keep arg parsing simple on older gh versions.
        var (codePing, _, errPing) = Exec("gh", $"api /repos/{repoSlug}");
        if (codePing != 0)
        {
            Console.Error.WriteLine($"gh api failed, token may lack scope: {errPing}");
            return false;
        }
        return true;
    }

    private static RunListItem? GetRunById(string repoSlug, long runId)
    {
        var view = ViewRun(repoSlug, runId);
        if (view == null) return null;
        return new RunListItem(runId, view.HeadSha, view.Status, view.Conclusion, view.HeadBranch, null, view.Url);
    }

    private static RunListItem? SelectRun(string repoSlug, string branch, string headSha, bool waitForHead, int timeoutSeconds, int intervalSeconds, string statusFilter, int runListLimit)
    {
        var deadline = DateTime.UtcNow.AddSeconds(timeoutSeconds);
        var statuses = ParseStatusFilter(statusFilter);
        while (true)
        {
            var runs = GetRuns(repoSlug, branch, statuses, runListLimit);
            var run = runs.FirstOrDefault(r => string.Equals(r.HeadSha, headSha, StringComparison.OrdinalIgnoreCase) && string.Equals(r.HeadBranch, branch, StringComparison.OrdinalIgnoreCase));
            if (run != null)
            {
                return run;
            }
            if (!waitForHead || DateTime.UtcNow >= deadline)
            {
                return runs.FirstOrDefault();
            }
            Thread.Sleep(TimeSpan.FromSeconds(intervalSeconds));
        }
    }

    private static RunListItem[] GetRuns(string repoSlug, string branch, HashSet<string> statusFilter, int runListLimit)
    {
        var (code, stdout, stderr) = Exec("gh", $"run list -R {repoSlug} --branch {branch} --limit {runListLimit} --json databaseId,headSha,status,conclusion,headBranch,updatedAt,url");
        if (code != 0)
        {
            Console.Error.WriteLine($"gh run list failed: {stderr}");
            return Array.Empty<RunListItem>();
        }
        var runs = JsonSerializer.Deserialize<RunListItem[]>(stdout, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? Array.Empty<RunListItem>();
        if (statusFilter.Count == 0) return runs;
        return runs.Where(r => r.Status != null && statusFilter.Contains(r.Status.ToLowerInvariant())).ToArray();
    }

    private static JobSummary[] GetRunJobs(string repoSlug, long runId)
    {
        var all = new List<JobSummary>();
        var page = 1;
        while (true)
        {
            var (code, stdout, stderr) = Exec("gh", $"api /repos/{repoSlug}/actions/runs/{runId}/jobs?per_page=100&page={page}");
            if (code != 0)
            {
                Console.Error.WriteLine($"Failed to list jobs for run {runId}: {stderr}");
                break;
            }
            var jobList = JsonSerializer.Deserialize<JobList>(stdout, SerializerOptions);
            if (jobList?.Jobs == null || jobList.Jobs.Length == 0)
            {
                break;
            }
            all.AddRange(jobList.Jobs);
            if (jobList.Jobs.Length < 100)
            {
                break;
            }
            page++;
        }
        return all.ToArray();
    }

    private static RunView? ViewRun(string repoSlug, long runId)
    {
        var (code, stdout, stderr) = Exec("gh", $"run view -R {repoSlug} {runId} --json url,status,conclusion,headBranch,headSha,name,jobs");
        if (code != 0)
        {
            Console.Error.WriteLine($"gh run view failed: {stderr}");
            return null;
        }
        return JsonSerializer.Deserialize<RunView>(stdout, SerializerOptions);
    }

    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private static void WithColor(ConsoleColor color, Action action)
    {
        var prev = Console.ForegroundColor;
        Console.ForegroundColor = color;
        try { action(); }
        finally { Console.ForegroundColor = prev; }
    }

    private static string Tail(string? input, int max = 4000)
    {
        if (string.IsNullOrEmpty(input)) return string.Empty;
        return input.Length <= max ? input : input[^max..];
    }

    private static HashSet<string> ParseStatusFilter(string statuses)
    {
        if (string.IsNullOrWhiteSpace(statuses)) return new HashSet<string>();
        return statuses
            .Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(s => s.Trim().ToLowerInvariant())
            .Where(s => s.Length > 0)
            .ToHashSet();
    }

    private sealed record SummaryJson(
        string Repo,
        long RunId,
        string? RunUrl,
        string? Status,
        string? Conclusion,
        string Branch,
        string HeadSha,
        JobSummary[] FailingJobs,
        string[] LogPaths,
        TestResult? Test,
        string TimestampUtc
    );

    private sealed record TestResult(int ExitCode, string Stdout, string Stderr);

    private static void EmitJsonSummary(string? path, string repoSlug, RunView view, JobSummary[] failing, IEnumerable<string> logPaths, (int ExitCode, string Stdout, string Stderr)? testResult, string? note = null)
    {
        if (string.IsNullOrWhiteSpace(path)) return;
        var summary = new SummaryJson(
            Repo: repoSlug,
            RunId: ParseRunIdFromUrl(view.Url),
            RunUrl: view.Url,
            Status: view.Status,
            Conclusion: view.Conclusion,
            Branch: view.HeadBranch,
            HeadSha: view.HeadSha,
            FailingJobs: failing,
            LogPaths: logPaths.ToArray(),
            Test: testResult.HasValue ? new TestResult(testResult.Value.ExitCode, testResult.Value.Stdout, testResult.Value.Stderr) : null,
            TimestampUtc: DateTime.UtcNow.ToString("o")
        );

        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);
        if (File.Exists(path) && !summary.LogPaths.Any() && !summary.FailingJobs.Any())
        {
            // allow overwrite but not necessary to append
        }
        File.WriteAllText(path, JsonSerializer.Serialize(summary, SerializerOptions));
    }

    private static long ParseRunIdFromUrl(string url)
    {
        if (string.IsNullOrWhiteSpace(url)) return 0;
        var parts = url.Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (long.TryParse(parts.LastOrDefault(), out var id)) return id;
        return 0;
    }
}
