using System.Diagnostics;
using System.Text;

internal static class Program
{
    static Program()
    {
        IntegrationEngineCli.Security.IsolationGuard.Enforce();
    }

    private record Options(
        string RepoPath,
        string Ref,
        string SupportedBitness,
        string LvlibpBitness,
        int Major,
        int Minor,
        int Patch,
        int Build,
        string CompanyName,
        string AuthorName,
        int LabVIEWMinorRevision,
        bool RunBothBitnessSeparately,
        string PwshPath,
        bool Verbose,
        bool Managed,
        string? CompareRequestPath,
        bool CompareDryRun);

    private static void LogSection(string title)
    {
        var line = new string('=', Math.Max(20, Math.Min(80, title.Length + 12)));
        Console.WriteLine(line);
        Console.WriteLine($"[ie-cli] {title}");
        Console.WriteLine(line);
    }

    private static void LogInfo(string message) => Console.WriteLine($"[ie-cli] {message}");

    private static void LogWarn(string message) => Console.Error.WriteLine($"[ie-cli][warn] {message}");

    private static void LogError(string message) => Console.Error.WriteLine($"[ie-cli][error] {message}");

    private static void LogDuration(string title, TimeSpan elapsed)
    {
        var label = $"{title}";
        var line = new string('=', Math.Max(20, Math.Min(80, label.Length + 20)));
        Console.WriteLine(line);
        Console.WriteLine("[ie-cli] Duration");
        Console.WriteLine($"[ie-cli] {label}: {elapsed.TotalSeconds:F1}s");
        Console.WriteLine(line);
    }

    private static int Main(string[] args)
    {
        if (args.Any(a => a.Equals("--print-provenance", StringComparison.OrdinalIgnoreCase)))
        {
            PrintProvenance();
            return 0;
        }

        var parsed = SafeParseArgs(args);
        if (parsed.Error != null)
        {
            Console.Error.WriteLine(parsed.Error);
            PrintUsage();
            return 1;
        }

        if (parsed.HelpRequested)
        {
            PrintUsage();
            return 0;
        }

        var opts = parsed.Value!;
        return opts.Managed ? RunManagedBuild(opts) : RunPwshBuild(opts);
    }

    private static (Options? Value, string? Error, bool HelpRequested) SafeParseArgs(string[] args)
    {
        var repo = Directory.GetCurrentDirectory();
        var @ref = "HEAD";
        var bitness = "64";
        var lvlibpBitness = "both";
        int major = 0, minor = 1, patch = 0, build = 1;
        var company = "LabVIEW-Community-CI-CD";
        var author = "Local Developer";
        var labviewMinor = 3;
        var runBoth = false;
        var pwsh = "pwsh";
        var verbose = false;
        var managed = false;
        string? compareRequest = null;
        var compareDryRun = false;

        try
        {
            for (int i = 0; i < args.Length; i++)
            {
                var arg = args[i];
                switch (arg)
                {
                    case "--repo":
                        repo = RequireNext(args, ref i, "--repo");
                        break;
                    case "--ref":
                        @ref = RequireNext(args, ref i, "--ref");
                        break;
                    case "--bitness":
                        bitness = RequireNext(args, ref i, "--bitness");
                        break;
                    case "--lvlibp-bitness":
                        lvlibpBitness = RequireNext(args, ref i, "--lvlibp-bitness");
                        break;
                    case "--major":
                        major = ParseInt(RequireNext(args, ref i, "--major"), "--major");
                        break;
                    case "--minor":
                        minor = ParseInt(RequireNext(args, ref i, "--minor"), "--minor");
                        break;
                    case "--patch":
                        patch = ParseInt(RequireNext(args, ref i, "--patch"), "--patch");
                        break;
                    case "--build":
                        build = ParseInt(RequireNext(args, ref i, "--build"), "--build");
                        break;
                    case "--company":
                        company = RequireNext(args, ref i, "--company");
                        break;
                    case "--author":
                        author = RequireNext(args, ref i, "--author");
                        break;
                    case "--labview-minor":
                        labviewMinor = ParseInt(RequireNext(args, ref i, "--labview-minor"), "--labview-minor");
                        break;
                    case "--run-both-bitness-separately":
                        runBoth = true;
                        break;
                    case "--pwsh":
                        pwsh = RequireNext(args, ref i, "--pwsh");
                        break;
                    case "--verbose":
                        verbose = true;
                        break;
                    case "--managed":
                        managed = true;
                        break;
                    case "--vi-compare-request":
                        compareRequest = RequireNext(args, ref i, "--vi-compare-request");
                        break;
                    case "--vi-compare-dry-run":
                        compareDryRun = true;
                        break;
                    case "--help":
                    case "-h":
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

        bitness = ValidateChoice(bitness, "--bitness", "32", "64");
        lvlibpBitness = ValidateChoice(lvlibpBitness, "--lvlibp-bitness", "both", "32", "64");
        if (labviewMinor is not (0 or 3))
        {
            return (null, "Invalid --labview-minor. Expected 0 or 3.", false);
        }
        if (major < 0 || minor < 0 || patch < 0 || build < 0)
        {
            return (null, "Version components must be non-negative integers.", false);
        }

        var repoFull = Path.GetFullPath(repo);
        if (!Directory.Exists(repoFull))
        {
            return (null, $"Repository path not found: {repoFull}", false);
        }

        return (new Options(
            RepoPath: repoFull,
            Ref: @ref,
            SupportedBitness: bitness,
            LvlibpBitness: lvlibpBitness,
            Major: major,
            Minor: minor,
            Patch: patch,
            Build: build,
            CompanyName: company,
            AuthorName: author,
            LabVIEWMinorRevision: labviewMinor,
            RunBothBitnessSeparately: runBoth,
            PwshPath: pwsh,
            Verbose: verbose,
            Managed: managed,
            CompareRequestPath: compareRequest,
            CompareDryRun: compareDryRun
        ), null, false);
    }

    private static int RunPwshBuild(Options opts)
    {
        var ieScript = Path.Combine(opts.RepoPath, "scripts", "ie.ps1");
        if (!File.Exists(ieScript))
        {
            Console.Error.WriteLine($"Integration Engine entrypoint not found at {ieScript}");
            return 1;
        }

        var args = new List<string>
        {
            "-NoProfile",
            "-File", ieScript,
            "-Command", "build-worktree",
            "-RepositoryPath", opts.RepoPath,
            "-Ref", opts.Ref,
            "-SupportedBitness", opts.SupportedBitness,
            "-LvlibpBitness", opts.LvlibpBitness,
            "-Major", opts.Major.ToString(),
            "-Minor", opts.Minor.ToString(),
            "-Patch", opts.Patch.ToString(),
            "-Build", opts.Build.ToString(),
            "-CompanyName", opts.CompanyName,
            "-AuthorName", opts.AuthorName,
            "-LabVIEWMinorRevision", opts.LabVIEWMinorRevision.ToString()
        };

        if (opts.RunBothBitnessSeparately)
        {
            args.Add("-RunBothBitnessSeparately");
        }

        if (opts.Verbose)
        {
            args.Add("-Verbose");
        }

        var psi = new ProcessStartInfo
        {
            FileName = opts.PwshPath,
            WorkingDirectory = opts.RepoPath,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        foreach (var a in args)
        {
            psi.ArgumentList.Add(a);
        }

        Console.WriteLine($"[ie-cli] Starting build-worktree for repo {opts.RepoPath} (ref {opts.Ref}, bitness {opts.SupportedBitness}/{opts.LvlibpBitness})");

        var process = Process.Start(psi);
        if (process == null)
        {
            Console.Error.WriteLine("Failed to start PowerShell process.");
            return 1;
        }

        process.OutputDataReceived += (_, e) => { if (e.Data != null) { Console.Out.WriteLine(e.Data); } };
        process.ErrorDataReceived += (_, e) => { if (e.Data != null) { Console.Error.WriteLine(e.Data); } };
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        process.WaitForExit();

        Console.WriteLine($"[ie-cli] Exit code: {process.ExitCode}");

        if (process.ExitCode == 0)
        {
            var do32 = opts.LvlibpBitness.Equals("both", StringComparison.OrdinalIgnoreCase) || opts.LvlibpBitness == "32";
            var do64 = opts.LvlibpBitness.Equals("both", StringComparison.OrdinalIgnoreCase) || opts.LvlibpBitness == "64";
            var revertScript = Path.Combine(opts.RepoPath, "scripts", "revert-development-mode", "RevertDevelopmentMode.ps1");
            if (File.Exists(revertScript))
            {
                foreach (var bit in new[] { "64", "32" })
                {
                    if (bit == "32" && !do32) continue;
                    if (bit == "64" && !do64) continue;

                    var revert = RunPwshScript(opts.PwshPath, opts.RepoPath, revertScript, new Dictionary<string, string>
                    {
                        { "RepositoryPath", opts.RepoPath },
                        { "SupportedBitness", bit }
                    }, opts.Verbose, label: $"revert-devmode-{bit}", echoOutput: opts.Verbose);
                    if (revert.ExitCode != 0)
                    {
                        LogWarn($"Revert development mode ({bit}-bit) reported exit {revert.ExitCode}. Continuing.");
                    }
                }
            }
            else
            {
                LogWarn($"Revert script not found at {revertScript}; dev-mode cleanup was skipped.");
            }
        }

        return process.ExitCode;
    }

    private static void PrintUsage()
    {
        Console.WriteLine("ie-cli (Integration Engine CLI) - builds the LabVIEW Icon Editor");
        Console.WriteLine("Usage:");
        Console.WriteLine("  dotnet run -- [options]");
        Console.WriteLine("Options:");
        Console.WriteLine("  --repo <path>              Repository path (default: current directory)");
        Console.WriteLine("  --ref <ref>                Git ref to build (default: HEAD)");
        Console.WriteLine("  --bitness <32|64>          LabVIEW bitness to build (default: 64)");
        Console.WriteLine("  --lvlibp-bitness <both|32|64>  PPL bitness (default: both)");
        Console.WriteLine("  --major <int>              Version major (default: 0)");
        Console.WriteLine("  --minor <int>              Version minor (default: 1)");
        Console.WriteLine("  --patch <int>              Version patch (default: 0)");
        Console.WriteLine("  --build <int>              Version build (default: 1)");
        Console.WriteLine("  --company <str>            Company name");
        Console.WriteLine("  --author <str>             Author name");
        Console.WriteLine("  --labview-minor <0|3>      LabVIEW minor revision (default: 3)");
        Console.WriteLine("  --run-both-bitness-separately  Build 32/64 in separate lanes");
        Console.WriteLine("  --pwsh <path>              PowerShell executable (default: pwsh)");
        Console.WriteLine("  --verbose                  Pass -Verbose to PowerShell");
        Console.WriteLine("  --managed                  Use managed orchestration (invokes individual scripts) instead of ie.ps1 wrapper");
        Console.WriteLine("  --vi-compare-request <path>  Optional: run VI compare replay with the given request file");
        Console.WriteLine("  --vi-compare-dry-run         Force VI compare dry-run (skip LVCompare execution)");
        Console.WriteLine("  -h, --help                 Show this help");
    }

    private static int RunManagedBuild(Options opts)
    {
        if (!OperatingSystem.IsWindows())
        {
            LogError("Managed build requires Windows (LabVIEW/VIPM).");
            return 1;
        }

        LogSection("Managed Integration Engine build");
        LogInfo($"Repository: {opts.RepoPath}");
        LogInfo($"Ref: {opts.Ref}; lvlibp-bitness: {opts.LvlibpBitness}; version: {opts.Major}.{opts.Minor}.{opts.Patch}.{opts.Build}");

        var repo = opts.RepoPath;
        var scriptsRoot = Path.Combine(repo, "scripts");
        string Script(string relative) => Path.Combine(scriptsRoot, relative);

        var bindScript = Script(Path.Combine("bind-development-mode", "BindDevelopmentMode.ps1"));
        var closeScript = Script(Path.Combine("close-labview", "Close_LabVIEW.ps1"));
        var buildLvlibpScript = Script(Path.Combine("build-lvlibp", "Build_lvlibp.ps1"));
        var renameScript = Script(Path.Combine("rename-file", "Rename-file.ps1"));
        var buildVipScript = Script(Path.Combine("build-vip", "build_vip.ps1"));
        var getLvVersionScript = Script("get-package-lv-version.ps1");
        var sourceDistScript = Script(Path.Combine("build-source-distribution", "Build_Source_Distribution.ps1"));
        var revertScript = Script(Path.Combine("revert-development-mode", "RevertDevelopmentMode.ps1"));
        var compareScript = Script(Path.Combine("vi-compare", "RunViCompareReplay.ps1"));
        var releaseNotes = Path.Combine(repo, "Tooling", "deployment", "release_notes.md");
        var vipbPath = Path.Combine(repo, "Tooling", "deployment", "seed.vipb");

        foreach (var path in new[] { bindScript, closeScript, buildLvlibpScript, renameScript, buildVipScript, getLvVersionScript, sourceDistScript })
        {
            if (!File.Exists(path))
            {
                LogError($"Missing required script: {path}");
                return 1;
            }
        }
        if (opts.CompareRequestPath is not null && !File.Exists(compareScript))
        {
            LogError($"Compare wrapper not found at {compareScript}");
            return 1;
        }

        var vipmPath = ResolveVipmPath(repo, opts.PwshPath, opts.Verbose);
        if (vipmPath == null)
        {
            LogError("VIPM CLI not found. Set VIPM_PATH or configure labview-paths.json.");
            return 1;
        }
        Environment.SetEnvironmentVariable("VIPM_PATH", vipmPath);
        var vipmDir = Path.GetDirectoryName(vipmPath);
        if (!string.IsNullOrWhiteSpace(vipmDir))
        {
            var currentPath = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
            if (!currentPath.Split(';').Any(p => string.Equals(p, vipmDir, StringComparison.OrdinalIgnoreCase)))
            {
                Environment.SetEnvironmentVariable("PATH", vipmDir + ";" + currentPath);
            }
        }

        var commit = RunCommand("git", repo, new[] { "rev-parse", "--short", opts.Ref }, label: "git", echoOutput: opts.Verbose);
        if (commit.ExitCode != 0 || string.IsNullOrWhiteSpace(commit.StdOut))
        {
            LogError($"Failed to resolve commit for ref {opts.Ref} (exit {commit.ExitCode}).");
            if (!string.IsNullOrWhiteSpace(commit.StdErr))
            {
                Console.Error.WriteLine(commit.StdErr.TrimEnd());
            }
            return commit.ExitCode == 0 ? 1 : commit.ExitCode;
        }
        var commitKey = commit.StdOut.Trim();
        LogInfo($"Commit resolved: {commitKey}");

        var lvVersionResult = RunPwshScript(opts.PwshPath, repo, getLvVersionScript, new Dictionary<string, string>
        {
            { "RepositoryPath", repo }
        }, opts.Verbose, label: "get-package-lv-version", echoOutput: true);
        if (lvVersionResult.ExitCode != 0 || string.IsNullOrWhiteSpace(lvVersionResult.StdOut))
        {
            return ReportFailure("Resolve LabVIEW version", lvVersionResult);
        }
        var lvVersion = lvVersionResult.StdOut.Trim();
        LogInfo($"LabVIEW version: {lvVersion}");

        bool do32 = opts.LvlibpBitness.Equals("both", StringComparison.OrdinalIgnoreCase) || opts.LvlibpBitness == "32";
        bool do64 = opts.LvlibpBitness.Equals("both", StringComparison.OrdinalIgnoreCase) || opts.LvlibpBitness == "64";

        var devBound32 = false;
        var devBound64 = false;
        var pplBuilt32 = false;
        var pplBuilt64 = false;
        var pplStaged = false;
        var vipBuilt = false;

        foreach (var bit in new[] { "64", "32" })
        {
            if (bit == "32" && !do32) continue;
            if (bit == "64" && !do64) continue;

            LogSection($"Bind development mode ({bit}-bit)");
            var bind = RunPwshScript(opts.PwshPath, repo, bindScript, new Dictionary<string, string>
            {
                { "RepositoryPath", repo },
                { "Mode", "bind" },
                { "Bitness", bit },
                { "Force", "True" }
            }, opts.Verbose, label: $"bind-{bit}", echoOutput: true);
            if (bind.ExitCode != 0)
            {
                return ReportFailure($"Bind development mode ({bit}-bit)", bind);
            }
            if (bit == "32") devBound32 = true; else devBound64 = true;
        }

        foreach (var bit in new[] { "64", "32" })
        {
            if (bit == "32" && !do32) continue;
            if (bit == "64" && !do64) continue;

            LogSection($"Close LabVIEW ({bit}-bit)");
            var closeTimer = Stopwatch.StartNew();
            var close = RunPwshScript(opts.PwshPath, repo, closeScript, new Dictionary<string, string>
            {
                { "Package_LabVIEW_Version", lvVersion },
                { "SupportedBitness", bit }
            }, opts.Verbose, label: $"close-labview-{bit}", echoOutput: true);
            closeTimer.Stop();
            if (close.ExitCode != 0)
            {
                return ReportFailure($"Close LabVIEW ({bit}-bit)", close);
            }
            LogDuration($"Close LabVIEW ({bit}-bit)", closeTimer.Elapsed);
        }

        if (do32)
        {
            LogSection("Build PPL (32-bit)");
            var build32Timer = Stopwatch.StartNew();
            var build32 = RunPwshScript(opts.PwshPath, repo, buildLvlibpScript, new Dictionary<string, string>
            {
                { "Package_LabVIEW_Version", lvVersion },
                { "SupportedBitness", "32" },
                { "RepositoryPath", repo },
                { "Major", opts.Major.ToString() },
                { "Minor", opts.Minor.ToString() },
                { "Patch", opts.Patch.ToString() },
                { "Build", opts.Build.ToString() },
                { "Commit", commitKey }
            }, opts.Verbose, label: "build-lvlibp-32", echoOutput: true);
            if (build32.ExitCode != 0)
            {
                return ReportFailure("Build PPL 32-bit", build32);
            }

            var rename32 = RunPwshScript(opts.PwshPath, repo, renameScript, new Dictionary<string, string>
            {
                { "CurrentFilename", Path.Combine(repo, "resource", "plugins", "lv_icon.lvlibp") },
                { "NewFilename", "lv_icon_x86.lvlibp" }
            }, opts.Verbose, label: "rename-ppl-32", echoOutput: opts.Verbose);
            if (rename32.ExitCode != 0)
            {
                return ReportFailure("Rename 32-bit PPL", rename32);
            }

            StashPpl(repo, commitKey, "lv_icon_x86.lvlibp");
            pplBuilt32 = true;
            build32Timer.Stop();
            LogDuration("Build PPL (32-bit)", build32Timer.Elapsed);
        }

        // Reset the project between bitness builds to avoid cross-bitness state.
        if (do32 && do64)
        {
            RestoreLvproj(repo);
            LogSection("Close LabVIEW (32-bit)");
            var close32Timer = Stopwatch.StartNew();
            var close32 = RunPwshScript(opts.PwshPath, repo, closeScript, new Dictionary<string, string>
            {
                { "Package_LabVIEW_Version", lvVersion },
                { "SupportedBitness", "32" }
            }, opts.Verbose, label: "close-labview-32", echoOutput: true);
            close32Timer.Stop();
            if (close32.ExitCode != 0)
            {
                return ReportFailure("Close LabVIEW (32-bit)", close32);
            }
            LogDuration("Close LabVIEW (32-bit)", close32Timer.Elapsed);
        }

        if (do64)
        {
            LogSection("Build PPL (64-bit)");
            var build64Timer = Stopwatch.StartNew();
            var build64 = RunPwshScript(opts.PwshPath, repo, buildLvlibpScript, new Dictionary<string, string>
            {
                { "Package_LabVIEW_Version", lvVersion },
                { "SupportedBitness", "64" },
                { "RepositoryPath", repo },
                { "Major", opts.Major.ToString() },
                { "Minor", opts.Minor.ToString() },
                { "Patch", opts.Patch.ToString() },
                { "Build", opts.Build.ToString() },
                { "Commit", commitKey }
            }, opts.Verbose, label: "build-lvlibp-64", echoOutput: true);
            if (build64.ExitCode != 0)
            {
                return ReportFailure("Build PPL 64-bit", build64);
            }

            var rename64 = RunPwshScript(opts.PwshPath, repo, renameScript, new Dictionary<string, string>
            {
                { "CurrentFilename", Path.Combine(repo, "resource", "plugins", "lv_icon.lvlibp") },
                { "NewFilename", "lv_icon_x64.lvlibp" }
            }, opts.Verbose, label: "rename-ppl-64", echoOutput: opts.Verbose);
            if (rename64.ExitCode != 0)
            {
                return ReportFailure("Rename 64-bit PPL", rename64);
            }

            StashPpl(repo, commitKey, "lv_icon_x64.lvlibp");
            pplBuilt64 = true;
            build64Timer.Stop();
            LogDuration("Build PPL (64-bit)", build64Timer.Elapsed);
        }

        pplStaged = StagePpls(repo, do32, do64);
        if (!pplStaged)
        {
            return 1;
        }

        var displayInfo = BuildDisplayInfo(opts.CompanyName, opts.AuthorName, opts.Major, opts.Minor, opts.Patch, opts.Build, opts.RepoPath);
        LogInfo("DisplayInformation JSON prepared.");

        LogSection("Build VIP package (64-bit)");
        var vipTimer = Stopwatch.StartNew();
        var buildVip = RunPwshScript(opts.PwshPath, repo, buildVipScript, new Dictionary<string, string>
        {
            { "SupportedBitness", "64" },
            { "RepositoryPath", repo },
            { "VIPBPath", vipbPath },
            { "Package_LabVIEW_Version", lvVersion },
            { "LabVIEWMinorRevision", opts.LabVIEWMinorRevision.ToString() },
            { "Major", opts.Major.ToString() },
            { "Minor", opts.Minor.ToString() },
            { "Patch", opts.Patch.ToString() },
            { "Build", opts.Build.ToString() },
            { "Commit", commitKey },
            { "ReleaseNotesFile", releaseNotes },
            { "DisplayInformationJSON", displayInfo }
        }, opts.Verbose, label: "build-vip", echoOutput: true);
        if (buildVip.ExitCode != 0)
        {
            return ReportFailure("Build VIP package", buildVip);
        }
        vipBuilt = true;
        vipTimer.Stop();
        LogDuration("Build VIP package (64-bit)", vipTimer.Elapsed);

        LogSection("Build Source Distribution");
        var sourceTimer = Stopwatch.StartNew();
        var sourceDist = RunPwshScript(opts.PwshPath, repo, sourceDistScript, new Dictionary<string, string>
        {
            { "RepositoryPath", repo }
        }, opts.Verbose, label: "source-distribution", echoOutput: true);
        sourceTimer.Stop();
        if (sourceDist.ExitCode != 0)
        {
            return ReportFailure("Build Source Distribution", sourceDist);
        }
        LogDuration("Build Source Distribution", sourceTimer.Elapsed);

        foreach (var bit in new[] { "64", "32" })
        {
            if (bit == "32" && !do32) continue;
            if (bit == "64" && !do64) continue;
            if (!File.Exists(revertScript)) continue;

            var revert = RunPwshScript(opts.PwshPath, repo, revertScript, new Dictionary<string, string>
            {
                { "RepositoryPath", repo },
                { "SupportedBitness", bit }
            }, opts.Verbose, label: $"revert-devmode-{bit}", echoOutput: opts.Verbose);
            if (revert.ExitCode != 0)
            {
                LogWarn($"Revert development mode ({bit}-bit) reported exit {revert.ExitCode}. Continuing.");
            }
        }

        LogSection("Recap");
        var devModeOk = (!do64 || devBound64) && (!do32 || devBound32);
        var pplOk = pplStaged && (!do64 || pplBuilt64) && (!do32 || pplBuilt32);
        LogInfo($"Dev mode: {(devModeOk ? "OK" : "incomplete")}");
        LogInfo($"PPL build: {(pplOk ? "OK" : "incomplete")} (32-bit={pplBuilt32}, 64-bit={pplBuilt64})");
        LogInfo($"VIP package: {(vipBuilt ? "OK" : "not built")}");

        if (opts.CompareRequestPath is not null)
        {
            var compareRequestFull = Path.IsPathRooted(opts.CompareRequestPath)
                ? opts.CompareRequestPath
                : Path.Combine(repo, opts.CompareRequestPath);

            if (!File.Exists(compareRequestFull))
            {
                LogError($"Compare request file not found: {compareRequestFull}");
                return 1;
            }

            LogSection("VI compare replay");
            var compareArgs = new Dictionary<string, string>
            {
                { "RequestPath", compareRequestFull }
            };
            if (opts.CompareDryRun)
            {
                compareArgs.Add("ForceDryRun", "True");
            }

            var compare = RunPwshScript(opts.PwshPath, repo, compareScript, compareArgs, opts.Verbose, label: "vi-compare", echoOutput: true);
            if (compare.ExitCode != 0)
            {
                return ReportFailure("VI compare replay", compare);
            }
        }

        LogInfo("Managed build completed.");
        return 0;
    }

    private static string? ResolveVipmPath(string repo, string pwsh, bool verbose)
    {
        var vendorTools = Path.Combine(repo, "tools", "VendorTools.psm1");
        if (!File.Exists(vendorTools))
        {
            LogWarn($"VendorTools.psm1 not found at {vendorTools}; VIPM path resolution skipped.");
            return null;
        }

        var script = $"Import-Module '{vendorTools}'; $p = Resolve-VIPMPath; if (-not $p) {{ exit 1 }}; Write-Output $p";
        var result = RunCommand(pwsh, repo, new[] { "-NoProfile", "-Command", script }, "resolve-vipm", verbose);
        if (result.ExitCode != 0)
        {
            LogWarn("Failed to resolve VIPM path via VendorTools.");
            return null;
        }

        var path = result.StdOut.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
        if (string.IsNullOrWhiteSpace(path))
        {
            LogWarn("VendorTools returned an empty VIPM path.");
            return null;
        }
        return path.Trim();
    }

    private static void StashPpl(string repo, string commitKey, string fileName)
    {
        var stashDir = Path.Combine(repo, "builds", "lvlibp-stash", commitKey);
        Directory.CreateDirectory(stashDir);
        var source = Path.Combine(repo, "resource", "plugins", fileName);
        if (!File.Exists(source))
        {
            LogWarn($"Skipping stash for {fileName} because it was not found at {source}");
            return;
        }

        var destination = Path.Combine(stashDir, fileName);
        File.Copy(source, destination, overwrite: true);
        LogInfo($"Stashed {fileName} at {destination}");
    }

    private static bool StagePpls(string repo, bool do32, bool do64)
    {
        var plugins = Path.Combine(repo, "resource", "plugins");
        var neutral = Path.Combine(plugins, "lv_icon.lvlibp");
        var win64 = Path.Combine(plugins, "lv_icon.lvlibp.windows_x64");
        var win32 = Path.Combine(plugins, "lv_icon.lvlibp.windows_x86");
        var x64 = Path.Combine(plugins, "lv_icon_x64.lvlibp");
        var x86 = Path.Combine(plugins, "lv_icon_x86.lvlibp");

        var ok = true;

        if (do64 && File.Exists(x64))
        {
            File.Copy(x64, neutral, true);
            File.Copy(x64, win64, true);
            LogInfo("Staged 64-bit PPL into neutral/windows_x64 slots.");
        }
        else if (do64)
        {
            LogError($"Expected 64-bit PPL not found at {x64}");
            ok = false;
        }
        if (do32 && File.Exists(x86))
        {
            if (!File.Exists(neutral))
            {
                File.Copy(x86, neutral, true);
            }
            File.Copy(x86, win32, true);
            LogInfo("Staged 32-bit PPL into neutral/windows_x86 slots.");
        }
        else if (do32)
        {
            LogError($"Expected 32-bit PPL not found at {x86}");
            ok = false;
        }

        foreach (var temp in new[] { x64, x86 })
        {
            if (File.Exists(temp))
            {
                File.Delete(temp);
            }
        }

        return ok;
    }

    private static void RestoreLvproj(string repo)
    {
        var lvproj = Path.Combine(repo, "lv_icon_editor.lvproj");
        if (!File.Exists(lvproj))
        {
            LogWarn($"Skip lvproj restore: file not found at {lvproj}");
            return;
        }

        var result = RunCommand("git", repo, new[] { "checkout", "--", lvproj }, label: "git-restore-lvproj", echoOutput: false);
        if (result.ExitCode != 0)
        {
            LogWarn($"lvproj restore attempted but git returned {result.ExitCode}. Proceeding.");
        }
        else
        {
            LogInfo("Restored lv_icon_editor.lvproj between bitness builds.");
        }
    }

    private static string BuildDisplayInfo(string company, string author, int major, int minor, int patch, int build, string repoPath)
    {
        var homepage = "https://github.com/ni/labview-icon-editor";
        var gitRemote = RunCommand("git", repoPath, new[] { "config", "--get", "remote.origin.url" });
        if (gitRemote.ExitCode == 0 && !string.IsNullOrWhiteSpace(gitRemote.StdOut))
        {
            homepage = gitRemote.StdOut.Trim();
        }

        return $$"""
{
  "Package Version": {
    "major": {{major}},
    "minor": {{minor}},
    "patch": {{patch}},
    "build": {{build}}
  },
  "Product Name": "LabVIEW Icon Editor",
  "Company Name": "{{company}}",
  "Author Name (Person or Company)": "{{author}}",
  "Product Homepage (URL)": "{{homepage}}",
  "Product Description Summary": "Community integration engine for LabVIEW",
  "Product Description": "Community-driven integration engine for LabVIEW.",
  "Release Notes - Change Log": "",
  "License Agreement Name": "",
  "Legal Copyright": "LabVIEW-Community-CI-CD"
}
""";
    }

    private static (int ExitCode, string StdOut, string StdErr) RunPwshScript(string pwsh, string workingDir, string scriptPath, Dictionary<string, string> args, bool verbose, string? label = null, bool echoOutput = false)
    {
        var argList = new List<string> { "-NoProfile", "-File", scriptPath };
        foreach (var kvp in args)
        {
            argList.Add("-" + kvp.Key);
            argList.Add(kvp.Value);
        }
        if (verbose)
        {
            argList.Add("-Verbose");
        }
        label ??= Path.GetFileNameWithoutExtension(scriptPath);
        return RunCommand(pwsh, workingDir, argList, label, echoOutput);
    }

    private static (int ExitCode, string StdOut, string StdErr) RunCommand(string fileName, string workingDir, IEnumerable<string> args, string? label = null, bool echoOutput = false)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            WorkingDirectory = workingDir,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        foreach (var a in args) psi.ArgumentList.Add(a);

        var proc = Process.Start(psi);
        if (proc == null)
        {
            return (1, string.Empty, "Failed to start process");
        }
        var stdout = new StringBuilder();
        var stderr = new StringBuilder();
        void HandleOut(string? data)
        {
            if (data == null) return;
            stdout.AppendLine(data);
            if (echoOutput)
            {
                Console.Out.WriteLine(label != null ? $"[{label}] {data}" : data);
            }
        }

        void HandleErr(string? data)
        {
            if (data == null) return;
            stderr.AppendLine(data);
            if (echoOutput)
            {
                Console.Error.WriteLine(label != null ? $"[{label}] {data}" : data);
            }
        }

        proc.OutputDataReceived += (_, e) => HandleOut(e.Data);
        proc.ErrorDataReceived += (_, e) => HandleErr(e.Data);
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();
        proc.WaitForExit();
        return (proc.ExitCode, stdout.ToString(), stderr.ToString());
    }

    private static int ReportFailure(string step, (int ExitCode, string StdOut, string StdErr) result)
    {
        var exit = result.ExitCode == 0 ? 1 : result.ExitCode;
        LogError($"{step} failed (exit {exit}).");
        if (!string.IsNullOrWhiteSpace(result.StdOut))
        {
            Console.Error.WriteLine(result.StdOut.TrimEnd());
        }
        if (!string.IsNullOrWhiteSpace(result.StdErr))
        {
            Console.Error.WriteLine(result.StdErr.TrimEnd());
        }
        return exit;
    }

    private static string RequireNext(string[] args, ref int index, string name)
    {
        if (index + 1 >= args.Length)
        {
            throw new ArgumentException($"Missing value for {name}");
        }
        return args[++index];
    }

    private static string ValidateChoice(string value, string name, params string[] allowed)
    {
        foreach (var candidate in allowed)
        {
            if (value.Equals(candidate, StringComparison.OrdinalIgnoreCase))
            {
                return candidate.ToLowerInvariant();
            }
        }

        var allowedText = string.Join(", ", allowed);
        throw new ArgumentException($"{name} must be one of: {allowedText}");
    }

    private static int ParseInt(string value, string name)
    {
        if (int.TryParse(value, out var parsed))
        {
            return parsed;
        }
        throw new ArgumentException($"Invalid integer for {name}: {value}");
    }

    private static void PrintProvenance()
    {
        var exePath = string.Empty;
        try { exePath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty; }
        catch { exePath = Environment.GetCommandLineArgs().FirstOrDefault() ?? string.Empty; }
        if (string.IsNullOrWhiteSpace(exePath))
        {
            exePath = "IntegrationEngineCli";
        }
        var sha = GetGitSha();
        var rid = System.Runtime.InteropServices.RuntimeInformation.RuntimeIdentifier;
        var repoEnv = Environment.GetEnvironmentVariable("IE_REPO_PATH") ?? string.Empty;
        var envTier = Environment.GetEnvironmentVariable("PROVENANCE_TIER");
        var envCacheKey = Environment.GetEnvironmentVariable("PROVENANCE_CACHEKEY");
        var tier = !string.IsNullOrWhiteSpace(envTier) ? envTier : InferTierFromPath(exePath);
        var cacheKey = !string.IsNullOrWhiteSpace(envCacheKey) ? envCacheKey : $"IntegrationEngineCli/{sha}/{rid}";
        Console.WriteLine($"cli=IntegrationEngineCli");
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
