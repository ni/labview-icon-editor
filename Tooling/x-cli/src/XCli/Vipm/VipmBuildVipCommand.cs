using System;
using System.IO;
using System.Text.Json;
using XCli.Labview.Providers;
using XCli.Simulation;

namespace XCli.Vipm;

public static class VipmBuildVipCommand
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    private sealed class BuildRequest
    {
        public string? RepoRoot { get; init; }
        public string? Workspace { get; init; }
        public string? ReleaseNotesPath { get; init; }
        public bool SkipReleaseNotes { get; init; }
        public bool SkipVipbUpdate { get; init; }
        public bool SkipBuild { get; init; }
        public bool CloseLabVIEW { get; init; }
        public bool DownloadArtifacts { get; init; }
        public string? BuildToolchain { get; init; } = "g-cli";
        public string? BuildProvider { get; init; }
        public string? JobName { get; init; }
        public string? RunId { get; init; }
        public string? LogPath { get; init; }
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
                Console.Error.WriteLine($"[x-cli] vipm-build-vip: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(requestPath))
        {
            Console.Error.WriteLine("[x-cli] vipm-build-vip: --request PATH is required.");
            return new SimulationResult(false, 1);
        }

        requestPath = Path.GetFullPath(requestPath);
        if (!File.Exists(requestPath))
        {
            Console.Error.WriteLine($"[x-cli] vipm-build-vip: request not found at '{requestPath}'.");
            return new SimulationResult(false, 1);
        }

        BuildRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<BuildRequest>(File.ReadAllText(requestPath), JsonOptions);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vipm-build-vip: failed to parse request JSON: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        if (request == null)
        {
            Console.Error.WriteLine("[x-cli] vipm-build-vip: empty request payload.");
            return new SimulationResult(false, 1);
        }

        var repoRoot = ResolveRepoRoot(request.RepoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] vipm-build-vip: unable to resolve repo root (set repoRoot in request or XCLI_REPO_ROOT).");
            return new SimulationResult(false, 1);
        }

        var scriptPath = Path.Combine(repoRoot, "src", "tools", "icon-editor", "Invoke-VipmPackageBuildJob.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"[x-cli] vipm-build-vip: build job script not found at '{scriptPath}'.");
            return new SimulationResult(false, 1);
        }

        var workspace = ResolvePathOrDefault(request.Workspace, repoRoot);
        var releaseNotes = ResolvePathOrDefault(request.ReleaseNotesPath ?? "Tooling/deployment/release_notes.md", workspace);

        // Optional guard
        var guardScript = Path.Combine(repoRoot, "src", "tools", "icon-editor", "Test-VipbCustomActions.ps1");
        var vipbPath = Path.Combine(repoRoot, ".github", "actions", "build-vi-package", "NI_Icon_editor.vipb");
        if (File.Exists(guardScript))
        {
            if (!File.Exists(vipbPath))
            {
                Console.Error.WriteLine($"[x-cli] vipm-build-vip: VIPB not found at '{vipbPath}'.");
                return new SimulationResult(false, 1);
            }

            var guardArgs = new System.Collections.Generic.List<string>
            {
                "-VipbPath", vipbPath,
                "-Workspace", workspace
            };
            var guardResult = provider.RunPwshScript(new PwshScriptRequest(
                ScriptPath: guardScript,
                Arguments: guardArgs.ToArray(),
                WorkingDirectory: workspace,
                TimeoutSeconds: 0
            ));
            if (!string.IsNullOrEmpty(guardResult.StdOut)) Console.Write(guardResult.StdOut);
            if (!string.IsNullOrEmpty(guardResult.StdErr)) Console.Error.Write(guardResult.StdErr);
            if (!guardResult.Success)
            {
                Console.Error.WriteLine("[x-cli] vipm-build-vip: custom action guard failed.");
                return new SimulationResult(false, guardResult.ExitCode);
            }
        }

        var argsList = new System.Collections.Generic.List<string>
        {
            "-RepoRoot", repoRoot,
            "-Workspace", workspace,
            "-ReleaseNotesPath", releaseNotes
        };
        if (request.SkipReleaseNotes) argsList.Add("-SkipReleaseNotes");
        if (request.SkipVipbUpdate) argsList.Add("-SkipVipbUpdate");
        if (request.SkipBuild) argsList.Add("-SkipBuild");
        if (request.CloseLabVIEW) argsList.Add("-CloseLabVIEW");
        if (request.DownloadArtifacts) argsList.Add("-DownloadArtifacts");
        if (!string.IsNullOrWhiteSpace(request.BuildToolchain))
        {
            argsList.Add("-BuildToolchain"); argsList.Add(request.BuildToolchain!);
        }
        if (!string.IsNullOrWhiteSpace(request.BuildProvider))
        {
            argsList.Add("-BuildProvider"); argsList.Add(request.BuildProvider!);
        }
        if (!string.IsNullOrWhiteSpace(request.JobName))
        {
            argsList.Add("-JobName"); argsList.Add(request.JobName!);
        }
        if (!string.IsNullOrWhiteSpace(request.RunId))
        {
            argsList.Add("-RunId"); argsList.Add(request.RunId!);
        }
        if (!string.IsNullOrWhiteSpace(request.LogPath))
        {
            argsList.Add("-LogPath"); argsList.Add(request.LogPath!);
        }

        var runResult = provider.RunPwshScript(new PwshScriptRequest(
            ScriptPath: scriptPath,
            Arguments: argsList.ToArray(),
            WorkingDirectory: workspace,
            TimeoutSeconds: 0
        ));

        if (!string.IsNullOrWhiteSpace(runResult.StdOut))
            Console.Out.WriteLine(runResult.StdOut);
        if (!string.IsNullOrWhiteSpace(runResult.StdErr))
            Console.Error.WriteLine(runResult.StdErr);

        return new SimulationResult(runResult.Success, runResult.ExitCode);
    }

    private static string? ResolveRepoRoot(string? candidate)
    {
        var root = candidate;
        if (string.IsNullOrWhiteSpace(root))
            root = Environment.GetEnvironmentVariable("XCLI_REPO_ROOT");
        if (string.IsNullOrWhiteSpace(root))
            return null;
        try { return Path.GetFullPath(root); }
        catch { return null; }
    }

    private static string ResolvePathOrDefault(string? path, string defaultRoot)
    {
        if (string.IsNullOrWhiteSpace(path))
            return defaultRoot;
        return Path.GetFullPath(Path.IsPathRooted(path) ? path : Path.Combine(defaultRoot, path));
    }
}
