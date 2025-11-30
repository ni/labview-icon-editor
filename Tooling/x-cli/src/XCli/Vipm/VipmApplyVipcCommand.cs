using System;
using System.IO;
using System.Text.Json;
using XCli.Labview.Providers;
using XCli.Simulation;

namespace XCli.Vipm;

public static class VipmApplyVipcCommand
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    private sealed class ApplyRequest
    {
        public string? RepoRoot { get; init; }
        public string? Workspace { get; init; }
        public string? VipcPath { get; init; }
        public string? MinimumSupportedLVVersion { get; init; }
        public string? VipLabVIEWVersion { get; init; }
        public int? SupportedBitness { get; init; }
        public string? Toolchain { get; init; } = "g-cli";
        public bool SkipExecution { get; init; }
        public string? JobName { get; init; }
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
                Console.Error.WriteLine($"[x-cli] vipm-apply-vipc: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(requestPath))
        {
            Console.Error.WriteLine("[x-cli] vipm-apply-vipc: --request PATH is required.");
            return new SimulationResult(false, 1);
        }

        requestPath = Path.GetFullPath(requestPath);
        if (!File.Exists(requestPath))
        {
            Console.Error.WriteLine($"[x-cli] vipm-apply-vipc: request not found at '{requestPath}'.");
            return new SimulationResult(false, 1);
        }

        ApplyRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<ApplyRequest>(File.ReadAllText(requestPath), JsonOptions);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vipm-apply-vipc: failed to parse request JSON: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        if (request == null)
        {
            Console.Error.WriteLine("[x-cli] vipm-apply-vipc: empty request payload.");
            return new SimulationResult(false, 1);
        }

        var repoRoot = ResolveRepoRoot(request.RepoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] vipm-apply-vipc: unable to resolve repo root (set repoRoot in request or XCLI_REPO_ROOT).");
            return new SimulationResult(false, 1);
        }

        var scriptPath = Path.Combine(repoRoot, "src", "tools", "icon-editor", "Apply-VipcJob.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"[x-cli] vipm-apply-vipc: replay script not found at '{scriptPath}'.");
            return new SimulationResult(false, 1);
        }

        var workspace = ResolvePathOrDefault(request.Workspace, repoRoot);
        var vipcPath = ResolvePathRelative(request.VipcPath ?? ".github/actions/apply-vipc/runner_dependencies.vipc", workspace);
        if (!File.Exists(vipcPath))
        {
            Console.Error.WriteLine($"[x-cli] vipm-apply-vipc: VIPC file not found at '{vipcPath}'.");
            return new SimulationResult(false, 1);
        }

        var argsList = new System.Collections.Generic.List<string>
        {
            "-Workspace", workspace,
            "-VipcPath", Relativize(vipcPath, workspace)
        };

        if (!string.IsNullOrWhiteSpace(request.MinimumSupportedLVVersion))
        {
            argsList.Add("-MinimumSupportedLVVersion");
            argsList.Add(request.MinimumSupportedLVVersion!);
        }
        if (!string.IsNullOrWhiteSpace(request.VipLabVIEWVersion))
        {
            argsList.Add("-VipLabVIEWVersion");
            argsList.Add(request.VipLabVIEWVersion!);
        }
        if (request.SupportedBitness.HasValue)
        {
            argsList.Add("-SupportedBitness");
            argsList.Add(request.SupportedBitness.Value.ToString());
        }
        if (!string.IsNullOrWhiteSpace(request.Toolchain))
        {
            argsList.Add("-Toolchain");
            argsList.Add(request.Toolchain!);
        }
        if (!string.IsNullOrWhiteSpace(request.JobName))
        {
            argsList.Add("-JobName");
            argsList.Add(request.JobName!);
        }
        if (request.SkipExecution)
        {
            argsList.Add("-SkipExecution");
        }

        var runResult = provider.RunPwshScript(new PwshScriptRequest(
            ScriptPath: scriptPath,
            Arguments: argsList.ToArray(),
            WorkingDirectory: workspace,
            TimeoutSeconds: 0
        ));

        if (!string.IsNullOrEmpty(runResult.StdOut))
        {
            Console.Write(runResult.StdOut);
        }
        if (!string.IsNullOrEmpty(runResult.StdErr))
        {
            Console.Error.Write(runResult.StdErr);
        }

        var exitCode = runResult.ExitCode;
        return new SimulationResult(runResult.Success, exitCode == 0 ? 0 : exitCode);
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

    private static string ResolvePathOrDefault(string? path, string defaultRoot)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return defaultRoot;
        }
        return Path.GetFullPath(Path.IsPathRooted(path) ? path : Path.Combine(defaultRoot, path));
    }

    private static string ResolvePathRelative(string path, string workspace)
    {
        if (Path.IsPathRooted(path))
        {
            return Path.GetFullPath(path);
        }
        return Path.GetFullPath(Path.Combine(workspace, path));
    }

    private static string Relativize(string path, string workspace)
    {
        try
        {
            var ws = Path.GetFullPath(workspace);
            var full = Path.GetFullPath(path);
            return Path.GetRelativePath(ws, full);
        }
        catch
        {
            return path;
        }
    }
}
