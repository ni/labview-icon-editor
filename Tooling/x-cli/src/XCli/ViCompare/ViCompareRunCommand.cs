using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using XCli.Simulation;
using XCli.Labview.Providers;

namespace XCli.ViCompare;

public static class ViCompareRunCommand
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    private sealed class RunRequest
    {
        public string? RepoRoot { get; init; }
        public string? ScenarioPath { get; init; }
        public string? OutputRoot { get; init; }
        public string? LabVIEWExePath { get; init; }
        public string? BundleOutputDirectory { get; init; }
        public string? NoiseProfile { get; init; }
        public bool IgnoreAttributes { get; init; }
        public bool IgnoreFrontPanel { get; init; }
        public bool IgnoreFrontPanelPosition { get; init; }
        public bool IgnoreBlockDiagram { get; init; }
        public bool IgnoreBlockDiagramCosmetics { get; init; }
        public bool DryRun { get; init; }
        public bool SkipBundle { get; init; }
    }

    private sealed class RunResponse
    {
        public string Schema { get; init; } = "icon-editor/vi-compare-run@v1";
        public string ScenarioPath { get; init; } = string.Empty;
        public string OutputRoot { get; init; } = string.Empty;
        public string? BundlePath { get; init; }
        public JsonElement? Summary { get; init; }
        public bool DryRun { get; init; }
        public string? SessionRoot { get; init; }
    }

    public static SimulationResult Run(string[] args) => Run(args, LabviewProviderFactory.CreateDefault());

    public static SimulationResult Run(string[] args, ILabviewProvider provider)
    {
        string? requestPath = null;
        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (arg == "--request" && i + 1 < args.Length)
            {
                requestPath = args[++i];
            }
            else
            {
                Console.Error.WriteLine($"[x-cli] vi-compare-run: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(requestPath))
        {
            Console.Error.WriteLine("[x-cli] vi-compare-run: --request PATH is required.");
            return new SimulationResult(false, 1);
        }

        requestPath = Path.GetFullPath(requestPath);
        if (!File.Exists(requestPath))
        {
            Console.Error.WriteLine($"[x-cli] vi-compare-run: request not found at '{requestPath}'.");
            return new SimulationResult(false, 1);
        }

        RunRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<RunRequest>(File.ReadAllText(requestPath), JsonOptions);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vi-compare-run: failed to parse request JSON: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        if (request == null)
        {
            Console.Error.WriteLine("[x-cli] vi-compare-run: empty request payload.");
            return new SimulationResult(false, 1);
        }

        var repoRoot = ResolveRepoRoot(request.RepoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] vi-compare-run: unable to resolve repo root.");
            return new SimulationResult(false, 1);
        }

        if (string.IsNullOrWhiteSpace(request.ScenarioPath))
        {
            Console.Error.WriteLine("[x-cli] vi-compare-run: scenarioPath is required.");
            return new SimulationResult(false, 1);
        }

        var scenarioPath = ResolvePath(request.ScenarioPath!, repoRoot);
        if (!File.Exists(scenarioPath))
        {
            Console.Error.WriteLine($"[x-cli] vi-compare-run: scenarioPath not found at '{scenarioPath}'.");
            return new SimulationResult(false, 1);
        }

        var scriptPath = Path.Combine(repoRoot, "tools", "icon-editor", "Replay-ViCompareScenario.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"[x-cli] vi-compare-run: Replay-ViCompareScenario.ps1 not found at '{scriptPath}'.");
            return new SimulationResult(false, 1);
        }

        var outputRoot = string.IsNullOrWhiteSpace(request.OutputRoot)
            ? Path.Combine(repoRoot, ".tmp-tests", "vi-compare-replays", DateTime.UtcNow.ToString("yyyyMMdd-HHmmss"))
            : ResolvePath(request.OutputRoot!, repoRoot, true);

        var tempRequestDir = Path.Combine(Path.GetTempPath(), "vi-compare-run");
        Directory.CreateDirectory(tempRequestDir);

        var argsList = new List<string>
        {
            "-RepoRoot", repoRoot,
            "-ScenarioPath", scenarioPath,
            "-OutputRoot", outputRoot,
            "-BundleOutputDirectory", request.BundleOutputDirectory ?? ".tmp-tests/vi-compare-bundles"
        };
        if (!string.IsNullOrWhiteSpace(request.LabVIEWExePath))
        {
            argsList.Add("-LabVIEWExePath");
            argsList.Add(ResolvePath(request.LabVIEWExePath!, repoRoot));
        }
        if (!string.IsNullOrWhiteSpace(request.NoiseProfile))
        {
            argsList.Add("-NoiseProfile");
            argsList.Add(request.NoiseProfile!);
        }
        if (request.IgnoreAttributes) argsList.Add("-IgnoreAttributes");
        if (request.IgnoreFrontPanel) argsList.Add("-IgnoreFrontPanel");
        if (request.IgnoreFrontPanelPosition) argsList.Add("-IgnoreFrontPanelPosition");
        if (request.IgnoreBlockDiagram) argsList.Add("-IgnoreBlockDiagram");
        if (request.IgnoreBlockDiagramCosmetics) argsList.Add("-IgnoreBlockDiagramCosmetics");
        if (request.DryRun) argsList.Add("-DryRun");
        if (request.SkipBundle) argsList.Add("-SkipBundle");

        var runResult = provider.RunPwshScript(new PwshScriptRequest(
            ScriptPath: scriptPath,
            Arguments: argsList.ToArray(),
            WorkingDirectory: repoRoot,
            TimeoutSeconds: 0
        ));

        if (!string.IsNullOrEmpty(runResult.StdOut)) Console.Write(runResult.StdOut);
        if (!string.IsNullOrEmpty(runResult.StdErr)) Console.Error.Write(runResult.StdErr);

        var exitCode = runResult.ExitCode;
        var summaryPath = Path.Combine(outputRoot, "vi-comparison-summary.json");
        JsonElement? summary = null;
        if (File.Exists(summaryPath))
        {
            try
            {
                using var doc = JsonDocument.Parse(File.ReadAllText(summaryPath));
                summary = doc.RootElement.Clone();
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[x-cli] vi-compare-run: failed to parse summary JSON: {ex.Message}");
            }
        }
        else
        {
            Console.Error.WriteLine($"[x-cli] vi-compare-run: summary not found at '{summaryPath}'.");
        }

        var bundlePath = FindBundlePath(outputRoot);
        var response = new RunResponse
        {
            ScenarioPath = scenarioPath,
            OutputRoot = outputRoot,
            BundlePath = bundlePath,
            Summary = summary,
            DryRun = request.DryRun || (summary?.TryGetProperty("dryRun", out var dryRunProp) == true && dryRunProp.ValueKind == JsonValueKind.True),
            SessionRoot = Path.Combine(repoRoot, ".tmp-tests", "vi-compare-sessions")
        };
        Console.WriteLine(JsonSerializer.Serialize(response, new JsonSerializerOptions { WriteIndented = true }));
        return new SimulationResult(exitCode == 0, exitCode);
    }

    private static string? ResolveRepoRoot(string? candidate)
    {
        var root = candidate;
        if (string.IsNullOrWhiteSpace(root))
        {
            root = Environment.GetEnvironmentVariable("XCLI_REPO_ROOT");
        }
        if (string.IsNullOrWhiteSpace(root))
        {
            return null;
        }
        try
        {
            return Path.GetFullPath(root);
        }
        catch
        {
            return null;
        }
    }

    private static string ResolvePath(string path, string repoRoot, bool ensureDirectory = false)
    {
        var candidate = Path.IsPathRooted(path) ? path : Path.Combine(repoRoot, path);
        var full = Path.GetFullPath(candidate);
        if (ensureDirectory && !Directory.Exists(full))
        {
            Directory.CreateDirectory(full);
        }
        return full;
    }

    private static string? FindBundlePath(string outputRoot)
    {
        var directory = Directory.GetParent(outputRoot)?.FullName;
        if (string.IsNullOrWhiteSpace(directory))
            return null;

        var bundlesRoot = Path.Combine(directory, "..", "vi-compare-bundles");
        if (!Directory.Exists(bundlesRoot))
            return null;

        foreach (var file in Directory.GetFiles(bundlesRoot, "vi-compare-*.zip", SearchOption.TopDirectoryOnly))
        {
            if (Path.GetFileNameWithoutExtension(file).Contains(Path.GetFileName(outputRoot)))
            {
                return file;
            }
        }
        return null;
    }
}
