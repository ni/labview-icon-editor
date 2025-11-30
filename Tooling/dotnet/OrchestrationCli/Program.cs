using System.Diagnostics;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Xml;
using System.Text;
using System.IO.Compression;

public static class Program
{
    public record Options(
        string Subcommand,
        string Repo,
        string Bitness,
        string Pwsh,
        string Ref,
        string LvlibpBitness,
        int Major,
        int Minor,
        int Patch,
        int Build,
        string Company,
        string Author,
        int LabviewMinor,
        bool RunBothBitnessSeparately,
        bool Managed,
        string? LvVersion,
        string? VipcPath,
        string? RequestPath,
        string? ProjectPath,
        string? ScenarioPath,
        string? VipmManifestPath,
        string? WorktreeRoot,
        bool SkipWorktree,
        bool SkipPreflight,
        bool RequireDevmode,
        bool AutoBindDevmode,
        int TimeoutSeconds,
        bool Plain,
        bool Verbose,
        string? SourceDistZip,
        string? SourceDistOutput,
        bool SourceDistStrict,
        bool SourceDistLogStash,
        string? LabviewCliPath,
        string? LabviewPath,
        int? LabviewPort,
        string? TempRoot,
        string? LogRoot,
        int? LabviewCliTimeoutSec,
        bool ForceWorktree,
        bool CopyOnFail,
        int RetryBuilds,
        string? ExpectSha);

    public sealed record CommandResult(
        string Command,
        string Status,
        int ExitCode,
        long DurationMs,
        object Details);

    internal static int Main(string[] args)
    {
        if (args.Any(a => a.Equals("--print-provenance", StringComparison.OrdinalIgnoreCase)))
        {
            PrintProvenance();
            return 0;
        }

        var parsed = ParseArgs(args);
        if (parsed.help)
        {
            PrintUsage();
            return 0;
        }
        if (parsed.error != null)
        {
            Console.Error.WriteLine(parsed.error);
            PrintUsage();
            return 1;
        }

        var opts = parsed.value!;
        var timer = Stopwatch.StartNew();
        var last = TimeSpan.Zero;

        void Log(string message)
        {
            var elapsed = timer.Elapsed;
            var delta = elapsed - last;
            last = elapsed;
            Console.WriteLine($"[orchestration-cli][(T+{elapsed.TotalSeconds:F3}s Δ+{delta.TotalMilliseconds:N0}ms)] {message}");
        }

        var repo = Path.GetFullPath(opts.Repo);
        if (string.Equals(opts.Repo, "auto", StringComparison.OrdinalIgnoreCase))
        {
            repo = Path.GetFullPath(Directory.GetCurrentDirectory());
        }
        var mainRepo = repo;
        if (!Directory.Exists(repo))
        {
            Console.Error.WriteLine($"Repository not found: {repo}");
            return 1;
        }

        var results = new List<CommandResult>();
        var overallExit = 0;

        if (opts.Subcommand.Equals("source-dist-verify", StringComparison.OrdinalIgnoreCase))
        {
            var verify = RunSourceDistVerify(Log, opts, repo);
            Console.WriteLine(JsonSerializer.Serialize(new[] { verify }, new JsonSerializerOptions { WriteIndented = true }));
            return verify.Status.Equals("success", StringComparison.OrdinalIgnoreCase) ? 0 : verify.ExitCode;
        }
        if (opts.Subcommand.Equals("sd-ppl-lvcli", StringComparison.OrdinalIgnoreCase))
        {
            var run = RunSdPplLvcli(Log, opts, repo);
            Console.WriteLine(JsonSerializer.Serialize(new[] { run }, new JsonSerializerOptions { WriteIndented = true }));
            return run.Status.Equals("success", StringComparison.OrdinalIgnoreCase) ? 0 : run.ExitCode;
        }

        var isPackage = opts.Subcommand.Equals("package-build", StringComparison.OrdinalIgnoreCase)
            || opts.Subcommand.Equals("package", StringComparison.OrdinalIgnoreCase);

        if (isPackage)
        {
            results.Add(RunPackageBuild(Log, opts, repo));
        }
        else
        {
            var bitnessList = ResolveBitness(opts.Bitness);
            foreach (var bit in bitnessList)
            {
                switch (opts.Subcommand.ToLowerInvariant())
                {
                    case "devmode-bind":
                        results.Add(RunBindUnbind(Log, opts, repo, bit, mode: "bind"));
                        break;
                    case "devmode-unbind":
                        results.Add(RunBindUnbind(Log, opts, repo, bit, mode: "unbind"));
                        break;
                    case "labview-close":
                        results.Add(RunCloseLabVIEW(Log, opts, repo, bit));
                        break;
                    case "restore-sources":
                        results.Add(RunRestore(Log, opts, repo, bit));
                        break;
                    case "apply-deps":
                        results.Add(RunApplyDeps(Log, opts, repo, bit));
                        break;
                    case "vi-analyzer":
                        results.Add(RunViAnalyzer(Log, opts, repo, bit));
                        break;
                    case "missing-check":
                        results.Add(RunMissingCheck(Log, opts, repo, bit));
                        break;
                    case "unit-tests":
                        results.Add(RunUnitTests(Log, opts, repo, bit));
                        break;
                case "vi-compare":
                    results.Add(RunViCompare(Log, opts, repo, bit));
                    break;
                case "vipm-verify":
                    results.Add(RunVipmVerify(Log, opts, repo, bit));
                    break;
                case "vipm-install":
                    results.Add(RunVipmInstall(Log, opts, repo, bit));
                    break;
                case "vi-compare-preflight":
                    results.Add(RunViComparePreflight(Log, opts, repo, bit));
                    break;
                default:
                    Console.Error.WriteLine($"Unknown subcommand: {opts.Subcommand}");
                    return 1;
            }
        }
        }

        var json = JsonSerializer.Serialize(results, new JsonSerializerOptions { WriteIndented = true });
        Console.WriteLine(json);

        foreach (var r in results)
        {
            if (!string.Equals(r.Status, "success", StringComparison.OrdinalIgnoreCase))
            {
                overallExit = overallExit == 0 ? r.ExitCode : overallExit;
            }
        }

        return overallExit;
    }

    internal static CommandResult RunBindUnbindForTest(Action<string> log, Options opts, string repo, string bitness, string mode)
        => RunBindUnbind(log, opts, repo, bitness, mode);

    private static CommandResult RunBindUnbind(Action<string> log, Options opts, string repo, string bitness, string mode)
    {
        var scriptRoot = string.IsNullOrWhiteSpace(opts.Repo) ? repo : opts.Repo;
        var script = mode == "bind"
            ? Path.Combine(scriptRoot, "scripts", "bind-development-mode", "BindDevelopmentMode.ps1")
            : Path.Combine(scriptRoot, "scripts", "revert-development-mode", "RevertDevelopmentMode.ps1");
        var lvVersion = ResolveLabviewVersion(repo, opts, log, fallback: "2023");

        var argList = new List<string> { "-NoProfile", "-File" };
        if (mode == "bind")
        {
            argList.AddRange(new[]
            {
                script,
                "-RepositoryPath", repo,
                "-Mode", "bind",
                "-Bitness", bitness,
                "-Force"
            });
        }
        else
        {
            argList.AddRange(new[]
            {
                script,
                "-RepositoryPath", repo,
                "-SupportedBitness", bitness
            });
        }
        if (!string.IsNullOrWhiteSpace(opts.LvVersion))
        {
            if (mode == "bind")
            {
                argList.AddRange(new[] { "-LabVIEWVersion", lvVersion });
            }
            else
            {
                // RevertDevelopmentMode expects Package_LabVIEW_Version
                argList.AddRange(new[] { "-Package_LabVIEW_Version", lvVersion });
            }
        }

        log($"{mode} devmode ({bitness}-bit, {lvVersion})...");
        var result = RunPwsh(opts, argList, opts.TimeoutSeconds);
        var status = result.ExitCode == 0 ? "success" : "fail";
        var details = new
        {
            bitness,
            mode,
            lvVersion,
            scriptPath = script,
            exit = result.ExitCode,
            stdout = result.StdOut,
            stderr = result.StdErr
        };
        return new CommandResult($"devmode-{mode}", status, result.ExitCode, result.DurationMs, details);
    }

    internal static CommandResult RunRestoreForTest(Action<string> log, Options opts, string repo, string bitness, bool? tokenPresentOverride = null)
        => RunRestore(log, opts, repo, bitness, tokenPresentOverride);

    private static CommandResult RunRestore(Action<string> log, Options opts, string repo, string bitness, bool? tokenPresentOverride = null)
    {
        var sw = Stopwatch.StartNew();
        var lvVersion = string.IsNullOrWhiteSpace(opts.LvVersion) ? "2021" : opts.LvVersion!;
        var tokenPresent = tokenPresentOverride ?? TokenPresent(repo, lvVersion, bitness);
        var viPath = Path.Combine(repo, "Tooling", "RestoreSetupLVSourceCore.vi");
        var projectPath = Path.Combine(repo, "lv_icon_editor.lvproj");
        var labviewPath = ResolveLabviewExePath(lvVersion, bitness, opts.LabviewPath, log);

        if (opts.Subcommand.Equals("sd-ppl-lvcli", StringComparison.OrdinalIgnoreCase))
        {
            sw.Stop();
            log($"restore packaged sources ({bitness}-bit) skipped for sd-ppl-lvcli (LabVIEWCLI-only flow).");
            return new CommandResult("restore-sources", "skip", 0, sw.ElapsedMilliseconds, new
            {
                bitness,
                lvVersion,
                tokenPresent = tokenPresent,
                viPath,
                projectPath,
                reason = "Skipped by sd-ppl-lvcli",
                gcliExit = 0,
                stdout = string.Empty,
                stderr = string.Empty
            });
        }

        if (!tokenPresent)
        {
            sw.Stop();
            log($"restore packaged sources ({bitness}-bit) skipped (token not present).");
            var detailsSkip = new
            {
                bitness,
                lvVersion,
                tokenPresent = false,
                viPath,
                projectPath,
                reason = "Dev-mode token not found in LabVIEW.ini for this repo/bitness.",
                gcliExit = 0,
                stdout = string.Empty,
                stderr = string.Empty
            };
            return new CommandResult("restore-sources", "skip", 0, sw.ElapsedMilliseconds, detailsSkip);
        }

        var connectMs = opts.TimeoutSeconds > 0 ? Math.Max(5000, Math.Min(opts.TimeoutSeconds * 500, 20000)) : 10000;
        var killMs = 5000;
        var gcliArgs = new List<string>
        {
            "--lv-ver", lvVersion,
            "--arch", bitness,
            "--connect-timeout", connectMs.ToString(),
            "--kill-timeout", killMs.ToString(),
            "-v", viPath,
            "--",
            projectPath,
            "Editor Packed Library"
        };
        log($"restore packaged sources ({bitness}-bit) via g-cli...");
        var result = RunProcess("g-cli", repo, gcliArgs, opts.TimeoutSeconds);
        var connectionIssue = IsConnectionIssue(result.StdOut) || IsConnectionIssue(result.StdErr);
        string status;
        int exitForResult;
        if (result.ExitCode == 0)
        {
            status = "success";
            exitForResult = 0;
        }
        else if (connectionIssue)
        {
            status = "skip";
            exitForResult = 0;
        }
        else
        {
            status = "fail";
            exitForResult = result.ExitCode;
        }

        // Best-effort close to avoid leaving LabVIEW running.
        try
        {
            RunCloseLabVIEW(log, opts, repo, bitness, fakeExit: null);
        }
        catch
        {
            // ignore close errors
        }

        var details = new
        {
            bitness,
            lvVersion,
            tokenPresent = tokenPresent,
            viPath,
            projectPath,
            gcliExit = result.ExitCode,
            stdout = result.StdOut,
            stderr = result.StdErr,
            connectionIssue
        };
        return new CommandResult("restore-sources", status, exitForResult, result.DurationMs, details);
    }

    internal static CommandResult RunApplyDepsForTest(Action<string> log, Options opts, string repo, string bitness)
        => RunApplyDeps(log, opts, repo, bitness);

    internal static CommandResult RunApplyDepsForTest(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
        => RunApplyDeps(log, opts, repo, bitness, fakeExit);

    private static CommandResult RunApplyDeps(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
    {
        var script = Path.Combine(repo, "scripts", "task-verify-apply-dependencies.ps1");
        var vipcPath = string.IsNullOrWhiteSpace(opts.VipcPath) ? "runner_dependencies.vipc" : opts.VipcPath!;
        var argList = new List<string>
        {
            "-NoProfile",
            "-File", script,
            "-RepositoryPath", repo,
            "-SupportedBitness", bitness,
            "-VipcPath", vipcPath
        };
        if (!string.IsNullOrWhiteSpace(opts.LvVersion))
        {
            argList.AddRange(new[] { "-PackageLabVIEWVersion", opts.LvVersion! });
        }

        log($"apply dependencies ({bitness}-bit) vipc={vipcPath}...");
        var result = fakeExit.HasValue
            ? (ExitCode: fakeExit.Value, StdOut: string.Empty, StdErr: string.Empty, DurationMs: 0L)
            : RunPwsh(opts, argList, opts.TimeoutSeconds);
        var status = result.ExitCode == 0 ? "success" : "fail";
        var details = new
        {
            bitness,
            vipcPath,
            lvVersion = opts.LvVersion,
            scriptPath = script,
            exit = result.ExitCode,
            stdout = result.StdOut,
            stderr = result.StdErr
        };
        return new CommandResult("apply-deps", status, result.ExitCode, result.DurationMs, details);
    }

    internal static CommandResult RunCloseLabVIEWForTest(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
        => RunCloseLabVIEW(log, opts, repo, bitness, fakeExit);

    internal static CommandResult RunVipmVerifyForTest(Action<string> log, Options opts, string repo, string bitness)
        => RunVipmVerify(log, opts, repo, bitness);

    internal static CommandResult RunVipmInstallForTest(Action<string> log, Options opts, string repo, string bitness)
        => RunVipmInstall(log, opts, repo, bitness);

        private static CommandResult RunCloseLabVIEW(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
        {
            var lvVersion = string.IsNullOrWhiteSpace(opts.LvVersion) ? "2021" : opts.LvVersion!;
            var script = Path.Combine(repo, "scripts", "close-labview", "Close_LabVIEW.ps1");
            var argList = new List<string>
            {
            "-NoProfile",
            "-File", script,
            "-Package_LabVIEW_Version", lvVersion,
            "-SupportedBitness", bitness
        };

        log($"close LabVIEW ({bitness}-bit, {lvVersion})...");
        var result = fakeExit.HasValue
            ? (ExitCode: fakeExit.Value, StdOut: string.Empty, StdErr: string.Empty, DurationMs: 0L)
            : RunPwsh(opts, argList, opts.TimeoutSeconds);
        var connectionIssue = IsConnectionIssue(result.StdOut) || IsConnectionIssue(result.StdErr);
        var status = result.ExitCode == 0 || connectionIssue ? "success" : "fail";
        var details = new
        {
            bitness,
            lvVersion,
            scriptPath = script,
            closed = result.ExitCode == 0,
            exit = result.ExitCode,
            stdout = result.StdOut,
            stderr = result.StdErr,
            connectionIssue
        };
        return new CommandResult("labview-close", status, result.ExitCode, result.DurationMs, details);
    }

    private static CommandResult RunPackageBuild(Action<string> log, Options opts, string repo)
    {
        var projectPath = Path.Combine(repo, "Tooling", "dotnet", "IntegrationEngineCli", "IntegrationEngineCli.csproj");
        if (!File.Exists(projectPath))
        {
            var message = $"IntegrationEngineCli project not found at {projectPath}";
            var failDetails = new
            {
                repo,
                projectPath,
                exit = 1,
                stdout = string.Empty,
                stderr = message
            };
            return new CommandResult("package-build", "fail", 1, 0, failDetails);
        }

        var argList = new List<string>
        {
            "run", "--project", projectPath, "--",
            "--repo", repo,
            "--ref", opts.Ref,
            "--bitness", opts.Bitness,
            "--lvlibp-bitness", opts.LvlibpBitness,
            "--major", opts.Major.ToString(),
            "--minor", opts.Minor.ToString(),
            "--patch", opts.Patch.ToString(),
            "--build", opts.Build.ToString(),
            "--company", opts.Company,
            "--author", opts.Author,
            "--labview-minor", opts.LabviewMinor.ToString(),
            "--pwsh", opts.Pwsh
        };

        if (opts.RunBothBitnessSeparately)
        {
            argList.Add("--run-both-bitness-separately");
        }
        if (opts.Verbose)
        {
            argList.Add("--verbose");
        }
        if (opts.Managed)
        {
            argList.Add("--managed");
        }

        log($"package build via IntegrationEngineCli (ref={opts.Ref}, bitness={opts.Bitness}, lvlibp-bitness={opts.LvlibpBitness}, version={opts.Major}.{opts.Minor}.{opts.Patch}.{opts.Build})...");
        var result = RunProcess("dotnet", repo, argList, opts.TimeoutSeconds);
        var status = result.ExitCode == 0 ? "success" : "fail";
        var details = new
        {
            repo,
            refName = opts.Ref,
            bitness = opts.Bitness,
            lvlibpBitness = opts.LvlibpBitness,
            version = new { opts.Major, opts.Minor, opts.Patch, opts.Build },
            company = opts.Company,
            author = opts.Author,
            labviewMinor = opts.LabviewMinor,
            managed = opts.Managed,
            runBothBitnessSeparately = opts.RunBothBitnessSeparately,
            projectPath,
            exit = result.ExitCode,
            stdout = result.StdOut,
            stderr = result.StdErr
        };
        return new CommandResult("package-build", status, result.ExitCode, result.DurationMs, details);
    }

    private sealed class SourceManifestEntry
    {
        [JsonPropertyName("path")]
        public string Path { get; set; } = string.Empty;

        [JsonPropertyName("last_commit")]
        public string? LastCommit { get; set; }

        [JsonPropertyName("commit_author")]
        public string? CommitAuthor { get; set; }

        [JsonPropertyName("commit_date")]
        public string? CommitDate { get; set; }

        [JsonPropertyName("commit_source")]
        public string? CommitSource { get; set; }

        [JsonPropertyName("size_bytes")]
        public long SizeBytes { get; set; }
    }

    private static CommandResult RunSourceDistVerify(Action<string> log, Options opts, string repo)
    {
        var sw = Stopwatch.StartNew();
        var zipPath = string.IsNullOrWhiteSpace(opts.SourceDistZip)
            ? Path.Combine(repo, "builds", "artifacts", "source-distribution.zip")
            : Path.IsPathRooted(opts.SourceDistZip!) ? opts.SourceDistZip! : Path.Combine(repo, opts.SourceDistZip!);

        if (!File.Exists(zipPath))
        {
            var detailsMissing = new
            {
                zipPath,
                error = "Zip artifact not found"
            };
            return new CommandResult("source-dist-verify", "fail", 1, sw.ElapsedMilliseconds, detailsMissing);
        }

        var outputRoot = string.IsNullOrWhiteSpace(opts.SourceDistOutput)
            ? Path.Combine(repo, "builds", "reports", "source-distribution-verify", DateTime.UtcNow.ToString("yyyyMMdd-HHmmss"))
            : Path.IsPathRooted(opts.SourceDistOutput!) ? opts.SourceDistOutput! : Path.Combine(repo, opts.SourceDistOutput!);
        var extractDir = Path.Combine(outputRoot, "extracted");
        Directory.CreateDirectory(extractDir);

        try
        {
            ZipFile.ExtractToDirectory(zipPath, extractDir, true);
        }
        catch (Exception ex)
        {
            var details = new { zipPath, outputRoot, error = $"Failed to extract zip: {ex.Message}" };
            return new CommandResult("source-dist-verify", "fail", 1, sw.ElapsedMilliseconds, details);
        }

        var manifestJson = Directory.GetFiles(extractDir, "manifest.json", SearchOption.AllDirectories).FirstOrDefault();
        var manifestCsv = Directory.GetFiles(extractDir, "manifest.csv", SearchOption.AllDirectories).FirstOrDefault();
        if (string.IsNullOrWhiteSpace(manifestJson))
        {
            var details = new { zipPath, extractDir, error = "manifest.json not found in extracted zip" };
            return new CommandResult("source-dist-verify", "fail", 1, sw.ElapsedMilliseconds, details);
        }

        List<SourceManifestEntry>? entries = null;
        try
        {
            var json = File.ReadAllText(manifestJson);
            entries = JsonSerializer.Deserialize<List<SourceManifestEntry>>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        }
        catch (Exception ex)
        {
            var details = new { zipPath, manifestJson, error = $"Failed to parse manifest.json: {ex.Message}" };
            return new CommandResult("source-dist-verify", "fail", 1, sw.ElapsedMilliseconds, details);
        }

        if (entries == null)
        {
            var details = new { zipPath, manifestJson, error = "manifest.json deserialized to null" };
            return new CommandResult("source-dist-verify", "fail", 1, sw.ElapsedMilliseconds, details);
        }

        var failures = new List<object>();
        var nullCommits = new List<object>();
        var warnings = new List<object>();
        var invalidPaths = new List<object>();
        var checkedCount = 0;
        foreach (var entry in entries)
        {
            var relPath = entry.Path ?? string.Empty;
            var lowered = relPath.Trim().ToLowerInvariant();
            if (lowered.StartsWith("program files") || lowered.Contains(":\\program files"))
            {
                invalidPaths.Add(new { path = relPath, reason = "Path under Program Files is not allowed in Source Distribution" });
                continue;
            }
            var commit = entry.LastCommit ?? string.Empty;
            if (string.IsNullOrWhiteSpace(commit))
            {
                nullCommits.Add(new { path = relPath, reason = "last_commit missing" });
                warnings.Add(new { path = relPath, reason = "last_commit missing (allowed; reported)" });
                continue;
            }

            var result = RunProcess("git", repo, new[] { "-C", repo, "cat-file", "-e", $"{commit}^{{commit}}" }, opts.TimeoutSeconds);
            if (result.ExitCode != 0)
            {
                failures.Add(new { path = relPath, commit, reason = string.IsNullOrWhiteSpace(result.StdErr) ? result.StdOut : result.StdErr });
            }
            else
            {
                checkedCount++;
            }
        }

        var status = failures.Count == 0
            ? (nullCommits.Count > 0 ? "success_with_warnings" : "success")
            : "fail";
        var exit = status.StartsWith("success", StringComparison.OrdinalIgnoreCase) ? 0 : 1;
        var report = new
        {
            zip = GetRelativePathSafe(repo, zipPath),
            manifestJson = GetRelativePathSafe(repo, manifestJson),
            manifestCsv = manifestCsv != null ? GetRelativePathSafe(repo, manifestCsv) : null,
            extracted = GetRelativePathSafe(repo, extractDir),
            strict = opts.SourceDistStrict,
            totalEntries = entries.Count,
            commitsChecked = checkedCount,
            nullCommitCount = nullCommits.Count,
            failures,
            nullCommits,
            warnings,
            invalidPaths
        };

        Directory.CreateDirectory(outputRoot);
        var reportPath = Path.Combine(outputRoot, "report.json");
        File.WriteAllText(reportPath, JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }));
        log($"source-dist verify: checked={checkedCount}, null={nullCommits.Count}, failures={failures.Count}, warnings={warnings.Count}, strict={opts.SourceDistStrict}");
        Console.WriteLine($"[artifact][source-dist-verify] report: {GetRelativePathSafe(repo, reportPath)}");
        Console.WriteLine($"[artifact][source-dist-verify] extracted: {GetRelativePathSafe(repo, extractDir)}");

        if (opts.SourceDistLogStash)
        {
            var logStash = Path.Combine(repo, "scripts", "log-stash", "Write-LogStashEntry.ps1");
            if (File.Exists(logStash))
            {
                var manifestJsonRel = GetRelativePathSafe(repo, manifestJson);
                var manifestCsvRel = !string.IsNullOrWhiteSpace(manifestCsv) ? GetRelativePathSafe(repo, manifestCsv!) : null;
                var extractDirRel = GetRelativePathSafe(repo, extractDir);
                var args = new List<string>
                {
                    "-NoProfile", "-File", logStash,
                    "-RepositoryPath", repo,
                    "-Category", "source-dist-verify",
                    "-Label", "verify",
                    "-LogPaths", reportPath,
                    "-AttachmentPaths", manifestJsonRel
                };
                if (!string.IsNullOrWhiteSpace(manifestCsvRel)) { args.Add(manifestCsvRel!); }
                args.Add(extractDirRel);
                args.AddRange(new[]
                {
                    "-Status", status,
                    "-ProducerScript", "OrchestrationCli",
                    "-ProducerTask", "source-dist-verify",
                    "-StartedAtUtc", DateTime.UtcNow.AddMilliseconds(-sw.ElapsedMilliseconds).ToString("o"),
                    "-DurationMs", sw.ElapsedMilliseconds.ToString()
                });
                var stashResult = RunProcess(opts.Pwsh, repo, args, opts.TimeoutSeconds);
                if (stashResult.ExitCode != 0)
                {
                    log($"log-stash bundle failed (exit {stashResult.ExitCode}): {stashResult.StdErr}");
                }
            }
            else
            {
                log("log-stash helper not found; skipping bundle.");
            }
        }

        sw.Stop();
        return new CommandResult("source-dist-verify", status, exit, sw.ElapsedMilliseconds, new
        {
            zipPath,
            outputRoot,
            manifestJson,
            manifestCsv,
            failures,
            nullCommits
        });
    }

    private static CommandResult RunSdPplLvcli(Action<string> log, Options opts, string repo)
    {
        var sw = Stopwatch.StartNew();
        var phases = new List<CommandResult>();
        var mainRepo = repo;
        var repoDisplay = Path.GetFullPath(repo);
        var stamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff");
        var lockPath = Path.Combine(repo, "builds", "locks", "sd-ppl-lvcli.lock");
        var shortSha = GetGitSha();
        if (string.IsNullOrWhiteSpace(shortSha) || shortSha.Length < 8) { shortSha = "sd-ppl"; }
        else { shortSha = shortSha[..8]; }
        var defaultTempRoot = @"C:\t";
        var tempRoot = !string.IsNullOrWhiteSpace(opts.TempRoot)
            ? (Path.IsPathRooted(opts.TempRoot!) ? opts.TempRoot! : Path.Combine(repo, opts.TempRoot!))
            : defaultTempRoot;
        var logsDir = !string.IsNullOrWhiteSpace(opts.LogRoot)
            ? (Path.IsPathRooted(opts.LogRoot!) ? opts.LogRoot! : Path.Combine(repo, opts.LogRoot!))
            : Path.Combine(tempRoot, "logs");
        var extractDir = Path.Combine(tempRoot, "extract");
        var defaultWorktreeBase = @"C:\w";
        var worktreeBase = !string.IsNullOrWhiteSpace(opts.WorktreeRoot)
            ? (Path.IsPathRooted(opts.WorktreeRoot!) ? opts.WorktreeRoot! : Path.Combine(repo, opts.WorktreeRoot!))
            : defaultWorktreeBase;
        var worktreePath = Path.Combine(worktreeBase, $"{shortSha}-{stamp.Substring(Math.Max(0, stamp.Length - 6))}");
        var workingRepo = repo;
        var worktreeCreated = false;
        var logPaths = new List<string>();
        var summaryLogs = new List<string>();
        var projectPath = string.IsNullOrWhiteSpace(opts.ProjectPath)
            ? Path.Combine(repo, "lv_icon_editor.lvproj")
            : (Path.IsPathRooted(opts.ProjectPath!) ? opts.ProjectPath! : Path.Combine(repo, opts.ProjectPath!));
        var targetName = "My Computer";
        var repoName = new DirectoryInfo(repo).Name;
        byte[]? baselineLvproj = null;
        try { baselineLvproj = File.ReadAllBytes(projectPath); } catch { baselineLvproj = null; }
        string sourceDistZip = string.Empty;
        string? extractedRoot = null;
        string? sdLogFile = null;
        string? pplLogFile = null;
        var copyOnFail = opts.CopyOnFail;
        var labviewCliPath = string.IsNullOrWhiteSpace(opts.LabviewCliPath) ? "LabVIEWCLI" : opts.LabviewCliPath!;
        var lvVersion = ResolveLabviewVersion(repo, opts, log, fallback: "2023");
        var bitness = ResolveLabviewBitness(repo, opts, log, fallback: "64");
        var optsWithVersion = opts with { LvVersion = lvVersion, Bitness = bitness };
        var labviewPath = ResolveLabviewExePath(lvVersion, bitness, opts.LabviewPath, log);
        int? portNumber = null;
        try
        {
            portNumber = opts.LabviewPort ?? ResolveLabviewPort(labviewPath, lvVersion, bitness, log);
        }
        catch (Exception ex)
        {
            return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { lvVersion, bitness, labviewPath, error = $"Failed to resolve LabVIEW port: {ex.Message}" });
        }
        var pipelineOk = true;
        var repoBound = false;
        var extractedBound = false;
        FileStream? lockStream = null;

        bool IsPathUnderProgramFiles(string path)
        {
            var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            var pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            if (!string.IsNullOrWhiteSpace(pf) && Path.GetFullPath(path).StartsWith(Path.GetFullPath(pf), StringComparison.OrdinalIgnoreCase)) return true;
            if (!string.IsNullOrWhiteSpace(pf86) && Path.GetFullPath(path).StartsWith(Path.GetFullPath(pf86), StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        bool TryHandleStaleLock(string path)
        {
            try
            {
                if (!File.Exists(path)) return false;
                var info = File.GetLastWriteTimeUtc(path);
                var age = DateTime.UtcNow - info;
                var text = File.ReadAllText(path);
                int? pid = null;
                var match = Regex.Match(text, @"pid=(\d+)");
                if (match.Success && int.TryParse(match.Groups[1].Value, out var p))
                {
                    pid = p;
                }
                var processAlive = false;
                if (pid.HasValue)
                {
                    try { using var proc = Process.GetProcessById(pid.Value); processAlive = !proc.HasExited; } catch { processAlive = false; }
                }
                var staleByAge = age.TotalHours >= 2;
                var stale = !processAlive || staleByAge;
                if (stale)
                {
                    log($"[sd-ppl-lvcli] removing stale lock (pid={pid?.ToString() ?? "unknown"}, age={age.TotalMinutes:F1}m): {path}");
                    try { File.Delete(path); } catch { }
                }
                return stale;
            }
            catch
            {
                return false;
            }
        }

        string ResolveSourceDistZip(string? overridePath, string baseRepo)
        {
            if (string.IsNullOrWhiteSpace(overridePath))
            {
                return Path.Combine(baseRepo, "builds", "artifacts", "source-distribution.zip");
            }

            return Path.IsPathRooted(overridePath!)
                ? overridePath!
                : Path.Combine(baseRepo, overridePath!);
        }

        CommandResult Record(CommandResult result, string phase, bool affectsOutcome = true)
        {
            phases.Add(result);
            log($"[sd-ppl-lvcli][{phase}] {result.Status} (exit {result.ExitCode}, {result.DurationMs}ms)");
            if (affectsOutcome && !string.Equals(result.Status, "success", StringComparison.OrdinalIgnoreCase))
            {
                pipelineOk = false;
            }
            return result;
        }

        void PhaseStart(string phase) => log($"[sd-ppl-lvcli][{phase}] start");

        CommandResult RunLabviewCliBuild(string buildSpec, string project, string workingDir, string logFilePath)
        {
            var lvcliTimeout = opts.LabviewCliTimeoutSec.HasValue && opts.LabviewCliTimeoutSec.Value > 0
                ? opts.LabviewCliTimeoutSec.Value
                : opts.TimeoutSeconds;

            var args = new List<string>
            {
                "-OperationName", "ExecuteBuildSpec",
                "-ProjectPath", project,
                "-TargetName", targetName,
                "-BuildSpecName", buildSpec
            };
            if (!string.IsNullOrWhiteSpace(logFilePath))
            {
                try
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(logFilePath)!);
                }
                catch { }
                args.AddRange(new[] { "-LogFilePath", logFilePath });
            }
            if (!string.IsNullOrWhiteSpace(labviewPath))
            {
                args.AddRange(new[] { "-LabVIEWPath", labviewPath! });
            }
            if (portNumber.HasValue)
            {
                args.AddRange(new[] { "-PortNumber", portNumber.Value.ToString() });
            }

            log($"[sd-ppl-lvcli] LabVIEWCLI ExecuteBuildSpec \"{buildSpec}\" ({bitness}-bit {lvVersion})...");
            int attempts = Math.Max(1, 1 + Math.Max(0, opts.RetryBuilds));
            CommandResult? last = null;
            for (int attempt = 1; attempt <= attempts; attempt++)
            {
                var result = RunProcess(labviewCliPath, workingDir, args, lvcliTimeout);
                if (!string.IsNullOrWhiteSpace(logFilePath) && File.Exists(logFilePath) && !logPaths.Contains(logFilePath))
                {
                    logPaths.Add(logFilePath);
                }
                var status = result.ExitCode == 0 ? "success" : "fail";
                summaryLogs.Add(logFilePath ?? string.Empty);
                last = new CommandResult($"labviewcli-{buildSpec.ToLowerInvariant().Replace(' ', '-')}", status, result.ExitCode, result.DurationMs, new
                {
                    projectPath = project,
                    targetName,
                    buildSpec,
                    bitness,
                    lvVersion,
                    labviewCliPath,
                    labviewPath,
                    portNumber,
                    logFilePath,
                    exit = result.ExitCode,
                    stdout = result.StdOut,
                    stderr = result.StdErr,
                    attempt,
                    attempts
                });
                if (result.ExitCode == 0 || attempt == attempts)
                {
                    if (!string.Equals(status, "success", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(logFilePath) && File.Exists(logFilePath))
                    {
                        var tail = ReadTail(logFilePath);
                        if (!string.IsNullOrWhiteSpace(tail))
                        {
                            log($"[sd-ppl-lvcli] tail of {logFilePath}:{Environment.NewLine}{tail}");
                        }
                    }
                    return last;
                }
                log($"[sd-ppl-lvcli] attempt {attempt} failed for \"{buildSpec}\" (exit {result.ExitCode}); retrying...");
            }
            return last!;
        }

        CommandResult RunLabviewCliMassCompile(string directoryToCompile, string workingDir, string logFilePath)
        {
            var lvcliTimeout = opts.LabviewCliTimeoutSec.HasValue && opts.LabviewCliTimeoutSec.Value > 0
                ? opts.LabviewCliTimeoutSec.Value
                : opts.TimeoutSeconds;

            var args = new List<string>
            {
                "-OperationName", "MassCompile",
                "-DirectoryToCompile", directoryToCompile
            };
            if (!string.IsNullOrWhiteSpace(logFilePath))
            {
                try
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(logFilePath)!);
                }
                catch { }
                args.AddRange(new[] { "-MassCompileLogFile", logFilePath });
            }
            if (!string.IsNullOrWhiteSpace(labviewPath))
            {
                args.AddRange(new[] { "-LabVIEWPath", labviewPath! });
            }
            if (portNumber.HasValue)
            {
                args.AddRange(new[] { "-PortNumber", portNumber.Value.ToString() });
            }

            log($"[sd-ppl-lvcli] LabVIEWCLI MassCompile ({bitness}-bit {lvVersion}) dir={directoryToCompile}...");
            var result = RunProcess(labviewCliPath, workingDir, args, lvcliTimeout);
            if (!string.IsNullOrWhiteSpace(logFilePath) && File.Exists(logFilePath) && !logPaths.Contains(logFilePath))
            {
                logPaths.Add(logFilePath);
            }

            var status = result.ExitCode == 0 ? "success" : "fail";
            summaryLogs.Add(logFilePath ?? string.Empty);
            if (!string.Equals(status, "success", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(logFilePath) && File.Exists(logFilePath))
            {
                var tail = ReadTail(logFilePath);
                if (!string.IsNullOrWhiteSpace(tail))
                {
                    log($"[sd-ppl-lvcli] tail of {logFilePath}:{Environment.NewLine}{tail}");
                }
            }
            return new CommandResult("labviewcli-mass-compile", status, result.ExitCode, result.DurationMs, new
            {
                directoryToCompile,
                bitness,
                lvVersion,
                labviewCliPath,
                labviewPath,
                portNumber,
                logFilePath,
                exit = result.ExitCode,
                stdout = result.StdOut,
                stderr = result.StdErr
            });
        }

        CommandResult RunLabviewCliClose(string workingDir, string? logFilePath = null)
        {
            var lvcliTimeout = opts.LabviewCliTimeoutSec.HasValue && opts.LabviewCliTimeoutSec.Value > 0
                ? opts.LabviewCliTimeoutSec.Value
                : opts.TimeoutSeconds;

            var args = new List<string> { "-OperationName", "CloseLabVIEW" };
            if (!string.IsNullOrWhiteSpace(logFilePath))
            {
                try
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(logFilePath)!);
                }
                catch { }
                args.AddRange(new[] { "-LogFilePath", logFilePath });
            }
            if (!string.IsNullOrWhiteSpace(labviewPath))
            {
                args.AddRange(new[] { "-LabVIEWPath", labviewPath! });
            }
            if (portNumber.HasValue)
            {
                args.AddRange(new[] { "-PortNumber", portNumber.Value.ToString() });
            }

            log($"[sd-ppl-lvcli] LabVIEWCLI CloseLabVIEW ({bitness}-bit {lvVersion})...");
            var result = RunProcess(labviewCliPath, workingDir, args, lvcliTimeout);
            var connectionIssue = result.ExitCode == -350000 || IsConnectionIssue(result.StdOut) || IsConnectionIssue(result.StdErr);
            string status;
            int exitForResult;
            if (result.ExitCode == 0)
            {
                status = "success";
                exitForResult = 0;
            }
            else if (connectionIssue)
            {
                // LabVIEW not running / could not connect — treat as skip so we don't fail cleanup paths.
                status = "skip";
                exitForResult = 0;
            }
            else
            {
                status = "fail";
                exitForResult = result.ExitCode;
            }
            summaryLogs.Add(logFilePath ?? string.Empty);
            return new CommandResult("labviewcli-close", status, exitForResult, result.DurationMs, new
            {
                bitness,
                lvVersion,
                labviewCliPath,
                labviewPath,
                portNumber,
                logFilePath,
                exit = result.ExitCode,
                stdout = result.StdOut,
                stderr = result.StdErr,
                connectionIssue
            });
        }

        CommandResult RunRequirementsSummary(Action<string> log, Options opts, string repo)
        {
            var swReq = Stopwatch.StartNew();
            var script = Path.Combine(repo, "scripts", "run-requirements-summary-task.ps1");
            if (!File.Exists(script))
            {
                log($"[sd-ppl-lvcli] requirements summary script not found; skipping: {script}");
                return new CommandResult("requirements-summary", "skip", 0, swReq.ElapsedMilliseconds, new { script, reason = "missing script" });
            }

            var args = new List<string>
            {
                "-NoProfile",
                "-File", script,
                "-Csv", "docs/requirements/requirements.csv",
                "-Summary", "reports/requirements-summary.md"
            };

            log($"[sd-ppl-lvcli] regenerating requirements summary via {script}");
            var result = RunPwsh(opts, args, opts.TimeoutSeconds);
            var status = result.ExitCode == 0 ? "success" : "fail";
            return new CommandResult("requirements-summary", status, result.ExitCode, swReq.ElapsedMilliseconds, new
            {
                script,
                exit = result.ExitCode,
                stdout = result.StdOut,
                stderr = result.StdErr
            });
        }

        CommandResult ExtractSourceDist(string zipPath, string dest, out string? sdRoot)
        {
            var swExtract = Stopwatch.StartNew();
            sdRoot = null;
            if (!File.Exists(zipPath))
            {
                return new CommandResult("extract-source-dist", "fail", 1, swExtract.ElapsedMilliseconds, new { zipPath, extractDir = dest, error = "source-distribution.zip not found" });
            }

            try
            {
                if (Directory.Exists(dest))
                {
                    Directory.Delete(dest, true);
                }
            }
            catch
            {
                // best-effort clean
            }

            try
            {
                Directory.CreateDirectory(dest);
                ZipFile.ExtractToDirectory(zipPath, dest, true);
                var lvproj = Directory.GetFiles(dest, "lv_icon_editor.lvproj", SearchOption.AllDirectories).FirstOrDefault();
                if (!string.IsNullOrWhiteSpace(lvproj))
                {
                    sdRoot = Path.GetDirectoryName(lvproj)!;
                }
                else
                {
                    var repoRootCandidate = Path.Combine(dest, "repos", "labview-icon-editor-final-fork");
                    if (Directory.Exists(repoRootCandidate))
                    {
                        sdRoot = repoRootCandidate;
                        var lvprojTarget = Path.Combine(sdRoot, "lv_icon_editor.lvproj");
                        if (!File.Exists(lvprojTarget) && File.Exists(projectPath))
                        {
                            File.Copy(projectPath, lvprojTarget, true);
                            var aliases = Path.Combine(repo, "lv_icon_editor.aliases");
                            if (File.Exists(aliases))
                            {
                                File.Copy(aliases, Path.Combine(sdRoot, "lv_icon_editor.aliases"), true);
                            }
                            var lvlps = Path.Combine(repo, "lv_icon_editor.lvlps");
                            if (File.Exists(lvlps))
                            {
                                File.Copy(lvlps, Path.Combine(sdRoot, "lv_icon_editor.lvlps"), true);
                            }
                            lvproj = lvprojTarget;
                        }
                    }
                }
                if (sdRoot != null)
                {
                    var scriptsSource = Path.Combine(repo, "scripts");
                    var scriptsDest = Path.Combine(sdRoot, "scripts");
                    CopyDirectory(scriptsSource, scriptsDest, overwrite: true);

                    var toolingSource = Path.Combine(repo, "Tooling");
                    var toolingDest = Path.Combine(sdRoot, "Tooling");
                    CopyDirectory(toolingSource, toolingDest, overwrite: true);
                }
                var status = sdRoot != null ? "success" : "fail";
                var exitCode = status == "success" ? 0 : 1;
                return new CommandResult("extract-source-dist", status, exitCode, swExtract.ElapsedMilliseconds, new
                {
                    zipPath,
                    extractDir = dest,
                    extractedRoot = sdRoot,
                    lvprojPath = lvproj
                });
            }
            catch (Exception ex)
            {
                return new CommandResult("extract-source-dist", "fail", 1, swExtract.ElapsedMilliseconds, new { zipPath, extractDir = dest, error = ex.Message });
            }
        }

        CommandResult EnsureSourceDistZip(string zipPath, string baseRepo)
        {
            var swZip = Stopwatch.StartNew();
            if (File.Exists(zipPath))
            {
                return new CommandResult("zip-source-dist", "success", 0, swZip.ElapsedMilliseconds, new { zipPath, created = false, reason = "existing" });
            }

            var sourceDir = Path.Combine(baseRepo, "builds", "Source Distribution");
            if (!Directory.Exists(sourceDir))
            {
                return new CommandResult("zip-source-dist", "fail", 1, swZip.ElapsedMilliseconds, new { zipPath, sourceDir, error = "Source Distribution directory not found to create zip" });
            }

            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(zipPath)!);
                if (File.Exists(zipPath))
                {
                    File.Delete(zipPath);
                }
                ZipFile.CreateFromDirectory(sourceDir, zipPath, CompressionLevel.Optimal, includeBaseDirectory: false);
                return new CommandResult("zip-source-dist", "success", 0, swZip.ElapsedMilliseconds, new { zipPath, sourceDir, created = true });
            }
            catch (Exception ex)
            {
                return new CommandResult("zip-source-dist", "fail", 1, swZip.ElapsedMilliseconds, new { zipPath, sourceDir, error = ex.Message });
            }
        }

        try
        {
            var cliPath = string.Empty;
            try { cliPath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty; } catch { cliPath = string.Empty; }
            var cliSha = GetGitSha();
            var cliRid = System.Runtime.InteropServices.RuntimeInformation.RuntimeIdentifier;
            var cliStamp = string.Empty;
            try
            {
                if (!string.IsNullOrWhiteSpace(cliPath) && File.Exists(cliPath))
                {
                    cliStamp = File.GetLastWriteTimeUtc(cliPath).ToString("o");
                }
            }
            catch { cliStamp = string.Empty; }
            log($"[sd-ppl-lvcli] repo={repoDisplay}, cli={cliPath}, sha={cliSha}, rid={cliRid}, built={cliStamp}");

            if (!string.IsNullOrWhiteSpace(opts.ExpectSha) && !string.Equals(opts.ExpectSha, cliSha, StringComparison.OrdinalIgnoreCase))
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { repo = repoDisplay, expectedSha = opts.ExpectSha, actualSha = cliSha, error = "CLI git SHA does not match --expect-sha" });
            }

            if (!Directory.Exists(repo) || !Directory.Exists(Path.Combine(repo, ".git")))
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { repo = repoDisplay, error = "Repository not found or missing .git (expect repo root).", repoExists = Directory.Exists(repo), gitExists = Directory.Exists(Path.Combine(repo, ".git")) });
            }

            if (IsPathUnderProgramFiles(repo))
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { repo = repoDisplay, error = "Refusing to run against a repo under Program Files; supply a writable repo path." });
            }

            TryHandleStaleLock(lockPath);

            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(lockPath)!);
                lockStream = new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
                lockStream.SetLength(0);
                using var writer = new StreamWriter(lockStream, Encoding.UTF8, 1024, leaveOpen: true);
                writer.Write($"pid={Process.GetCurrentProcess().Id}; started={DateTime.UtcNow:o}");
                writer.Flush();
                log($"[sd-ppl-lvcli] lock acquired at {lockPath}");
            }
            catch (Exception ex)
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { lockPath, error = "Failed to acquire exclusive lock", exception = ex.Message });
            }

            try
            {
                if (!Directory.Exists(tempRoot))
                {
                    return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { tempRoot, error = $"Temp root not found. Create short path {tempRoot} or override --temp-root." });
                }
                if (!Directory.Exists(worktreeBase))
                {
                    return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { worktreeBase, error = $"Worktree root not found. Create short path {worktreeBase} or override --worktree-root." });
                }
                Directory.CreateDirectory(tempRoot);
                Directory.CreateDirectory(logsDir);
                Directory.CreateDirectory(extractDir);
                var probe = Path.Combine(tempRoot, ".write-test");
                File.WriteAllText(probe, "sd-ppl-lvcli");
                File.Delete(probe);
                var wtProbe = Path.Combine(worktreeBase, ".write-test");
                File.WriteAllText(wtProbe, "sd-ppl-lvcli");
                File.Delete(wtProbe);
            }
            catch (Exception ex)
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { tempRoot, logsDir, extractDir, worktreeBase, error = $"Temp/log/worktree path not writable: {ex.Message}" });
            }

            Environment.SetEnvironmentVariable("TMP", tempRoot);
            Environment.SetEnvironmentVariable("TEMP", tempRoot);
            Environment.SetEnvironmentVariable("TMPDIR", tempRoot);
            log($"[sd-ppl-lvcli] temp={tempRoot}, logs={logsDir}, extract={extractDir}");
            log($"[sd-ppl-lvcli] lv-version={lvVersion}, bitness={bitness}, labview-cli={labviewCliPath}, labview.exe={(labviewPath ?? "(auto)")}, port={(portNumber?.ToString() ?? "auto")}");

            if (string.IsNullOrWhiteSpace(labviewPath))
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { lvVersion, bitness, error = "LabVIEW.exe not found for requested version/bitness" });
            }

            if (!portNumber.HasValue)
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { lvVersion, bitness, labviewPath, error = "Unable to resolve LabVIEW server.tcp.port (missing in INI and no fallback available)" });
            }

            if (!string.IsNullOrWhiteSpace(labviewCliPath) && Path.IsPathRooted(labviewCliPath) && !File.Exists(labviewCliPath))
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { labviewCliPath, error = "Specified LabVIEWCLI path not found" });
            }

            if (string.IsNullOrWhiteSpace(labviewPath))
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { lvVersion, bitness, error = "LabVIEW.exe not found for requested version/bitness" });
            }

            // g-cli presence check
            var gcliCheck = RunProcess("g-cli", repo, new[] { "--version" }, 30);
            if (gcliCheck.ExitCode != 0)
            {
                return new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { error = "g-cli not available or failed to run", exit = gcliCheck.ExitCode, stdout = gcliCheck.StdOut, stderr = gcliCheck.StdErr });
            }

            if (!string.IsNullOrWhiteSpace(opts.LabviewPath) && string.IsNullOrWhiteSpace(labviewPath))
            {
                Record(new CommandResult("sd-ppl-lvcli", "fail", 1, sw.ElapsedMilliseconds, new { requestedLabviewPath = opts.LabviewPath, error = "Specified LabVIEW.exe path not found" }), "labview-path-check");
            }

            if (pipelineOk)
            {
                PhaseStart("unbind-current");
                Record(RunBindUnbind(log, optsWithVersion, repo, bitness, mode: "unbind"), "unbind-current");
            }

            if (pipelineOk)
            {
                PhaseStart("worktree-add");
                try
                {
                    if (Directory.Exists(worktreePath))
                    {
                        if (!opts.ForceWorktree)
                        {
                            Record(new CommandResult("worktree-add", "fail", 1, 0, new { worktreePath, error = "Worktree path already exists; rerun with --force-worktree to reuse/remove." }), "worktree-add");
                            pipelineOk = false;
                        }
                        else
                        {
                            try { Directory.Delete(worktreePath, true); } catch { }
                        }
                    }
                    if (pipelineOk)
                    {
                        Directory.CreateDirectory(worktreeBase);
                        var probe = Path.Combine(worktreeBase, ".write-test");
                        File.WriteAllText(probe, "sd-ppl-lvcli");
                        File.Delete(probe);
                    }
                    var wtResult = RunProcess("git", repo, new[] { "worktree", "add", "--force", "--detach", worktreePath, "HEAD" }, opts.TimeoutSeconds);
                    if (wtResult.ExitCode != 0)
                    {
                        Record(new CommandResult("worktree-add", "fail", wtResult.ExitCode, wtResult.DurationMs, new { worktreePath, stdout = wtResult.StdOut, stderr = wtResult.StdErr }), "worktree-add");
                        pipelineOk = false;
                    }
                    else
                    {
                        workingRepo = worktreePath;
                        projectPath = Path.Combine(workingRepo, "lv_icon_editor.lvproj");
                        Record(new CommandResult("worktree-add", "success", 0, wtResult.DurationMs, new { worktreePath, repo = mainRepo }), "worktree-add");
                        worktreeCreated = true;

                        var detectedLv = ResolveLabviewVersion(workingRepo, opts, log, fallback: lvVersion);
                        var detectedBitness = ResolveLabviewBitness(workingRepo, opts, log, fallback: bitness);
                        if (!string.IsNullOrWhiteSpace(detectedLv) && !string.Equals(detectedLv, lvVersion, StringComparison.OrdinalIgnoreCase))
                        {
                            lvVersion = detectedLv!;
                            log($"[sd-ppl-lvcli] lv-version updated from worktree vipb: {lvVersion}");
                        }
                        if (!string.IsNullOrWhiteSpace(detectedBitness) && !string.Equals(detectedBitness, bitness, StringComparison.OrdinalIgnoreCase))
                        {
                            bitness = detectedBitness;
                            log($"[sd-ppl-lvcli] bitness updated from worktree vipb: {bitness}");
                        }
                        optsWithVersion = optsWithVersion with { LvVersion = lvVersion, Bitness = bitness };
                        labviewPath = ResolveLabviewExePath(lvVersion, bitness, opts.LabviewPath, log);
                        portNumber = opts.LabviewPort ?? ResolveLabviewPort(labviewPath, lvVersion, bitness, log);
                        if (string.IsNullOrWhiteSpace(labviewPath) || !portNumber.HasValue)
                        {
                            Record(new CommandResult("worktree-add", "fail", 1, 0, new { worktreePath, lvVersion, bitness, labviewPath, port = portNumber, error = "Resolved LabVIEW path/port is missing after worktree detection" }), "worktree-add");
                            pipelineOk = false;
                        }
                    }
                }
                catch (Exception ex)
                {
                    Record(new CommandResult("worktree-add", "fail", 1, 0, new { worktreePath, error = ex.Message }), "worktree-add");
                    pipelineOk = false;
                }
            }

            if (pipelineOk)
            {
                if (HasConflictingToken(workingRepo, lvVersion, bitness))
                {
                    log($"[sd-ppl-lvcli] WARNING: Found conflicting LocalHost.LibraryPaths token for {lvVersion} {bitness}-bit; proceeding may reuse a different repo. Consider unbinding first.");
                }
                PhaseStart("bind-repo");
                var bindRepo = Record(RunBindUnbind(log, optsWithVersion, workingRepo, bitness, mode: "bind"), "bind-repo");
                repoBound = string.Equals(bindRepo.Status, "success", StringComparison.OrdinalIgnoreCase);
            }

            sourceDistZip = ResolveSourceDistZip(opts.SourceDistZip, workingRepo);

            if (pipelineOk)
            {
                sdLogFile = Path.Combine(logsDir, $"{SanitizeFileName($"source-distribution-{bitness}")}.log");
                PhaseStart("build-source-distribution");
                Record(RunLabviewCliBuild("Source Distribution", projectPath, Path.GetDirectoryName(projectPath) ?? workingRepo, sdLogFile), "build-source-distribution");
            }

            if (pipelineOk)
            {
                PhaseStart("close-after-sd");
                Record(RunLabviewCliClose(workingRepo, Path.Combine(logsDir, $"{SanitizeFileName($"close-after-sd-{bitness}")}.log")), "close-after-sd", affectsOutcome: false);
            }

            if (repoBound)
            {
                PhaseStart("unbind-repo-post-sd");
                Record(RunBindUnbind(log, optsWithVersion, workingRepo, bitness, mode: "unbind"), "unbind-repo-post-sd", affectsOutcome: pipelineOk);
                repoBound = false;
            }

            if (pipelineOk)
            {
                PhaseStart("requirements-summary");
                Record(RunRequirementsSummary(log, optsWithVersion, workingRepo), "requirements-summary");

                if (baselineLvproj != null)
                {
                    try
                    {
                        var destDir = Path.Combine(workingRepo, "builds", "Source Distribution", "repos", repoName);
                        Directory.CreateDirectory(destDir);
                        var destPath = Path.Combine(destDir, Path.GetFileName(projectPath));
                        File.WriteAllBytes(destPath, baselineLvproj);
                        log($"[sd-ppl-lvcli] refreshed lvproj for zip: {GetRelativePathSafe(workingRepo, destPath)}");
                    }
                    catch (Exception ex)
                    {
                        log($"[sd-ppl-lvcli] failed to refresh lvproj into Source Distribution: {ex.Message}");
                    }
                }

                try
                {
                    var sdRepoRoot = Path.Combine(workingRepo, "builds", "Source Distribution", "repos", repoName);
                    Directory.CreateDirectory(sdRepoRoot);

                    var vscodeSource = Path.Combine(workingRepo, ".vscode");
                    if (Directory.Exists(vscodeSource))
                    {
                        CopyDirectory(vscodeSource, Path.Combine(sdRepoRoot, ".vscode"), overwrite: true);
                        log($"[sd-ppl-lvcli] bundled .vscode tasks into Source Distribution");
                    }

                    var configsSource = Path.Combine(workingRepo, "configs");
                    if (Directory.Exists(configsSource))
                    {
                        CopyDirectory(configsSource, Path.Combine(sdRepoRoot, "configs"), overwrite: true);
                        log($"[sd-ppl-lvcli] bundled configs into Source Distribution");
                    }

                    var scriptsSource = Path.Combine(workingRepo, "scripts");
                    if (Directory.Exists(scriptsSource))
                    {
                        CopyDirectory(scriptsSource, Path.Combine(sdRepoRoot, "scripts"), overwrite: true);
                        log($"[sd-ppl-lvcli] bundled scripts into Source Distribution");
                    }

                    var toolingSource = Path.Combine(workingRepo, "Tooling");
                    if (Directory.Exists(toolingSource))
                    {
                        // Publish self-contained OrchestrationCli into Tooling/bin/win-x64 if not present.
                        PublishOrchestrationCli(workingRepo, log, opts.TimeoutSeconds);
                        PublishRequirementsSummarizer(workingRepo, log, opts.TimeoutSeconds);
                        CopyDirectory(toolingSource, Path.Combine(sdRepoRoot, "Tooling"), overwrite: true);
                        log($"[sd-ppl-lvcli] bundled Tooling into Source Distribution");
                    }

                    var reportsSource = Path.Combine(workingRepo, "reports");
                    if (Directory.Exists(reportsSource))
                    {
                        CopyDirectory(reportsSource, Path.Combine(sdRepoRoot, "reports"), overwrite: true);
                        log($"[sd-ppl-lvcli] bundled reports into Source Distribution");
                    }
                }
                catch (Exception ex)
                {
                    log($"[sd-ppl-lvcli] WARNING: failed to bundle tooling into Source Distribution: {ex.Message}");
                }

                PhaseStart("zip-source-dist");
                Record(EnsureSourceDistZip(sourceDistZip, workingRepo), "zip-source-dist");
            }

            if (pipelineOk)
            {
                PhaseStart("extract-source-dist");
                var extractResult = Record(ExtractSourceDist(sourceDistZip, extractDir, out extractedRoot), "extract-source-dist");
                pipelineOk = pipelineOk && string.Equals(extractResult.Status, "success", StringComparison.OrdinalIgnoreCase) && extractedRoot != null;
            }

            if (pipelineOk && extractedRoot != null)
            {
                try
                {
                    var sdPayload = Path.Combine(extractDir, "builds", "Source Distribution");
                    var copiedPayload = false;
                    if (Directory.Exists(sdPayload))
                    {
                        CopyDirectory(sdPayload, extractedRoot, overwrite: true);
                        copiedPayload = true;
                        log($"[sd-ppl-lvcli] copied extracted Source Distribution into extracted root: {sdPayload} -> {extractedRoot}");
                    }

                    var wCandidates = new[]
                    {
                        Path.Combine(extractedRoot, "w"),
                        Path.Combine(extractDir, "w"),
                    };

                    foreach (var wPath in wCandidates.Where(Directory.Exists))
                    {
                        var subDirs = Directory.GetDirectories(wPath);
                        if (subDirs.Length == 1)
                        {
                            var nested = subDirs[0];
                            CopyDirectory(nested, extractedRoot, overwrite: true);
                            copiedPayload = true;
                            log($"[sd-ppl-lvcli] flattened nested worktree folder into extracted root: {nested} -> {extractedRoot}");
                        }
                    }

                    if (!copiedPayload)
                    {
                        log($"[sd-ppl-lvcli] WARNING: No Source Distribution payload found to flatten under {extractDir}; extracted root may be missing resources.");
                    }
                }
                catch (Exception ex)
                {
                    log($"[sd-ppl-lvcli] failed to flatten Source Distribution into extracted root: {ex.Message}");
                }
            }

            if (pipelineOk && extractedRoot != null)
            {
                if (HasConflictingToken(extractedRoot, lvVersion, bitness))
                {
                    log($"[sd-ppl-lvcli] WARNING: Conflicting LocalHost.LibraryPaths token detected for extracted SD ({lvVersion} {bitness}-bit); proceeding may reuse another repo.");
                }
                PhaseStart("bind-extracted-sd");
                var bindExtract = Record(RunBindUnbind(log, optsWithVersion, extractedRoot, bitness, mode: "bind"), "bind-extracted-sd");
                extractedBound = string.Equals(bindExtract.Status, "success", StringComparison.OrdinalIgnoreCase);
            }

            if (pipelineOk && extractedRoot != null)
            {
                pplLogFile = Path.Combine(logsDir, $"{SanitizeFileName($"ppl-{bitness}")}.log");
                var pplProject = Path.Combine(extractedRoot, "lv_icon_editor.lvproj");
                PhaseStart("build-ppl");
                Record(RunLabviewCliBuild("Editor Packed Library", pplProject, extractedRoot, pplLogFile), "build-ppl");
            }

            if (extractedBound && extractedRoot != null)
            {
                PhaseStart("close-after-ppl");
                Record(RunLabviewCliClose(extractedRoot, Path.Combine(logsDir, $"{SanitizeFileName($"close-after-ppl-{bitness}")}.log")), "close-after-ppl", affectsOutcome: false);
                PhaseStart("unbind-extracted-sd");
                Record(RunBindUnbind(log, optsWithVersion, extractedRoot, bitness, mode: "unbind"), "unbind-extracted-sd", affectsOutcome: pipelineOk);
                extractedBound = false;
            }
        }
        finally
        {
            if (extractedBound && extractedRoot != null)
            {
                PhaseStart("close-after-ppl-final");
                Record(RunLabviewCliClose(extractedRoot, Path.Combine(logsDir, $"{SanitizeFileName($"close-after-ppl-final-{bitness}")}.log")), "close-after-ppl-final", affectsOutcome: false);
                PhaseStart("unbind-extracted-final");
                Record(RunBindUnbind(log, optsWithVersion, extractedRoot, bitness, mode: "unbind"), "unbind-extracted-final", affectsOutcome: false);
                extractedBound = false;
            }
            if (repoBound)
            {
                PhaseStart("close-repo-final");
                Record(RunLabviewCliClose(workingRepo, Path.Combine(logsDir, $"{SanitizeFileName($"close-repo-final-{bitness}")}.log")), "close-repo-final", affectsOutcome: false);
                PhaseStart("unbind-repo-final");
                Record(RunBindUnbind(log, optsWithVersion, workingRepo, bitness, mode: "unbind"), "unbind-repo-final", affectsOutcome: false);
                repoBound = false;
            }
            lockStream?.Dispose();
        }

        var failing = phases.FirstOrDefault(p => !string.Equals(p.Status, "success", StringComparison.OrdinalIgnoreCase));
        var overallExit = failing == null ? 0 : (failing.ExitCode == 0 ? 1 : failing.ExitCode);
        var finalStatus = overallExit == 0 ? "success" : "fail";

        if ((overallExit == 0 || copyOnFail) && worktreeCreated)
        {
            try
            {
                var sourceDistSource = Path.Combine(workingRepo, "builds", "Source Distribution");
                var sourceDistDest = Path.Combine(mainRepo, "builds", "Source Distribution");
                if (Directory.Exists(sourceDistSource))
                {
                    CopyDirectory(sourceDistSource, sourceDistDest, overwrite: true);
                    log($"[sd-ppl-lvcli] copied Source Distribution to main repo: src={sourceDistSource} ({GetRelativePathSafe(mainRepo, sourceDistSource)}), dest={sourceDistDest} ({GetRelativePathSafe(mainRepo, sourceDistDest)})");
                }

                var artifactsSource = Path.Combine(workingRepo, "builds", "artifacts");
                var artifactsDest = Path.Combine(mainRepo, "builds", "artifacts");
                if (Directory.Exists(artifactsSource))
                {
                    CopyDirectory(artifactsSource, artifactsDest, overwrite: true);
                    log($"[sd-ppl-lvcli] copied artifacts to main repo: src={artifactsSource} ({GetRelativePathSafe(mainRepo, artifactsSource)}), dest={artifactsDest} ({GetRelativePathSafe(mainRepo, artifactsDest)})");
                }

                var pplSource = Path.Combine(workingRepo, "resource", "plugins");
                var pplDest = Path.Combine(mainRepo, "resource", "plugins");
                if (Directory.Exists(pplSource))
                {
                    Directory.CreateDirectory(pplDest);
                    foreach (var file in Directory.GetFiles(pplSource, "lv_icon*.lvlibp*", SearchOption.TopDirectoryOnly))
                    {
                        var destFile = Path.Combine(pplDest, Path.GetFileName(file));
                        File.Copy(file, destFile, true);
                    }
                    log($"[sd-ppl-lvcli] copied PPL outputs to main repo plugins folder: src={pplSource} ({GetRelativePathSafe(mainRepo, pplSource)}), dest={pplDest} ({GetRelativePathSafe(mainRepo, pplDest)})");
                }
            }
            catch (Exception ex)
            {
                log($"[sd-ppl-lvcli] artifact copy from worktree failed: {ex.Message}");
            }
        }

        var logStash = Path.Combine(repo, "scripts", "log-stash", "Write-LogStashEntry.ps1");
        if (File.Exists(logStash))
        {
            try
            {
                var sourceDistAttachment = sourceDistZip;
                if (overallExit == 0 && worktreeCreated)
                {
                    var mainZipCandidate = ResolveSourceDistZip(opts.SourceDistZip, mainRepo);
                    if (File.Exists(mainZipCandidate))
                    {
                        sourceDistAttachment = mainZipCandidate;
                    }
                }

                var attachments = new List<string>();
                if (!string.IsNullOrWhiteSpace(sourceDistAttachment) && File.Exists(sourceDistAttachment)) attachments.Add(sourceDistAttachment);
                if (!string.IsNullOrWhiteSpace(sdLogFile) && File.Exists(sdLogFile)) attachments.Add(sdLogFile);
                if (!string.IsNullOrWhiteSpace(pplLogFile) && File.Exists(pplLogFile)) attachments.Add(pplLogFile);
                var args = new List<string>
                {
                    "-NoProfile", "-File", logStash,
                    "-RepositoryPath", repo,
                    "-Category", "sd-ppl-lvcli",
                    "-Label", "sd-ppl-labviewcli"
                };
                if (logPaths.Count > 0)
                {
                    args.Add("-LogPaths");
                    foreach (var p in logPaths)
                    {
                        var path = p;
                        if (Path.IsPathRooted(p))
                        {
                            if (Path.GetFullPath(p).StartsWith(Path.GetFullPath(repo), StringComparison.OrdinalIgnoreCase))
                            {
                                path = GetRelativePathSafe(repo, p);
                            }
                            else
                            {
                                path = Path.GetFileName(p);
                            }
                        }
                        args.Add(path);
                    }
                }
                if (attachments.Count > 0)
                {
                    args.Add("-AttachmentPaths");
                    foreach (var p in attachments)
                    {
                        var path = p;
                        if (Path.IsPathRooted(p))
                        {
                            if (Path.GetFullPath(p).StartsWith(Path.GetFullPath(repo), StringComparison.OrdinalIgnoreCase))
                            {
                                path = GetRelativePathSafe(repo, p);
                            }
                            else
                            {
                                path = Path.GetFileName(p);
                            }
                        }
                        args.Add(path);
                    }
                }
                args.AddRange(new[]
                {
                    "-Status", finalStatus,
                    "-ProducerScript", "OrchestrationCli",
                    "-ProducerTask", "sd-ppl-lvcli",
                    "-StartedAtUtc", DateTime.UtcNow.AddMilliseconds(-sw.ElapsedMilliseconds).ToString("o"),
                    "-DurationMs", sw.ElapsedMilliseconds.ToString()
                });
                var stashResult = RunProcess(opts.Pwsh, repo, args, opts.TimeoutSeconds);
                if (stashResult.ExitCode != 0)
                {
                    log($"log-stash bundle failed (exit {stashResult.ExitCode}): {stashResult.StdErr}");
                }
            }
            catch (Exception ex)
            {
                log($"log-stash bundle skipped: {ex.Message}");
            }
        }
        else
        {
            log("log-stash helper not found; skipping bundle.");
        }

        if (worktreeCreated)
        {
            try
            {
                RunProcess("git", mainRepo, new[] { "worktree", "remove", "--force", worktreePath }, opts.TimeoutSeconds);
                if (Directory.Exists(worktreePath))
                {
                    Directory.Delete(worktreePath, true);
                }
                log($"[sd-ppl-lvcli] cleaned worktree at {worktreePath}");
            }
            catch (Exception ex)
            {
                log($"[sd-ppl-lvcli] failed to remove worktree {worktreePath}: {ex.Message}. If still present, close handles and delete manually.");
            }
        }

        var summary = new StringBuilder();
        summary.Append($"status={finalStatus}; lv-version={lvVersion}; bitness={bitness}; labview-cli={labviewCliPath}; labview.exe={(labviewPath ?? "(auto)")} port={(portNumber?.ToString() ?? "auto")}; lvcli-timeout={opts.LabviewCliTimeoutSec?.ToString() ?? opts.TimeoutSeconds.ToString()}; temp={tempRoot}; logs={logsDir}; extract={extractDir}");
        if (summaryLogs.Count > 0)
        {
            summary.Append($"; labviewcli-logs={string.Join('|', summaryLogs.Where(s => !string.IsNullOrWhiteSpace(s)))}");
        }
        log($"[sd-ppl-lvcli][summary] {summary}");

        return new CommandResult("sd-ppl-lvcli", finalStatus, overallExit, sw.ElapsedMilliseconds, new
        {
            lvVersion,
            bitness,
            labviewCliPath,
            labviewPath,
            portNumber,
            projectPath,
            targetName,
            tempRoot,
            logsDir,
            extractDir,
            lockPath,
            worktreePath = worktreeCreated ? worktreePath : null,
            workingRepo,
            mainRepo,
            sourceDistZip,
            extractedRoot,
            logPaths,
            summaryLogs,
            phases
        });
    }

    private static CommandResult RunVipmInstall(Action<string> log, Options opts, string repo, string bitness)
    {
        var lvVersion = string.IsNullOrWhiteSpace(opts.LvVersion) ? "2021" : opts.LvVersion!;
        var vipcPath = string.IsNullOrWhiteSpace(opts.VipcPath)
            ? Path.Combine(repo, "runner_dependencies.vipc")
            : (Path.IsPathRooted(opts.VipcPath) ? opts.VipcPath! : Path.Combine(repo, opts.VipcPath));

        if (!File.Exists(vipcPath))
        {
            var missingDetails = new
            {
                bitness,
                lvVersion,
                vipcPath,
                stdout = string.Empty,
                stderr = $"VIPC not found at {vipcPath}"
            };
            return new CommandResult("vipm-install", "fail", 1, 0, missingDetails);
        }

        var argList = new List<string>
        {
            "--labview-version", lvVersion,
            "--labview-bitness", bitness,
            "install", vipcPath
        };

        log($"vipm install ({bitness}-bit, {lvVersion}) vipc={vipcPath}...");
        var result = RunProcess("vipm", repo, argList, opts.TimeoutSeconds);
        var status = result.ExitCode == 0 ? "success" : "fail";
        var details = new
        {
            bitness,
            lvVersion,
            vipcPath,
            exit = result.ExitCode,
            stdout = result.StdOut,
            stderr = result.StdErr
        };
        return new CommandResult("vipm-install", status, result.ExitCode, result.DurationMs, details);
    }

    private static CommandResult RunViComparePreflight(Action<string> log, Options opts, string repo, string bitness)
    {
        var script = Path.Combine(repo, "tools", "icon-editor", "Replay-ViCompareScenario.ps1");
        var vipbBlock = BlockIfVipbTooOld("vi-compare-preflight", repo, script, 2025);
        if (vipbBlock != null) return vipbBlock;
        var compareLvVersion = !string.IsNullOrWhiteSpace(opts.LvVersion)
            ? opts.LvVersion!
            : GetLabviewVersionFromVipb(repo) ?? "2025";
        CommandResult? bindResult = null;

        // VIPM verify/install
        var vipmCheck = RunVipmVerify(log, opts, repo, bitness);
        if (!vipmCheck.Status.Equals("success", StringComparison.OrdinalIgnoreCase))
        {
            var vipmInstall = RunVipmInstall(log, opts, repo, bitness);
            if (!vipmInstall.Status.Equals("success", StringComparison.OrdinalIgnoreCase))
            {
                var preflightDetails = new
                {
                    bitness,
                    scriptPath = script,
                    lvVersion = compareLvVersion,
                    vipmInstall = vipmInstall.Details
                };
                return new CommandResult("vi-compare-preflight", "fail", vipmInstall.ExitCode, vipmInstall.DurationMs, preflightDetails);
            }

            vipmCheck = RunVipmVerify(log, opts, repo, bitness);
            if (!vipmCheck.Status.Equals("success", StringComparison.OrdinalIgnoreCase))
            {
                var preflightDetails = new
                {
                    bitness,
                    scriptPath = script,
                    lvVersion = compareLvVersion,
                    vipmCheck = vipmCheck.Details
                };
                return new CommandResult("vi-compare-preflight", "fail", vipmCheck.ExitCode, vipmCheck.DurationMs, preflightDetails);
            }
        }

        // Token conflict check and optional unbind/bind
        var conflict = HasConflictingToken(repo, compareLvVersion, bitness);
        if (conflict && !opts.AutoBindDevmode)
        {
            var preflightDetails = new
            {
                bitness,
                scriptPath = script,
                lvVersion = compareLvVersion,
                devmodeRequired = opts.RequireDevmode,
                devmodeBound = false,
                exit = 1,
                stdout = string.Empty,
                stderr = "Conflicting LocalHost.LibraryPaths token found; rerun with --auto-bind-devmode or clear dev mode."
            };
            return new CommandResult("vi-compare-preflight", "fail", 1, 0, preflightDetails);
        }
        var bindTimeout = Math.Min(opts.TimeoutSeconds > 0 ? opts.TimeoutSeconds : 60, 60);
        var bindOpts = opts with { TimeoutSeconds = bindTimeout, LvVersion = compareLvVersion };
        if (conflict && opts.AutoBindDevmode)
        {
            log($"devmode-unbind ({bitness}-bit, {compareLvVersion}) before vi-compare (conflicting token)...");
            var unbindResult = RunBindUnbind(log, bindOpts, repo, bitness, mode: "unbind");
            if (!unbindResult.Status.Equals("success", StringComparison.OrdinalIgnoreCase))
            {
                var preflightDetails = new
                {
                    bitness,
                    scriptPath = script,
                    lvVersion = compareLvVersion,
                    devmodeUnbindStatus = unbindResult.Status,
                    devmodeUnbindExit = unbindResult.ExitCode,
                    devmodeUnbindStdout = (unbindResult.Details as dynamic)?.stdout,
                    devmodeUnbindStderr = (unbindResult.Details as dynamic)?.stderr,
                    devmodeRequired = opts.RequireDevmode,
                    devmodeBound = false,
                    exit = unbindResult.ExitCode,
                    stdout = string.Empty,
                    stderr = "Conflicting LocalHost.LibraryPaths token could not be cleared before vi-compare."
                };
                return new CommandResult("vi-compare-preflight", "fail", unbindResult.ExitCode, unbindResult.DurationMs, preflightDetails);
            }
        }

        if (opts.RequireDevmode)
        {
            var tokenPresent = TokenPresent(repo, compareLvVersion, bitness);
            if (!tokenPresent && opts.AutoBindDevmode)
            {
                log($"devmode-bind ({bitness}-bit, {compareLvVersion}) before vi-compare...");
                bindResult = RunBindUnbind(log, bindOpts, repo, bitness, mode: "bind");
                tokenPresent = bindResult.Status.Equals("success", StringComparison.OrdinalIgnoreCase) && TokenPresent(repo, compareLvVersion, bitness);
                if (!tokenPresent)
                {
                    var details = new
                    {
                        bitness,
                        scriptPath = script,
                        lvVersion = compareLvVersion,
                        devmodeBindStatus = bindResult.Status,
                        devmodeBindExit = bindResult.ExitCode,
                        devmodeBindStdout = (bindResult.Details as dynamic)?.stdout,
                        devmodeBindStderr = (bindResult.Details as dynamic)?.stderr,
                        devmodeRequired = true,
                        devmodeBound = false,
                        exit = bindResult.ExitCode,
                        stdout = (bindResult.Details as dynamic)?.stdout ?? string.Empty,
                        stderr = (bindResult.Details as dynamic)?.stderr ?? "Dev-mode token not present; vi-compare preflight failed."
                    };
                    return new CommandResult("vi-compare-preflight", "fail", bindResult.ExitCode, bindResult.DurationMs, details);
                }
            }
            else if (!tokenPresent && !opts.AutoBindDevmode)
            {
                var details = new
                {
                    bitness,
                    scriptPath = script,
                    lvVersion = compareLvVersion,
                    devmodeRequired = true,
                    devmodeBound = false,
                    exit = 1,
                    stdout = string.Empty,
                    stderr = "Dev-mode token not present; rerun with --auto-bind-devmode or bind manually."
                };
                return new CommandResult("vi-compare-preflight", "fail", 1, 0, details);
            }
        }

        var successDetails = new
        {
            bitness,
            scriptPath = script,
            lvVersion = compareLvVersion,
            vipm = vipmCheck.Details
        };
        return new CommandResult("vi-compare-preflight", "success", 0, 0, successDetails);
    }

    private static CommandResult RunVipmVerify(Action<string> log, Options opts, string repo, string bitness)
    {
        var lvVersion = string.IsNullOrWhiteSpace(opts.LvVersion) ? "2021" : opts.LvVersion!;

        // Resolve required packages from manifest or VIPC
        var manifestPath = string.IsNullOrWhiteSpace(opts.VipmManifestPath)
            ? Path.Combine(repo, "configs", "vipm-required.sample.json")
            : (Path.IsPathRooted(opts.VipmManifestPath) ? opts.VipmManifestPath! : Path.Combine(repo, opts.VipmManifestPath));
        var vipcPath = string.IsNullOrWhiteSpace(opts.VipcPath)
            ? Path.Combine(repo, "runner_dependencies.vipc")
            : (Path.IsPathRooted(opts.VipcPath) ? opts.VipcPath! : Path.Combine(repo, opts.VipcPath));

        List<VipmPackage>? requiredPackages = null;
        string? sourceType = null;

        if (File.Exists(manifestPath))
        {
            try
            {
                var raw = File.ReadAllText(manifestPath);
                var manifest = JsonSerializer.Deserialize<VipmManifest>(raw, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                manifest ??= new VipmManifest { Packages = new List<VipmPackage>() };
                requiredPackages = manifest.Packages;
                sourceType = "manifest";
            }
            catch (Exception ex)
            {
                var failDetails = new
                {
                    bitness,
                    lvVersion,
                    manifestPath,
                    stdout = string.Empty,
                    stderr = $"Failed to parse manifest: {ex.Message}"
                };
                return new CommandResult("vipm-verify", "fail", 1, 0, failDetails);
            }
        }

        if (requiredPackages == null)
        {
            if (!File.Exists(vipcPath))
            {
                var missingDetails = new
                {
                    bitness,
                    lvVersion,
                    manifestPath,
                    vipcPath,
                    stdout = string.Empty,
                    stderr = $"VIPC not found at {vipcPath}"
                };
                return new CommandResult("vipm-verify", "fail", 1, 0, missingDetails);
            }

            var vipcArgs = new List<string> { "list", vipcPath };
            var vipcList = RunProcess("vipm", repo, vipcArgs, opts.TimeoutSeconds);
            if (vipcList.ExitCode != 0)
            {
                var failDetails = new
                {
                    bitness,
                    lvVersion,
                    manifestPath,
                    vipcPath,
                    exit = vipcList.ExitCode,
                    stdout = vipcList.StdOut,
                    stderr = vipcList.StdErr
                };
                return new CommandResult("vipm-verify", "fail", vipcList.ExitCode, vipcList.DurationMs, failDetails);
            }

            var vipcPackages = ParseVipmList(vipcList.StdOut);
            requiredPackages = vipcPackages
                .Select(kv => new VipmPackage { Name = kv.Key, PackageId = kv.Key, MinVersion = kv.Value })
                .ToList();
            sourceType = "vipc";
        }

        var argList = new List<string>
        {
            "--labview-version", lvVersion,
            "--labview-bitness", bitness,
            "list", "--installed"
        };

        log($"vipm verify ({bitness}-bit, {lvVersion}) manifest={manifestPath}...");
        var result = RunProcess("vipm", repo, argList, opts.TimeoutSeconds);
        if (result.ExitCode != 0)
        {
            var failDetails = new
            {
                bitness,
                lvVersion,
                manifestPath,
                exit = result.ExitCode,
                stdout = result.StdOut,
                stderr = result.StdErr
            };
            return new CommandResult("vipm-verify", "fail", result.ExitCode, result.DurationMs, failDetails);
        }

        var installed = ParseVipmList(result.StdOut);
        var missing = new List<object>();
        var outdated = new List<object>();
        foreach (var req in requiredPackages)
        {
            if (!installed.TryGetValue(req.PackageId.ToLowerInvariant(), out var installedVersion))
            {
                missing.Add(new { req.Name, req.PackageId, requiredMin = req.MinVersion, installed = (string?)null });
                continue;
            }
            if (!IsVersionAtLeast(installedVersion, req.MinVersion))
            {
                outdated.Add(new { req.Name, req.PackageId, requiredMin = req.MinVersion, installed = installedVersion });
            }
        }

        var status = (missing.Count == 0 && outdated.Count == 0) ? "success" : "fail";
        var details = new
        {
            bitness,
            lvVersion,
            manifestPath = sourceType == "manifest" ? manifestPath : null,
            vipcPath = sourceType == "vipc" ? vipcPath : null,
            source = sourceType,
            exit = result.ExitCode,
            missing,
            outdated,
            stdout = result.StdOut,
            stderr = result.StdErr
        };
        return new CommandResult("vipm-verify", status, status == "success" ? 0 : 1, result.DurationMs, details);
    }

    internal static CommandResult RunViAnalyzerForTest(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
        => RunViAnalyzer(log, opts, repo, bitness, fakeExit);

    private static CommandResult RunViAnalyzer(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
    {
        var script = Path.Combine(repo, "scripts", "vi-analyzer", "RunWithDevMode.ps1");
        var requestPath = opts.RequestPath;
        if (string.IsNullOrWhiteSpace(requestPath))
        {
            requestPath = Path.Combine(repo, "configs", "vi-analyzer-request.sample.json");
        }
        else if (!Path.IsPathRooted(requestPath))
        {
            requestPath = Path.Combine(repo, requestPath);
        }

        var argList = new List<string>
        {
            "-NoProfile",
            "-File", script,
            "-RequestPath", requestPath,
            "-RepositoryPath", repo
        };

        log($"vi-analyzer ({bitness}-bit) request={requestPath}...");
        var result = fakeExit.HasValue
            ? (ExitCode: fakeExit.Value, StdOut: string.Empty, StdErr: string.Empty, DurationMs: 0L)
            : RunPwsh(opts, argList, opts.TimeoutSeconds);
        var status = result.ExitCode == 0 ? "success" : "fail";
        var details = new
        {
            bitness,
            requestPath,
            scriptPath = script,
            exit = result.ExitCode,
            stdout = result.StdOut,
            stderr = result.StdErr
        };
        return new CommandResult("vi-analyzer", status, result.ExitCode, result.DurationMs, details);
    }

    internal static CommandResult RunMissingCheckForTest(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
        => RunMissingCheck(log, opts, repo, bitness, fakeExit);

    private static CommandResult RunMissingCheck(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
    {
        var script = Path.Combine(repo, "scripts", "missing-in-project", "RunMissingCheckWithGCLI.ps1");
        var projectPath = opts.ProjectPath;
        if (string.IsNullOrWhiteSpace(projectPath))
        {
            projectPath = Path.Combine(repo, "lv_icon_editor.lvproj");
        }
        else if (!Path.IsPathRooted(projectPath))
        {
            projectPath = Path.Combine(repo, projectPath);
        }

        var lvVersion = string.IsNullOrWhiteSpace(opts.LvVersion) ? "2021" : opts.LvVersion!;
        var argList = new List<string>
        {
            "-NoProfile",
            "-File", script,
            "-LVVersion", lvVersion,
            "-Arch", bitness,
            "-ProjectFile", projectPath
        };

        log($"missing-in-project ({bitness}-bit, {lvVersion}) project={projectPath}...");
        var result = fakeExit.HasValue
            ? (ExitCode: fakeExit.Value, StdOut: string.Empty, StdErr: string.Empty, DurationMs: 0L)
            : RunPwsh(opts, argList, opts.TimeoutSeconds);
        var status = result.ExitCode == 0 ? "success" : "fail";
        var details = new
        {
            bitness,
            lvVersion,
            projectPath,
            scriptPath = script,
            exit = result.ExitCode,
            stdout = result.StdOut,
            stderr = result.StdErr
        };
        return new CommandResult("missing-check", status, result.ExitCode, result.DurationMs, details);
    }

    internal static CommandResult RunViCompareForTest(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
        => RunViCompare(log, opts, repo, bitness, fakeExit);

    private static CommandResult RunViCompare(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
    {
        var script = Path.Combine(repo, "tools", "icon-editor", "Replay-ViCompareScenario.ps1");
        var scenarioPath = opts.ScenarioPath;
        if (string.IsNullOrWhiteSpace(scenarioPath))
        {
            scenarioPath = opts.RequestPath;
        }
        if (string.IsNullOrWhiteSpace(scenarioPath))
        {
            scenarioPath = Path.Combine(repo, "scenarios", "sample", "vi-diff-requests.json");
        }
        else if (!Path.IsPathRooted(scenarioPath))
        {
            scenarioPath = Path.Combine(repo, scenarioPath);
        }

        if (fakeExit.HasValue)
        {
            var detailsFake = new
            {
                bitness,
                scenarioPath,
                scriptPath = script,
                worktreePath = (string?)null,
                lvVersion = (string?)null,
                devmodeRequired = opts.RequireDevmode,
                devmodeAutoBind = opts.AutoBindDevmode,
                devmodeBindStatus = (string?)null,
                devmodeBindExit = (int?)null,
                devmodeBindStdout = (string?)null,
                devmodeBindStderr = (string?)null,
                bundlePath = (string?)null,
                summaryPath = (string?)null,
                exit = fakeExit.Value,
                stdout = string.Empty,
                stderr = string.Empty
            };
            return new CommandResult("vi-compare", "success", fakeExit.Value, 0, detailsFake);
        }

        var vipbBlock = BlockIfVipbTooOld("vi-compare", repo, script, 2025);
        if (vipbBlock != null) return vipbBlock;
        if (!opts.SkipPreflight)
        {
            var preflight = RunViComparePreflight(log, opts, repo, bitness);
            if (!preflight.Status.Equals("success", StringComparison.OrdinalIgnoreCase))
            {
                return new CommandResult("vi-compare", preflight.Status, preflight.ExitCode, preflight.DurationMs, preflight.Details);
            }
        }

        // Optional worktree isolation
        var worktreeBase = string.IsNullOrWhiteSpace(opts.WorktreeRoot)
            ? Path.Combine(repo, ".tmp-tests", "vi-compare-worktrees")
            : opts.WorktreeRoot!;
        var stamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff");
        var worktreePath = Path.Combine(worktreeBase, $"vi-compare-{stamp}");
        var repoForCompare = repo;
        var worktreeCreated = false;
        CommandResult? resultWrapper = null;
        CommandResult? bindResult = null;

        if (!opts.SkipWorktree)
        {
            try
            {
                Directory.CreateDirectory(worktreeBase);
                var wtResult = RunProcess("git", repo, new[] { "worktree", "add", "--force", "--detach", worktreePath, opts.Ref }, opts.TimeoutSeconds);
                if (wtResult.ExitCode != 0)
                {
                    var failDetails = new
                    {
                        bitness,
                        scenarioPath,
                        scriptPath = script,
                        worktreePath,
                        exit = wtResult.ExitCode,
                        stdout = wtResult.StdOut,
                        stderr = wtResult.StdErr
                    };
                    resultWrapper = new CommandResult("vi-compare", "fail", wtResult.ExitCode, wtResult.DurationMs, failDetails);
                    return resultWrapper;
                }
                repoForCompare = worktreePath;
                worktreeCreated = true;
            }
            catch (Exception ex)
            {
                var failDetails = new
                {
                    bitness,
                    scenarioPath,
                    scriptPath = script,
                    worktreePath,
                    exit = 1,
                    stdout = string.Empty,
                    stderr = $"Failed to create worktree: {ex.Message}"
                };
                resultWrapper = new CommandResult("vi-compare", "fail", 1, 0, failDetails);
                return resultWrapper;
            }
        }

        try
        {
            // Resolve LabVIEW version (prefer explicit flag, otherwise VIPB)
            var compareLvVersion = !string.IsNullOrWhiteSpace(opts.LvVersion)
                ? opts.LvVersion!
                : GetLabviewVersionFromVipb(repoForCompare) ?? "2025";
            var compareLvYear = ParseLabviewYear(compareLvVersion);
            if (compareLvYear.HasValue && compareLvYear.Value < 2025)
            {
                var skipDetails = new
                {
                    bitness,
                    scenarioPath,
                    scriptPath = script,
                    worktreePath,
                    lvVersion = compareLvVersion,
                    devmodeRequired = opts.RequireDevmode,
                    devmodeBound = false,
                    exit = 0,
                    stdout = string.Empty,
                    stderr = $"vi-compare requires LabVIEW 2025 or later (found {compareLvVersion})."
                };
                return new CommandResult("vi-compare", "skip", 0, 0, skipDetails);
            }

            // Guard: VIPB targets an older LV than requested
            var vipbYear = ParseLabviewYear(GetLabviewVersionFromVipb(repoForCompare));
            var compareYear = ParseLabviewYear(compareLvVersion);
            if (vipbYear.HasValue && compareYear.HasValue && vipbYear.Value < compareYear.Value)
            {
                var failDetails = new
                {
                    bitness,
                    scenarioPath,
                    scriptPath = script,
                    worktreePath,
                    vipbVersion = GetLabviewVersionFromVipb(repoForCompare),
                    lvVersion = compareLvVersion,
                    devmodeRequired = opts.RequireDevmode,
                    devmodeBound = false,
                    exit = 1,
                    stdout = string.Empty,
                    stderr = $"VIPB Package_LabVIEW_Version ({vipbYear.Value}) is below requested {compareLvVersion}; update the VIPB or override the target."
                };
                return new CommandResult("vi-compare", "fail", 1, 0, failDetails);
            }

            if (!opts.SkipWorktree)
            {
                // Guard: if LocalHost.LibraryPaths points elsewhere, unbind first (or fail fast)
                var conflict = HasConflictingToken(repoForCompare, compareLvVersion, bitness);
                if (conflict && !opts.SkipPreflight)
                {
                    var bindTimeout = Math.Min(opts.TimeoutSeconds > 0 ? opts.TimeoutSeconds : 60, 60);
                    var bindOpts = opts with { TimeoutSeconds = bindTimeout, LvVersion = compareLvVersion };
                    if (opts.AutoBindDevmode)
                    {
                        log($"devmode-unbind ({bitness}-bit, {compareLvVersion}) before vi-compare (conflicting token)...");
                        var unbindResult = RunBindUnbind(log, bindOpts, repoForCompare, bitness, mode: "unbind");
                        if (!unbindResult.Status.Equals("success", StringComparison.OrdinalIgnoreCase))
                        {
                            var preflightDetails = new
                            {
                                bitness,
                                scenarioPath,
                                scriptPath = script,
                                worktreePath,
                                lvVersion = compareLvVersion,
                                devmodeUnbindStatus = unbindResult.Status,
                                devmodeUnbindExit = unbindResult.ExitCode,
                                devmodeUnbindStdout = (unbindResult.Details as dynamic)?.stdout,
                                devmodeUnbindStderr = (unbindResult.Details as dynamic)?.stderr,
                                devmodeRequired = opts.RequireDevmode,
                                devmodeBound = false,
                                exit = unbindResult.ExitCode,
                                stdout = string.Empty,
                                stderr = "Conflicting LocalHost.LibraryPaths token could not be cleared before vi-compare."
                            };
                            return new CommandResult("vi-compare", "fail", unbindResult.ExitCode, unbindResult.DurationMs, preflightDetails);
                        }
                        else
                        {
                            log($"devmode-unbind ({bitness}-bit, {compareLvVersion}) completed in {unbindResult.DurationMs}ms.");
                        }
                    }
                    else
                    {
                        var preflightDetails = new
                        {
                            bitness,
                            scenarioPath,
                            scriptPath = script,
                            worktreePath,
                            lvVersion = compareLvVersion,
                            devmodeRequired = opts.RequireDevmode,
                            devmodeBound = false,
                            exit = 1,
                            stdout = string.Empty,
                            stderr = "Conflicting LocalHost.LibraryPaths token found; rerun with --auto-bind-devmode or clear dev mode."
                        };
                        return new CommandResult("vi-compare", "fail", 1, 0, preflightDetails);
                    }
                }
                else if (conflict && opts.SkipPreflight)
                {
                    log("skip preflight: leaving existing LocalHost.LibraryPaths token intact.");
                }
            }

            var argList = new List<string>
            {
                "-NoProfile",
                "-File", script,
                "-RepoRoot", repoForCompare,
                "-ScenarioPath", scenarioPath
            };

            // Optional dev-mode enforcement
            if (opts.RequireDevmode || opts.AutoBindDevmode)
            {
                var tokenPresent = TokenPresent(repoForCompare, compareLvVersion, bitness);
                if (!tokenPresent && opts.AutoBindDevmode)
                {
                    log($"devmode-bind ({bitness}-bit, {compareLvVersion}) before vi-compare...");
                    bindResult = RunBindUnbind(log, opts with { LvVersion = compareLvVersion }, repoForCompare, bitness, mode: "bind");
                    tokenPresent = bindResult.Status.Equals("success", StringComparison.OrdinalIgnoreCase) && TokenPresent(repoForCompare, compareLvVersion, bitness);
                }
                if (!tokenPresent && opts.RequireDevmode)
                {
                    var skipDetails = new
                    {
                        bitness,
                        scenarioPath,
                        scriptPath = script,
                        worktreePath,
                        lvVersion = compareLvVersion,
                        devmodeBindStatus = bindResult?.Status,
                        devmodeBindExit = bindResult?.ExitCode,
                        devmodeBindStdout = (bindResult?.Details as dynamic)?.stdout,
                        devmodeBindStderr = (bindResult?.Details as dynamic)?.stderr,
                        devmodeRequired = true,
                        devmodeBound = false,
                        exit = bindResult?.ExitCode ?? 1,
                        stdout = (bindResult?.Details as dynamic)?.stdout ?? string.Empty,
                        stderr = (bindResult?.Details as dynamic)?.stderr ?? "Dev-mode token not present; vi-compare skipped."
                    };
                    var skipStatus = bindResult != null && !string.Equals(bindResult.Status, "success", StringComparison.OrdinalIgnoreCase) ? "fail" : "skip";
                    return new CommandResult("vi-compare", skipStatus, skipDetails.exit, 0, skipDetails);
                }
            }

            log($"vi-compare ({bitness}-bit) scenario={scenarioPath}...");
            var result = fakeExit.HasValue
                ? (ExitCode: fakeExit.Value, StdOut: string.Empty, StdErr: string.Empty, DurationMs: 0L)
                : RunPwsh(opts, argList, opts.TimeoutSeconds);
            var status = result.ExitCode == 0 ? "success" : "fail";
            var bundlePath = ParsePathFromOutput(result.StdOut, "vi-compare-bundles");
            var summaryPath = ParsePathFromOutput(result.StdOut, "vi-comparison-summary.json");
            var details = new
            {
                bitness,
                scenarioPath,
                scriptPath = script,
                worktreePath = worktreeCreated ? repoForCompare : null,
                lvVersion = compareLvVersion,
                devmodeRequired = opts.RequireDevmode,
                devmodeAutoBind = opts.AutoBindDevmode,
                devmodeBindStatus = bindResult?.Status,
                devmodeBindExit = bindResult?.ExitCode,
                devmodeBindStdout = (bindResult?.Details as dynamic)?.stdout,
                devmodeBindStderr = (bindResult?.Details as dynamic)?.stderr,
                bundlePath,
                summaryPath,
                exit = result.ExitCode,
                stdout = result.StdOut,
                stderr = result.StdErr
            };
            return new CommandResult("vi-compare", status, result.ExitCode, result.DurationMs, details);
        }
        finally
        {
            if (worktreeCreated)
            {
                try { RunProcess("git", repo, new[] { "worktree", "remove", "--force", worktreePath }, 0); } catch { }
                try { if (Directory.Exists(worktreePath)) { Directory.Delete(worktreePath, true); } } catch { }
            }
        }
    }

    internal static CommandResult RunUnitTestsForTest(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
        => RunUnitTests(log, opts, repo, bitness, fakeExit);

    private static CommandResult RunUnitTests(Action<string> log, Options opts, string repo, string bitness, int? fakeExit = null)
    {
        var script = Path.Combine(repo, "scripts", "run-unit-tests", "RunUnitTests.ps1");
        var projectPath = opts.ProjectPath;
        if (string.IsNullOrWhiteSpace(projectPath))
        {
            projectPath = Path.Combine(repo, "lv_icon_editor.lvproj");
        }
        else if (!Path.IsPathRooted(projectPath))
        {
            projectPath = Path.Combine(repo, projectPath);
        }

        var lvVersion = ResolveLabviewVersion(repo, opts, log, fallback: "2023");
        var argList = new List<string>
        {
            "-NoProfile",
            "-File", script,
            "-SupportedBitness", bitness,
            "-Package_LabVIEW_Version", lvVersion,
            "-AbsoluteProjectPath", projectPath
        };

        log($"unit-tests ({bitness}-bit, {lvVersion}) project={projectPath}...");
        var result = fakeExit.HasValue
            ? (ExitCode: fakeExit.Value, StdOut: string.Empty, StdErr: string.Empty, DurationMs: 0L)
            : RunPwsh(opts, argList, opts.TimeoutSeconds);
        var status = result.ExitCode == 0 ? "success" : "fail";
        var details = new
        {
            bitness,
            lvVersion,
            projectPath,
            scriptPath = script,
            exit = result.ExitCode,
            stdout = result.StdOut,
            stderr = result.StdErr
        };
        return new CommandResult("unit-tests", status, result.ExitCode, result.DurationMs, details);
    }

    internal static (Options? value, string? error, bool help) ParseArgsForTest(string[] args) => ParseArgs(args);

    private static (Options? value, string? error, bool help) ParseArgs(string[] args)
    {
        if (args.Length == 0) return (null, null, true);

        var sub = args[0];
        if (sub is "-h" or "--help")
        {
            return (null, null, true);
        }

        var repo = Directory.GetCurrentDirectory();
        var bitness = sub.Equals("sd-ppl-lvcli", StringComparison.OrdinalIgnoreCase) ? string.Empty : "both";
        var pwsh = "pwsh";
        var refName = "HEAD";
        var lvlibpBitness = "both";
        int major = 0, minor = 1, patch = 0, build = 1;
        var company = "LabVIEW-Community-CI-CD";
        var author = "Local Developer";
        var labviewMinor = 3;
        var runBothBitnessSeparately = false;
        var managed = false;
        string? lv = null;
        string? vipc = null;
        string? requestPath = null;
        string? projectPath = null;
        string? scenarioPath = null;
        string? vipmManifestPath = null;
        string? worktreeRoot = null;
        var skipWorktree = false;
        var skipPreflight = false;
        var requireDevmode = false;
        var autoBindDevmode = false;
        var timeoutSec = 0;
        var plain = false;
        var verbose = false;
        string? sourceDistZip = null;
        string? sourceDistOutput = null;
        var sourceDistStrict = false;
        var sourceDistLogStash = false;
        string? labviewCliPath = null;
        string? labviewPath = null;
        int? labviewPort = null;
        string? tempRoot = null;
        string? logRoot = null;
        int? labviewCliTimeoutSec = null;
        var forceWorktree = false;
        var copyOnFail = false;
        var retryBuilds = 0;
        string? expectSha = null;

        try
        {
            for (int i = 1; i < args.Length; i++)
            {
                var arg = args[i];
                switch (arg)
                {
                    case "--repo":
                        repo = RequireNext(args, ref i, "--repo");
                        break;
                    case "--ref":
                        refName = RequireNext(args, ref i, "--ref");
                        break;
                    case "--bitness":
                        bitness = RequireNext(args, ref i, "--bitness");
                        break;
                    case "--lvlibp-bitness":
                        lvlibpBitness = RequireNext(args, ref i, "--lvlibp-bitness");
                        break;
                    case "--pwsh":
                        pwsh = RequireNext(args, ref i, "--pwsh");
                        break;
                    case "--lv-version":
                        lv = RequireNext(args, ref i, "--lv-version");
                        break;
                    case "--vipc-path":
                        vipc = RequireNext(args, ref i, "--vipc-path");
                        break;
                    case "--request":
                        requestPath = RequireNext(args, ref i, "--request");
                        break;
                    case "--project":
                        projectPath = RequireNext(args, ref i, "--project");
                        break;
                    case "--scenario":
                        scenarioPath = RequireNext(args, ref i, "--scenario");
                        break;
                    case "--vipm-manifest":
                        vipmManifestPath = RequireNext(args, ref i, "--vipm-manifest");
                        break;
            case "--worktree-root":
                worktreeRoot = RequireNext(args, ref i, "--worktree-root");
                break;
            case "--skip-worktree":
                skipWorktree = true;
                break;
            case "--skip-preflight":
                skipPreflight = true;
                break;
                    case "--require-devmode":
                        requireDevmode = true;
                        break;
                    case "--auto-bind-devmode":
                        autoBindDevmode = true;
                        break;
                    case "--major":
                        if (!int.TryParse(RequireNext(args, ref i, "--major"), out major))
                        {
                            return (null, "Invalid --major", false);
                        }
                        break;
                    case "--minor":
                        if (!int.TryParse(RequireNext(args, ref i, "--minor"), out minor))
                        {
                            return (null, "Invalid --minor", false);
                        }
                        break;
                    case "--patch":
                        if (!int.TryParse(RequireNext(args, ref i, "--patch"), out patch))
                        {
                            return (null, "Invalid --patch", false);
                        }
                        break;
                    case "--build":
                        if (!int.TryParse(RequireNext(args, ref i, "--build"), out build))
                        {
                            return (null, "Invalid --build", false);
                        }
                        break;
                    case "--company":
                        company = RequireNext(args, ref i, "--company");
                        break;
                    case "--author":
                        author = RequireNext(args, ref i, "--author");
                        break;
                    case "--labview-minor":
                        if (!int.TryParse(RequireNext(args, ref i, "--labview-minor"), out labviewMinor))
                        {
                            return (null, "Invalid --labview-minor", false);
                        }
                        break;
                    case "--run-both-bitness-separately":
                        runBothBitnessSeparately = true;
                        break;
                    case "--timeout-sec":
                        if (!int.TryParse(RequireNext(args, ref i, "--timeout-sec"), out timeoutSec))
                        {
                            return (null, "Invalid --timeout-sec", false);
                        }
                        break;
                    case "--managed":
                        managed = true;
                        break;
                    case "--plain":
                        plain = true;
                        break;
                    case "--source-dist-zip":
                        sourceDistZip = RequireNext(args, ref i, "--source-dist-zip");
                        break;
                    case "--source-dist-output":
                        sourceDistOutput = RequireNext(args, ref i, "--source-dist-output");
                        break;
                    case "--source-dist-strict":
                        sourceDistStrict = true;
                        break;
                    case "--source-dist-log-stash":
                        sourceDistLogStash = true;
                        break;
                    case "--labviewcli-path":
                        labviewCliPath = RequireNext(args, ref i, "--labviewcli-path");
                        break;
                    case "--labview-path":
                        labviewPath = RequireNext(args, ref i, "--labview-path");
                        break;
                    case "--lv-port":
                        var portText = RequireNext(args, ref i, "--lv-port");
                        if (!int.TryParse(portText, out var parsedPort))
                        {
                            return (null, "Invalid --lv-port", false);
                        }
                        labviewPort = parsedPort;
                        break;
                    case "--temp-root":
                        tempRoot = RequireNext(args, ref i, "--temp-root");
                        break;
                    case "--log-root":
                        logRoot = RequireNext(args, ref i, "--log-root");
                        break;
                    case "--lvcli-timeout-sec":
                        var lvcliTimeoutText = RequireNext(args, ref i, "--lvcli-timeout-sec");
                        if (!int.TryParse(lvcliTimeoutText, out var parsedLvcliTimeout))
                        {
                            return (null, "Invalid --lvcli-timeout-sec", false);
                        }
                        labviewCliTimeoutSec = parsedLvcliTimeout;
                        break;
                    case "--force-worktree":
                        forceWorktree = true;
                        break;
                    case "--copy-on-fail":
                        copyOnFail = true;
                        break;
                    case "--retry-build":
                        if (!int.TryParse(RequireNext(args, ref i, "--retry-build"), out retryBuilds))
                        {
                            return (null, "Invalid --retry-build", false);
                        }
                        break;
                    case "--expect-sha":
                        expectSha = RequireNext(args, ref i, "--expect-sha");
                        break;
                    case "--verbose":
                        verbose = true;
                        break;
                    case "-h":
                    case "--help":
                        return (null, null, true);
                    default:
                        return (null, $"Unknown argument: {arg}", false);
                }
            }
        }
        catch (ArgumentException ex)
        {
            return (null, ex.Message, false);
        }

        if (ResolveBitness(bitness).Count == 0)
        {
            if (!sub.Equals("sd-ppl-lvcli", StringComparison.OrdinalIgnoreCase) || !string.IsNullOrWhiteSpace(bitness))
            {
                return (null, "Invalid --bitness; expected both|64|32", false);
            }
        }
        if (ResolveBitness(lvlibpBitness).Count == 0)
        {
            return (null, "Invalid --lvlibp-bitness; expected both|64|32", false);
        }

        var repoFull = Path.GetFullPath(repo);
        if (!Directory.Exists(repoFull))
        {
            return (null, $"Repository path not found: {repoFull}", false);
        }

        return (new Options(sub, repoFull, bitness, pwsh, refName, lvlibpBitness, major, minor, patch, build, company, author, labviewMinor, runBothBitnessSeparately, managed, lv, vipc, requestPath, projectPath, scenarioPath, vipmManifestPath, worktreeRoot, skipWorktree, skipPreflight, requireDevmode, autoBindDevmode, timeoutSec, plain, verbose, sourceDistZip, sourceDistOutput, sourceDistStrict, sourceDistLogStash, labviewCliPath, labviewPath, labviewPort, tempRoot, logRoot, labviewCliTimeoutSec, forceWorktree, copyOnFail, retryBuilds, expectSha), null, false);
    }

    private static List<string> ResolveBitness(string value)
    {
        var v = value.ToLowerInvariant();
        return v switch
        {
            "both" => new List<string> { "64", "32" },
            "64" => new List<string> { "64" },
            "32" => new List<string> { "32" },
            _ => new List<string>()
        };
    }

    private static string ResolveLabviewVersion(string repo, Options opts, Action<string>? log, string fallback = "2023")
    {
        if (!string.IsNullOrWhiteSpace(opts.LvVersion))
        {
            return opts.LvVersion!;
        }

        var script = Path.Combine(repo, "scripts", "get-package-lv-version.ps1");
        if (!File.Exists(script))
        {
            log?.Invoke($"get-package-lv-version.ps1 not found at {script}; defaulting to {fallback}");
            return fallback;
        }

        var args = new List<string> { "-NoProfile", "-File", script, "-RepositoryPath", repo };
        var result = RunPwsh(opts, args, opts.TimeoutSeconds);
        if (result.ExitCode == 0 && !string.IsNullOrWhiteSpace(result.StdOut))
        {
            return result.StdOut.Trim();
        }

        log?.Invoke($"get-package-lv-version.ps1 failed (exit {result.ExitCode}); defaulting to {fallback}");
        return fallback;
    }

    private static string ResolveLabviewBitness(string repo, Options opts, Action<string>? log, string fallback = "64")
    {
        if (!string.IsNullOrWhiteSpace(opts.Bitness) && !opts.Bitness.Equals("both", StringComparison.OrdinalIgnoreCase))
        {
            return opts.Bitness;
        }

        var script = Path.Combine(repo, "scripts", "get-package-lv-bitness.ps1");
        if (!File.Exists(script))
        {
            log?.Invoke($"get-package-lv-bitness.ps1 not found at {script}; defaulting to {fallback}");
            return fallback;
        }

        var args = new List<string> { "-NoProfile", "-File", script, "-RepositoryPath", repo };
        var result = RunPwsh(opts, args, opts.TimeoutSeconds);
        if (result.ExitCode == 0 && !string.IsNullOrWhiteSpace(result.StdOut))
        {
            var bit = result.StdOut.Trim();
            if (bit.Equals("both", StringComparison.OrdinalIgnoreCase))
            {
                log?.Invoke($"get-package-lv-bitness.ps1 returned 'both'; defaulting to {fallback}");
                return fallback;
            }
            return bit;
        }

        log?.Invoke($"get-package-lv-bitness.ps1 failed (exit {result.ExitCode}); defaulting to {fallback}");
        return fallback;
    }

    private static string? ResolveLabviewExePath(string lvVersion, string bitness, string? overridePath, Action<string>? log)
    {
        if (!string.IsNullOrWhiteSpace(overridePath))
        {
            try
            {
                var full = Path.GetFullPath(overridePath);
                if (File.Exists(full)) return full;
                log?.Invoke($"LabVIEWPath override not found: {full}");
                return null;
            }
            catch
            {
                log?.Invoke($"LabVIEWPath override invalid: {overridePath}");
                return null;
            }
        }

        if (string.IsNullOrWhiteSpace(lvVersion)) return null;

        var candidates = new List<string>();
        if (bitness == "32")
        {
            var pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            if (!string.IsNullOrWhiteSpace(pf86))
            {
                candidates.Add(Path.Combine(pf86, $"National Instruments\\LabVIEW {lvVersion}\\LabVIEW.exe"));
            }
            var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            if (!string.IsNullOrWhiteSpace(pf))
            {
                candidates.Add(Path.Combine(pf, $"National Instruments\\LabVIEW {lvVersion} (32-bit)\\LabVIEW.exe"));
            }
        }
        else
        {
            var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            if (!string.IsNullOrWhiteSpace(pf))
            {
                candidates.Add(Path.Combine(pf, $"National Instruments\\LabVIEW {lvVersion}\\LabVIEW.exe"));
            }
        }

        foreach (var c in candidates)
        {
            try
            {
                if (File.Exists(c)) return c;
            }
            catch
            {
                // ignore
            }
        }

        if (candidates.Count > 0)
        {
            log?.Invoke($"LabVIEW executable not found for {lvVersion} ({bitness}-bit). Checked: {string.Join("; ", candidates)}");
        }
        return null;
    }

    private static string? PublishOrchestrationCli(string repoPath, Action<string> log, int timeoutSec)
    {
        try
        {
            var project = Path.Combine(repoPath, "Tooling", "dotnet", "OrchestrationCli", "OrchestrationCli.csproj");
            if (!File.Exists(project))
            {
                log($"[sd-ppl-lvcli] OrchestrationCli project not found at {project}; skipping publish.");
                return null;
            }
            var output = Path.Combine(repoPath, "Tooling", "bin", "win-x64");
            Directory.CreateDirectory(output);
            var args = new List<string>
            {
                "publish", project,
                "-c", "Release",
                "-r", "win-x64",
                "--self-contained", "true",
                "-p:PublishSingleFile=true",
                "-o", output
            };
            var result = RunProcess("dotnet", repoPath, args, timeoutSec <= 0 ? 600 : timeoutSec);
            if (result.ExitCode != 0)
            {
                log($"[sd-ppl-lvcli] WARNING: failed to publish OrchestrationCli (exit {result.ExitCode}): {result.StdErr}");
                return null;
            }
            log($"[sd-ppl-lvcli] published OrchestrationCli to {output}");
            return output;
        }
        catch (Exception ex)
        {
            log($"[sd-ppl-lvcli] WARNING: failed to publish OrchestrationCli: {ex.Message}");
            return null;
        }
    }

    private static string? PublishRequirementsSummarizer(string repoPath, Action<string> log, int timeoutSec)
    {
        try
        {
            var project = Path.Combine(repoPath, "Tooling", "dotnet", "RequirementsSummarizer", "RequirementsSummarizer.csproj");
            if (!File.Exists(project))
            {
                log($"[sd-ppl-lvcli] RequirementsSummarizer project not found at {project}; skipping publish.");
                return null;
            }
            var output = Path.Combine(repoPath, "Tooling", "bin", "win-x64");
            Directory.CreateDirectory(output);
            var args = new List<string>
            {
                "publish", project,
                "-c", "Release",
                "-r", "win-x64",
                "--self-contained", "true",
                "-p:PublishSingleFile=true",
                "-o", output
            };
            var result = RunProcess("dotnet", repoPath, args, timeoutSec <= 0 ? 600 : timeoutSec);
            if (result.ExitCode != 0)
            {
                log($"[sd-ppl-lvcli] WARNING: failed to publish RequirementsSummarizer (exit {result.ExitCode}): {result.StdErr}");
                return null;
            }
            log($"[sd-ppl-lvcli] published RequirementsSummarizer to {output}");
            return output;
        }
        catch (Exception ex)
        {
            log($"[sd-ppl-lvcli] WARNING: failed to publish RequirementsSummarizer: {ex.Message}");
            return null;
        }
    }

    private static bool IsPortInUse(int port)
    {
        try
        {
            using var client = new System.Net.Sockets.TcpClient();
            var task = client.ConnectAsync("127.0.0.1", port);
            if (!task.Wait(TimeSpan.FromMilliseconds(200)))
            {
                return false;
            }
            return client.Connected;
        }
        catch
        {
            return false;
        }
    }

    private static int? ResolveLabviewPort(string? labviewPath, string lvVersion, string bitness, Action<string>? log)
    {
        if (string.IsNullOrWhiteSpace(labviewPath)) return null;
        int? portFromIni = null;
        try
        {
            var ini = Path.Combine(Path.GetDirectoryName(labviewPath) ?? string.Empty, "LabVIEW.ini");
            if (File.Exists(ini))
            {
                foreach (var line in File.ReadAllLines(ini))
                {
                    var match = Regex.Match(line, "^\\s*server\\.tcp\\.port\\s*=\\s*(?<port>\\d+)", RegexOptions.IgnoreCase);
                    if (match.Success && int.TryParse(match.Groups["port"].Value, out var port))
                    {
                        portFromIni = port;
                        break;
                    }
                }
            }
        }
        catch
        {
            // ignore
        }

        int fallbackPort = bitness == "32" ? 3367 : 3365;
        var selected = portFromIni ?? fallbackPort;

        if (portFromIni.HasValue)
        {
            log?.Invoke($"[sd-ppl-lvcli] resolved LabVIEW port {selected} from LabVIEW.ini ({lvVersion} {bitness}-bit)");
        }
        else
        {
            log?.Invoke($"[sd-ppl-lvcli] server.tcp.port not found in LabVIEW.ini ({lvVersion} {bitness}-bit); using fallback port {selected}");
        }

        if (IsPortInUse(selected))
        {
            throw new InvalidOperationException($"Port {selected} appears in use; cannot launch LabVIEWCLI for {lvVersion} {bitness}-bit. Free the port or override with --lv-port.");
        }

        return selected;
    }

    private static (int ExitCode, string StdOut, string StdErr, long DurationMs) RunPwsh(Options opts, IEnumerable<string> argList, int timeoutSec)
    {
        return RunProcess(opts.Pwsh, opts.Repo, argList, timeoutSec);
    }

    private static string QuoteArg(string arg)
    {
        if (string.IsNullOrEmpty(arg)) return "\"\"";
        if (arg.Any(ch => char.IsWhiteSpace(ch) || ch == '\"'))
        {
            return $"\"{arg.Replace("\"", "\\\"")}\"";
        }
        return arg;
    }

    private static string ReadTail(string path, int lines = 40)
    {
        try
        {
            var tail = File.ReadLines(path).TakeLast(lines);
            return string.Join(Environment.NewLine, tail);
        }
        catch
        {
            return string.Empty;
        }
    }

    private static (int ExitCode, string StdOut, string StdErr, long DurationMs) RunProcess(string fileName, string workingDirectory, IEnumerable<string> argList, int timeoutSec)
    {
        var argsMaterialized = argList.ToList();
        var renderedArgs = string.Join(" ", argsMaterialized.Select(QuoteArg));
        Console.WriteLine($"[orchestration-cli][proc] {fileName} {renderedArgs} (cwd={workingDirectory}, timeout={(timeoutSec <= 0 ? "none" : $"{timeoutSec}s")})");

        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        foreach (var a in argsMaterialized) psi.ArgumentList.Add(a);

        var stdout = new StringBuilder();
        var stderr = new StringBuilder();
        var stdoutDone = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var stderrDone = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

        var sw = Stopwatch.StartNew();
        var proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
        proc.OutputDataReceived += (_, e) =>
        {
            if (e.Data == null) { stdoutDone.TrySetResult(true); return; }
            stdout.AppendLine(e.Data);
            Console.WriteLine(e.Data);
        };
        proc.ErrorDataReceived += (_, e) =>
        {
            if (e.Data == null) { stderrDone.TrySetResult(true); return; }
            stderr.AppendLine(e.Data);
            Console.Error.WriteLine(e.Data);
        };

        try
        {
            if (!proc.Start())
            {
                return (1, string.Empty, $"Failed to start process: {fileName}", 0);
            }
        }
        catch (Exception ex)
        {
            return (1, string.Empty, $"Failed to start process: {ex.Message}", 0);
        }

        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();

        var heartbeat = Task.Run(async () =>
        {
            while (!proc.HasExited)
            {
                await Task.Delay(TimeSpan.FromSeconds(25));
                if (!proc.HasExited)
                {
                    Console.WriteLine($"[orchestration-cli][proc][{fileName}] running {sw.Elapsed.TotalSeconds:F1}s (pid={proc.Id}, cwd={workingDirectory})");
                }
            }
        });

        var timedOut = false;
        var exited = timeoutSec > 0 ? proc.WaitForExit(timeoutSec * 1000) : proc.WaitForExit(int.MaxValue);
        if (!exited)
        {
            timedOut = true;
            try { proc.Kill(true); } catch { }
        }
        // ensure async reads complete
        Task.WaitAll(new[] { stdoutDone.Task, stderrDone.Task }, 5000);
        sw.Stop();

        var outText = stdout.ToString();
        var errText = stderr.ToString();
        if (timedOut)
        {
            errText += $"{(string.IsNullOrWhiteSpace(errText) ? string.Empty : Environment.NewLine)}Process timed out after {timeoutSec} second(s).";
            return (1, outText, errText, sw.ElapsedMilliseconds);
        }

        return (proc.ExitCode, outText, errText, sw.ElapsedMilliseconds);
    }

    private static string GetRelativePathSafe(string basePath, string targetPath)
    {
        try { return Path.GetRelativePath(basePath, targetPath); }
        catch { return targetPath; }
    }

    private static string SanitizeFileName(string name)
    {
        var invalid = Path.GetInvalidFileNameChars();
        var sanitized = new string(name.Select(ch => invalid.Contains(ch) ? '-' : ch).ToArray());
        return string.IsNullOrWhiteSpace(sanitized) ? "log" : sanitized;
    }

    private static void CopyDirectory(string sourceDir, string destDir, bool overwrite)
    {
        if (!Directory.Exists(sourceDir)) return;
        Directory.CreateDirectory(destDir);
        foreach (var file in Directory.GetFiles(sourceDir))
        {
            var destFile = Path.Combine(destDir, Path.GetFileName(file));
            File.Copy(file, destFile, overwrite);
        }
        foreach (var directory in Directory.GetDirectories(sourceDir))
        {
            var destSub = Path.Combine(destDir, Path.GetFileName(directory));
            CopyDirectory(directory, destSub, overwrite);
        }
    }

    private static string? ParsePathFromOutput(string output, string contains)
    {
        if (string.IsNullOrWhiteSpace(output)) return null;
        var lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
        foreach (var line in lines)
        {
            if (line.IndexOf(contains, StringComparison.OrdinalIgnoreCase) >= 0)
            {
                var start = line.IndexOf("C:", StringComparison.OrdinalIgnoreCase);
                if (start >= 0)
                {
                    var candidate = line.Substring(start).Trim();
                    return candidate;
                }
                return line.Trim();
            }
        }
        return null;
    }

    private static string RequireNext(string[] args, ref int index, string name)
    {
        if (index + 1 >= args.Length)
        {
            throw new ArgumentException($"Missing value for {name}");
        }
        return args[++index];
    }

    private static void PrintUsage()
    {
        Console.WriteLine("OrchestrationCli");
        Console.WriteLine("Usage:");
        Console.WriteLine("  dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- <subcommand> [options]");
        Console.WriteLine("Subcommands:");
        Console.WriteLine("  devmode-bind      Bind LocalHost.LibraryPaths for specified bitness.");
        Console.WriteLine("  devmode-unbind    Unbind dev mode for specified bitness.");
        Console.WriteLine("  labview-close     Close LabVIEW for specified bitness/version.");
        Console.WriteLine("  apply-deps        Apply dependencies via VIPC (wrapper).");
        Console.WriteLine("  restore-sources   Restore packaged LabVIEW sources (guarded).");
        Console.WriteLine("  vi-analyzer       Run VI Analyzer via RunWithDevMode.ps1 (request-driven).");
        Console.WriteLine("  missing-check     Run MissingInProjectCLI via g-cli for a project file.");
        Console.WriteLine("  vi-compare        Run VI compare replay via Replay-ViCompareScenario.ps1 (request-driven).");
        Console.WriteLine("  vi-compare-preflight  VIPM + devmode preflight for vi-compare (no worktree).");
        Console.WriteLine("  vipm-verify       Preflight check for required VIPM packages for a LabVIEW version/bitness.");
        Console.WriteLine("  vipm-install      Apply a VIPC (default: runner_dependencies.vipc) via VIPM CLI for a LabVIEW version/bitness.");
        Console.WriteLine("  unit-tests        Run LUnit via run-unit-tests/RunUnitTests.ps1.");
        Console.WriteLine("  package-build     Run IntegrationEngineCli to build/package the addon (VIPM).");
        Console.WriteLine("  source-dist-verify Verify source-distribution.zip manifest commits against git history.");
        Console.WriteLine("  sd-ppl-lvcli      Build Source Distribution then Icon Editor PPL via LabVIEWCLI with g-cli bind/unbind.");
        Console.WriteLine("                    (Derives LabVIEW version/bitness from VIPB; omit --bitness/--lv-version for this subcommand.)");
        Console.WriteLine("Options:");
        Console.WriteLine("  --repo <path>             Repository path (default: current directory)");
        Console.WriteLine("  --ref <git-ref>           Git ref to pass to IntegrationEngineCli (default: HEAD)");
        Console.WriteLine("  --bitness <both|64|32>    Target bitness (default: both; sd-ppl-lvcli ignores if omitted and uses VIPB)");
        Console.WriteLine("  --lvlibp-bitness <both|64|32> lvlibp bitness (default: both, package-build only)");
        Console.WriteLine("  --lv-version <year>       LabVIEW version (e.g., 2021) for bind/unbind/restore/apply-deps");
        Console.WriteLine("  --vipc-path <path>        VIPC to apply (apply-deps only)");
        Console.WriteLine("  --request <path>          Request JSON for vi-analyzer/vi-compare (defaults in configs/)");
        Console.WriteLine("  --project <path>          Project file for missing-check/unit-tests (default: lv_icon_editor.lvproj)");
        Console.WriteLine("  --scenario <path>         Scenario file for vi-compare (optional)");
        Console.WriteLine("  --vipm-manifest <path>    Manifest of required VIPM packages (vipm-verify); defaults to configs/vipm-required.sample.json or runner_dependencies.vipc when absent.");
        Console.WriteLine("  --skip-worktree           Run vi-compare against the repo without creating a temporary worktree.");
        Console.WriteLine("  --skip-preflight          Skip vi-compare preflight (VIPM/devmode); assumes preflight already run.");
        Console.WriteLine("  --require-devmode         Require dev-mode token before vi-compare (skip if absent).");
        Console.WriteLine("  --auto-bind-devmode       Attempt devmode-bind before vi-compare when dev mode is missing.");
        Console.WriteLine("  --major|--minor|--patch|--build <n> Version numbers for package-build (default: 0.1.0.1)");
        Console.WriteLine("  --company <name>          Company metadata for package-build (default: LabVIEW-Community-CI-CD)");
        Console.WriteLine("  --author <name>           Author metadata for package-build (default: Local Developer)");
        Console.WriteLine("  --labview-minor <n>       LabVIEW minor revision (default: 3, package-build)");
        Console.WriteLine("  --run-both-bitness-separately  Split build lanes per bitness (package-build)");
        Console.WriteLine("  --timeout-sec <n>         Timeout seconds (apply-deps/package-build; 0 = no timeout)");
        Console.WriteLine("  --pwsh <path>             PowerShell executable (default: pwsh)");
        Console.WriteLine("  --managed                 Use managed IntegrationEngineCli mode (Windows only, package-build)");
        Console.WriteLine("  --source-dist-zip <path>  Path to source-distribution.zip (default: builds/artifacts/source-distribution.zip)");
        Console.WriteLine("  --source-dist-output <dir> Output root for verification artifacts (default: builds/reports/source-distribution-verify/<timestamp>)");
        Console.WriteLine("  --source-dist-strict      Treat null/empty last_commit entries as failures");
        Console.WriteLine("  --source-dist-log-stash   Publish verification report via log-stash helper if available");
        Console.WriteLine("  --labviewcli-path <path>  LabVIEWCLI executable (sd-ppl-lvcli)");
        Console.WriteLine("  --labview-path <path>     LabVIEW.exe path override (sd-ppl-lvcli)");
        Console.WriteLine("  --lv-port <n>             LabVIEW VI server port override (sd-ppl-lvcli)");
        Console.WriteLine("  --lvcli-timeout-sec <n>   LabVIEWCLI process timeout override (sd-ppl-lvcli)");
        Console.WriteLine("  --temp-root <path>        Temp root override for sd-ppl-lvcli (default: user temp)");
        Console.WriteLine("  --log-root <path>         Log root override for sd-ppl-lvcli (default: <temp>/logs)");
        Console.WriteLine("  --force-worktree          Allow reusing/removing an existing worktree path (sd-ppl-lvcli)");
        Console.WriteLine("  --copy-on-fail            Copy artifacts back even if the flow fails (sd-ppl-lvcli)");
        Console.WriteLine("  --retry-build <n>         Retry LabVIEWCLI builds up to n times on failure (sd-ppl-lvcli)");
        Console.WriteLine("  --expect-sha <hash>       Require CLI git SHA to match (sd-ppl-lvcli)");
        Console.WriteLine("  --plain                   Plain output (reserved for future)");
        Console.WriteLine("  --verbose                 Verbose output (pass-through)");
    }

    private static bool TokenPresent(string repo, string lvVersion, string bitness)
    {
        var candidates = new List<string>();
        var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        if (bitness == "32")
        {
            if (!string.IsNullOrWhiteSpace(pf86))
            {
                candidates.Add(Path.Combine(pf86, $"National Instruments\\LabVIEW {lvVersion}\\LabVIEW.ini"));
            }
            if (!string.IsNullOrWhiteSpace(pf))
            {
                candidates.Add(Path.Combine(pf, $"National Instruments\\LabVIEW {lvVersion} (32-bit)\\LabVIEW.ini"));
            }
        }
        else
        {
            if (!string.IsNullOrWhiteSpace(pf))
            {
                candidates.Add(Path.Combine(pf, $"National Instruments\\LabVIEW {lvVersion}\\LabVIEW.ini"));
            }
        }

        foreach (var path in candidates)
        {
            try
            {
                if (File.Exists(path))
                {
                    var content = File.ReadAllText(path);
                    if (content.IndexOf(repo, StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        return true;
                    }
                }
            }
            catch
            {
                // ignore read errors
            }
        }
        return false;
    }

    private static string? GetLabviewVersionFromVipb(string repo)
    {
        try
        {
            var vipbFiles = Directory.GetFiles(repo, "*.vipb", SearchOption.AllDirectories);
            string? bestVersion = null;
            int? bestYear = null;

            foreach (var vipb in vipbFiles)
            {
                try
                {
                    var doc = new XmlDocument();
                    doc.Load(vipb);
                    var node = doc.SelectSingleNode("//VI_Package_Builder_Settings/Library_General_Settings/Package_LabVIEW_Version");
                    if (node == null) continue;

                    var raw = node.InnerText?.Trim();
                    if (string.IsNullOrWhiteSpace(raw)) continue;

                    var year = ParseLabviewYear(raw);
                    if (year.HasValue)
                    {
                        if (!bestYear.HasValue || year.Value > bestYear.Value)
                        {
                            bestYear = year;
                            bestVersion = raw;
                        }
                    }
                    else if (bestVersion == null)
                    {
                        bestVersion = raw;
                    }
                }
                catch
                {
                    // ignore malformed VIPB files and continue searching
                }
            }

            return bestVersion;
        }
        catch
        {
            // ignore parsing errors and fall through
        }
        return null;
    }

    private static int? ParseLabviewYear(string? version)
    {
        if (string.IsNullOrWhiteSpace(version)) return null;

        // Strip bitness markers so we do not misinterpret 64-bit as a year.
        var cleaned = Regex.Replace(version, @"\(\s*\d+\s*-\s*bit\s*\)", string.Empty, RegexOptions.IgnoreCase);
        cleaned = Regex.Replace(cleaned, @"\b\d+\s*-\s*bit\b", string.Empty, RegexOptions.IgnoreCase).Trim();

        var match = Regex.Match(cleaned, "(20\\d{2})");
        if (match.Success && int.TryParse(match.Groups[1].Value, out var year))
        {
            return year;
        }

        // VIPB may store short-form years like "25.3 (64-bit)"; interpret as 2025.x.
        var shortMatch = Regex.Match(cleaned, @"(?<!\d)(\d{2})(?:[.]\d+)?");
        if (shortMatch.Success && int.TryParse(shortMatch.Groups[1].Value, out var shortYear) && shortYear >= 10)
        {
            return 2000 + shortYear;
        }

        return null;
    }

    private static bool HasConflictingToken(string repo, string lvVersion, string bitness)
    {
        var iniPath = ResolveIniPath(lvVersion, bitness);
        if (string.IsNullOrWhiteSpace(iniPath) || !File.Exists(iniPath))
        {
            return false;
        }
        var repoFull = Path.GetFullPath(repo).TrimEnd('\\', '/');
        try
        {
            var lines = File.ReadAllLines(iniPath);
            var entries = lines.Where(l => Regex.IsMatch(l, "^\\s*LocalHost\\.LibraryPaths", RegexOptions.IgnoreCase)).ToList();
            if (entries.Count == 0) return false;
            foreach (var entry in entries)
            {
                var parts = entry.Split('=', 2, StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length < 2) continue;
                var val = parts[1].Trim().Trim('"');
                try
                {
                    var normalized = Path.GetFullPath(val).TrimEnd('\\', '/');
                    // Accept tokens that point to this repo or a worktree under it.
                    if (!normalized.Equals(repoFull, StringComparison.OrdinalIgnoreCase) &&
                        !normalized.StartsWith(repoFull, StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                }
                catch
                {
                    // If we cannot normalize, treat as potential conflict
                    if (!val.Contains(repoFull, StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                }
            }
        }
        catch
        {
            // On read errors, do not block
            return false;
        }
        return false;
    }

    private static string? ResolveIniPath(string lvVersion, string bitness)
    {
        var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var pf86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        if (bitness == "32")
        {
            if (!string.IsNullOrWhiteSpace(pf86))
            {
                var path = Path.Combine(pf86, $"National Instruments\\LabVIEW {lvVersion}\\LabVIEW.ini");
                if (File.Exists(path)) return path;
            }
            if (!string.IsNullOrWhiteSpace(pf))
            {
                var path = Path.Combine(pf, $"National Instruments\\LabVIEW {lvVersion} (32-bit)\\LabVIEW.ini");
                if (File.Exists(path)) return path;
            }
        }
        else
        {
            if (!string.IsNullOrWhiteSpace(pf))
            {
                var path = Path.Combine(pf, $"National Instruments\\LabVIEW {lvVersion}\\LabVIEW.ini");
                if (File.Exists(path)) return path;
            }
        }
        return null;
    }

    private static Dictionary<string, string> ParseVipmList(string stdout)
    {
        var dict = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var lines = stdout.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
        foreach (var line in lines)
        {
            var match = Regex.Match(line, @"\s*(?<name>.+?)\s*\((?<pkg>[^\s]+)\s+v(?<ver>.+)\)");
            if (!match.Success) continue;
            var pkg = match.Groups["pkg"].Value.Trim();
            var ver = match.Groups["ver"].Value.Trim();
            dict[pkg] = ver;
        }
        return dict;
    }

        private static bool IsConnectionIssue(string? text)
        {
            if (string.IsNullOrWhiteSpace(text)) return false;
            var t = text.ToLowerInvariant();
            return t.Contains("no connection established")
                || t.Contains("timed out waiting for app to connect")
                || t.Contains("failed to establish a connection")
                || t.Contains("connection") && t.Contains("timed out");
        }

    private static bool IsVersionAtLeast(string candidate, string required)
    {
        var candParts = SplitVersion(candidate);
        var reqParts = SplitVersion(required);
        var len = Math.Max(candParts.Count, reqParts.Count);
        for (int i = 0; i < len; i++)
        {
            var c = i < candParts.Count ? candParts[i] : 0;
            var r = i < reqParts.Count ? reqParts[i] : 0;
            if (c > r) return true;
            if (c < r) return false;
        }
        return true;
    }

    private static List<int> SplitVersion(string value)
    {
        var parts = new List<int>();
        foreach (var token in Regex.Split(value, @"[^0-9]+"))
        {
            if (int.TryParse(token, out var num))
            {
                parts.Add(num);
            }
        }
        return parts;
    }

    private sealed class VipmManifest
    {
        [JsonPropertyName("packages")]
        public List<VipmPackage> Packages { get; set; } = new();
    }

    private sealed class VipmPackage
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("packageId")]
        public string PackageId { get; set; } = string.Empty;

        [JsonPropertyName("minVersion")]
        public string MinVersion { get; set; } = "0";
    }

    private static CommandResult? BlockIfVipbTooOld(string command, string repo, string scriptPath, int targetYear)
    {
        var vipbVersion = GetLabviewVersionFromVipb(repo);
        var vipbYear = ParseLabviewYear(vipbVersion);
        if (!vipbYear.HasValue || vipbYear.Value < targetYear)
        {
            var details = new
            {
                scriptPath,
                vipbVersion,
                requiredYear = targetYear,
                exit = 1,
                stdout = string.Empty,
                stderr = $"VIPB Package_LabVIEW_Version ({vipbVersion ?? "unknown"}) is below required {targetYear}; update the VIPB before running {command}."
            };
            return new CommandResult(command, "fail", 1, 0, details);
        }
        return null;
    }

    private static void PrintProvenance()
    {
        var exePath = string.Empty;
        try { exePath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty; }
        catch { exePath = Environment.GetCommandLineArgs().FirstOrDefault() ?? string.Empty; }
        if (string.IsNullOrWhiteSpace(exePath))
        {
            exePath = "OrchestrationCli";
        }
        var sha = GetGitSha();
        var rid = System.Runtime.InteropServices.RuntimeInformation.RuntimeIdentifier;
        var repoEnv = Environment.GetEnvironmentVariable("ORCH_REPO_PATH") ?? string.Empty;
        var envTier = Environment.GetEnvironmentVariable("PROVENANCE_TIER");
        var envCacheKey = Environment.GetEnvironmentVariable("PROVENANCE_CACHEKEY");
        var tier = !string.IsNullOrWhiteSpace(envTier) ? envTier : InferTierFromPath(exePath);
        var cacheKey = !string.IsNullOrWhiteSpace(envCacheKey) ? envCacheKey : $"OrchestrationCli/{sha}/{rid}";

        Console.WriteLine($"cli=OrchestrationCli");
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
