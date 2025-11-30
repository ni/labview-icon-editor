using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Threading.Tasks;
using XCli.Labview.Providers;
using XCli.Simulation;

namespace XCli.SourceDist;

public static class SourceDistBuildCommand
{
    public static SimulationResult Run(string[] args) => Run(args, LabviewProviderSelector.Create());

    public static SimulationResult Run(string[] args, ILabviewProvider provider)
    {
        string? repoRoot = null;
        string? lvVersion = null;
        string? bitness = null;
        int timeoutSec = 0;
        bool verboseGit = false;
        bool perfCpu = false;
        bool allowDirty = false;
        string? commitIndexPath = null;

        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (arg == "--repo" && i + 1 < args.Length) repoRoot = args[++i];
            else if (arg == "--lv-version" && i + 1 < args.Length) lvVersion = args[++i];
            else if (arg == "--bitness" && i + 1 < args.Length) bitness = args[++i];
            else if (arg == "--timeout-sec" && i + 1 < args.Length && int.TryParse(args[++i], out var ts)) timeoutSec = ts;
            else if (arg == "--verbose-git") verboseGit = true;
            else if (arg == "--perf-cpu") perfCpu = true;
            else if (arg == "--allow-dirty") allowDirty = true;
            else if (arg == "--commit-index" && i + 1 < args.Length) commitIndexPath = args[++i];
            else
            {
                Console.Error.WriteLine($"[x-cli] source-dist-build: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        repoRoot = ResolveRepoRoot(repoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] source-dist-build: repo root required (set --repo or XCLI_REPO_ROOT).");
            return new SimulationResult(false, 1);
        }

        var scriptPath = Path.Combine(repoRoot, "scripts", "build-source-distribution", "Build_Source_Distribution.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"[x-cli] source-dist-build: script not found at '{scriptPath}'.");
            return new SimulationResult(false, 1);
        }

        var dirtyState = IsRepoDirty(repoRoot);
        if (dirtyState == true && !allowDirty)
        {
            Console.Error.WriteLine("[x-cli] source-dist-build: working tree is dirty; aborting. Clean the repo or re-run with --allow-dirty if you intentionally want to proceed.");
            return new SimulationResult(false, 2);
        }
        else if (dirtyState == null)
        {
            Console.WriteLine("[x-cli][warn] could not determine working tree cleanliness (git unavailable?); continuing.");
        }

        // Let the build script generate or consume the commit index after the SD is built.
        if (string.IsNullOrWhiteSpace(commitIndexPath))
        {
            commitIndexPath = Path.Combine(repoRoot, "builds", "cache", "commit-index.json");
        }

        var sw = Stopwatch.StartNew();
        var start = DateTime.UtcNow;
        Timer? hb = null;
        CancellationTokenSource? perfCts = null;
        Task<List<CpuSample>>? perfTask = null;
        try
        {
            hb = new Timer(_ =>
            {
                var elapsed = sw.Elapsed.TotalSeconds;
                Console.WriteLine($"[x-cli][hb] source-dist-build alive T+{elapsed:F1}s (repo={repoRoot})...");
            }, null, TimeSpan.FromSeconds(15), TimeSpan.FromSeconds(15));

            if (perfCpu)
            {
                perfCts = new CancellationTokenSource();
                perfTask = Task.Run(() => MonitorLabviewCpu(start, perfCts.Token));
                Console.WriteLine("[x-cli][perf] CPU sampling enabled; reporting peak/avg at completion.");
            }
        }
        catch { hb = null; }

        Console.WriteLine($"[x-cli] starting source-dist-build (repo={repoRoot}, lv={lvVersion ?? "vipb"}, bitness={bitness ?? "vipb"}). This may take a minute to launch g-cli/LabVIEW.");

        var argsList = new List<string> { "-RepositoryPath", repoRoot };
        if (!string.IsNullOrWhiteSpace(lvVersion))
        {
            argsList.Add("-Package_LabVIEW_Version");
            argsList.Add(lvVersion!);
        }
        if (!string.IsNullOrWhiteSpace(bitness))
        {
            argsList.Add("-SupportedBitness");
            argsList.Add(bitness!);
        }
        if (!string.IsNullOrWhiteSpace(commitIndexPath))
        {
            argsList.Add("-CommitIndexPath");
            argsList.Add(commitIndexPath);
        }
        if (verboseGit)
        {
            argsList.Add("-VerboseGit");
        }

        var runResult = provider.RunPwshScript(new PwshScriptRequest(
            ScriptPath: scriptPath,
            Arguments: argsList.ToArray(),
            WorkingDirectory: repoRoot,
            TimeoutSeconds: timeoutSec
        ));

        if (!string.IsNullOrEmpty(runResult.StdOut)) Console.Write(runResult.StdOut);
        if (!string.IsNullOrEmpty(runResult.StdErr)) Console.Error.Write(runResult.StdErr);

        sw.Stop();
        hb?.Dispose();
        Console.WriteLine($"[x-cli] source-dist-build completed status={(runResult.Success ? "success" : "fail")} exit={runResult.ExitCode} elapsed={sw.Elapsed.TotalSeconds:F1}s (started {start:HH:mm:ss}Z).");

        if (perfCts != null)
        {
            perfCts.Cancel();
            try
            {
                perfTask?.Wait(2000);
                var samples = perfTask?.Result ?? new List<CpuSample>();
                if (samples.Count > 0)
                {
                    var peak = samples.OrderByDescending(s => s.CpuPercent).First();
                    var avg = samples.Average(s => s.CpuPercent);
                    Console.WriteLine($"[x-cli][perf] LabVIEW CPU samples: {samples.Count}, peak {peak.CpuPercent:F1}% (pid {peak.Pid}), avg {avg:F1}%.");
                }
                else
                {
                    Console.WriteLine("[x-cli][perf] No LabVIEW CPU samples captured.");
                }
            }
            catch { /* ignore perf errors */ }
        }

        return new SimulationResult(runResult.Success, runResult.ExitCode);
    }

    private sealed record CpuSample(DateTime Timestamp, int Pid, double CpuPercent);

    private static List<CpuSample> MonitorLabviewCpu(DateTime start, CancellationToken token)
    {
        var samples = new List<CpuSample>();
        var lastCpu = new Dictionary<int, (TimeSpan Cpu, DateTime Ts)>();
        var interval = TimeSpan.FromSeconds(5);
        var cpuCount = Environment.ProcessorCount;

        while (!token.IsCancellationRequested)
        {
            var now = DateTime.UtcNow;
            try
            {
                var procs = Process.GetProcessesByName("LabVIEW")
                    .Where(p => p.StartTime.ToUniversalTime() >= start.AddMinutes(-5))
                    .ToList();
                foreach (var p in procs)
                {
                    try
                    {
                        var cpu = p.TotalProcessorTime;
                        if (lastCpu.TryGetValue(p.Id, out var prev))
                        {
                            var dt = (now - prev.Ts).TotalSeconds;
                            if (dt > 0)
                            {
                                var cpuDelta = (cpu - prev.Cpu).TotalSeconds;
                                var percent = (cpuDelta / dt) * 100.0 / cpuCount;
                                samples.Add(new CpuSample(now, p.Id, percent));
                            }
                        }
                        lastCpu[p.Id] = (cpu, now);
                    }
                    catch { }
                }
            }
            catch { }

            try { Task.Delay(interval, token).Wait(token); }
            catch { break; }
        }

        return samples;
    }

    private static string? ResolveRepoRoot(string? candidate)
    {
        var root = candidate;
        if (string.IsNullOrWhiteSpace(root))
        {
            root = Environment.GetEnvironmentVariable("XCLI_REPO_ROOT");
        }
        if (string.IsNullOrWhiteSpace(root)) return null;
        try { return Path.GetFullPath(root); }
        catch { return null; }
    }

    private static bool? IsRepoDirty(string repoRoot)
    {
        try
        {
            var psi = new ProcessStartInfo("git", "status --porcelain")
            {
                WorkingDirectory = repoRoot,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            using var proc = Process.Start(psi);
            if (proc == null) return null;
            var output = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit(5000);
            if (proc.ExitCode != 0) return null;
            return !string.IsNullOrWhiteSpace(output);
        }
        catch
        {
            return null;
        }
    }
}
