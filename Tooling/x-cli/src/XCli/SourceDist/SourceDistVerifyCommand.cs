using System;
using System.Collections.Generic;
using System.IO;
using XCli.Labview.Providers;
using XCli.Simulation;

namespace XCli.SourceDist;

public static class SourceDistVerifyCommand
{
    public static SimulationResult Run(string[] args) => Run(args, LabviewProviderSelector.Create());

    public static SimulationResult Run(string[] args, ILabviewProvider provider)
    {
        string? repoRoot = null;
        bool strict = true;
        bool logStash = true;
        int timeoutSec = 0;

        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (arg == "--repo" && i + 1 < args.Length) repoRoot = args[++i];
            else if (arg == "--no-strict") strict = false;
            else if (arg == "--no-log-stash") logStash = false;
            else if (arg == "--timeout-sec" && i + 1 < args.Length && int.TryParse(args[++i], out var ts)) timeoutSec = ts;
            else
            {
                Console.Error.WriteLine($"[x-cli] source-dist-verify: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        repoRoot = ResolveRepoRoot(repoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] source-dist-verify: repo root required (set --repo or XCLI_REPO_ROOT).");
            return new SimulationResult(false, 1);
        }

        var orchProject = Path.Combine(repoRoot, "Tooling", "dotnet", "OrchestrationCli", "OrchestrationCli.csproj");
        var argsList = new List<string>
        {
            "run",
            "--project",
            orchProject,
            "--",
            "source-dist-verify",
            "--repo",
            repoRoot
        };
        if (logStash) argsList.Add("--source-dist-log-stash");
        if (strict) argsList.Add("--source-dist-strict");

        var runResult = provider.RunPwshScript(new PwshScriptRequest(
            ScriptPath: "dotnet",
            Arguments: argsList.ToArray(),
            WorkingDirectory: repoRoot,
            TimeoutSeconds: timeoutSec,
            UseCommand: true
        ));

        if (!string.IsNullOrEmpty(runResult.StdOut)) Console.Write(runResult.StdOut);
        if (!string.IsNullOrEmpty(runResult.StdErr)) Console.Error.Write(runResult.StdErr);

        return new SimulationResult(runResult.Success, runResult.ExitCode);
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
}
