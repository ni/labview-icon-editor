using System;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using XCli.Simulation;

namespace XCli.Vipm;

public static class VipmCliBuildCommand
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private sealed class BuildRequest
    {
        public string? RepoRoot { get; init; }
        public string? IconEditorRoot { get; init; }
        public string? RepoSlug { get; init; }
        public int? MinimumSupportedLVVersion { get; init; }
        public int? PackageMinimumSupportedLVVersion { get; init; }
        public int? PackageSupportedBitness { get; init; }
        public bool SkipSync { get; init; }
        public bool SkipVipcApply { get; init; }
        public bool SkipBuild { get; init; }
        public bool SkipRogueCheck { get; init; }
        public bool SkipClose { get; init; }
        public int? Major { get; init; }
        public int? Minor { get; init; }
        public int? Patch { get; init; }
        public int? Build { get; init; }
        public string? ResultsRoot { get; init; }
        public bool VerboseOutput { get; init; }
    }

    public static SimulationResult Run(string[] args)
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
                Console.Error.WriteLine($"[x-cli] vipmcli-build: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(requestPath))
        {
            Console.Error.WriteLine("[x-cli] vipmcli-build: --request PATH is required.");
            return new SimulationResult(false, 1);
        }

        requestPath = Path.GetFullPath(requestPath);
        if (!File.Exists(requestPath))
        {
            Console.Error.WriteLine($"[x-cli] vipmcli-build: request not found at '{requestPath}'.");
            return new SimulationResult(false, 1);
        }

        BuildRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<BuildRequest>(File.ReadAllText(requestPath), JsonOptions);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vipmcli-build: failed to parse request JSON: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        if (request == null)
        {
            Console.Error.WriteLine("[x-cli] vipmcli-build: empty request payload.");
            return new SimulationResult(false, 1);
        }

        var repoRoot = ResolveRepoRoot(request.RepoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] vipmcli-build: unable to resolve repo root.");
            return new SimulationResult(false, 1);
        }

        var scriptPath = Path.Combine(repoRoot, "src", "tools", "icon-editor", "Invoke-VipmCliBuild.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"[x-cli] vipmcli-build: script not found at '{scriptPath}'.");
            return new SimulationResult(false, 1);
        }

        var iconEditorRoot = string.IsNullOrWhiteSpace(request.IconEditorRoot)
            ? Path.Combine(repoRoot, "vendor", "icon-editor")
            : ResolvePath(request.IconEditorRoot!, repoRoot);

        var pwsh = Environment.GetEnvironmentVariable("XCLI_PWSH") ?? "pwsh";
        var psi = new ProcessStartInfo(pwsh)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        psi.ArgumentList.Add("-NoLogo");
        psi.ArgumentList.Add("-NoProfile");
        psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(scriptPath);
        psi.ArgumentList.Add("-RepoRoot");
        psi.ArgumentList.Add(repoRoot);
        psi.ArgumentList.Add("-IconEditorRoot");
        psi.ArgumentList.Add(iconEditorRoot);

        if (!string.IsNullOrWhiteSpace(request.RepoSlug))
        {
            psi.ArgumentList.Add("-RepoSlug");
            psi.ArgumentList.Add(request.RepoSlug!);
        }
        if (request.MinimumSupportedLVVersion.HasValue)
        {
            psi.ArgumentList.Add("-MinimumSupportedLVVersion");
            psi.ArgumentList.Add(request.MinimumSupportedLVVersion.Value.ToString());
        }
        if (request.PackageMinimumSupportedLVVersion.HasValue)
        {
            psi.ArgumentList.Add("-PackageMinimumSupportedLVVersion");
            psi.ArgumentList.Add(request.PackageMinimumSupportedLVVersion.Value.ToString());
        }
        if (request.PackageSupportedBitness.HasValue)
        {
            psi.ArgumentList.Add("-PackageSupportedBitness");
            psi.ArgumentList.Add(request.PackageSupportedBitness.Value.ToString());
        }
        if (request.SkipSync) psi.ArgumentList.Add("-SkipSync");
        if (request.SkipVipcApply) psi.ArgumentList.Add("-SkipVipcApply");
        if (request.SkipBuild) psi.ArgumentList.Add("-SkipBuild");
        if (request.SkipRogueCheck) psi.ArgumentList.Add("-SkipRogueCheck");
        if (request.SkipClose) psi.ArgumentList.Add("-SkipClose");

        if (request.Major.HasValue) { psi.ArgumentList.Add("-Major"); psi.ArgumentList.Add(request.Major.Value.ToString()); }
        if (request.Minor.HasValue) { psi.ArgumentList.Add("-Minor"); psi.ArgumentList.Add(request.Minor.Value.ToString()); }
        if (request.Patch.HasValue) { psi.ArgumentList.Add("-Patch"); psi.ArgumentList.Add(request.Patch.Value.ToString()); }
        if (request.Build.HasValue) { psi.ArgumentList.Add("-Build"); psi.ArgumentList.Add(request.Build.Value.ToString()); }

        if (!string.IsNullOrWhiteSpace(request.ResultsRoot))
        {
            psi.ArgumentList.Add("-ResultsRoot");
            psi.ArgumentList.Add(ResolvePath(request.ResultsRoot!, repoRoot));
        }
        if (request.VerboseOutput)
        {
            psi.ArgumentList.Add("-VerboseOutput");
        }

        using var process = Process.Start(psi);
        if (process == null)
        {
            Console.Error.WriteLine("[x-cli] vipmcli-build: failed to launch PowerShell process.");
            return new SimulationResult(false, 1);
        }

        var stdOut = process.StandardOutput.ReadToEnd();
        var stdErr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (!string.IsNullOrEmpty(stdOut)) Console.Write(stdOut);
        if (!string.IsNullOrEmpty(stdErr)) Console.Error.Write(stdErr);

        return new SimulationResult(process.ExitCode == 0, process.ExitCode);
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

    private static string ResolvePath(string path, string repoRoot)
    {
        return Path.GetFullPath(Path.IsPathRooted(path) ? path : Path.Combine(repoRoot, path));
    }
}
