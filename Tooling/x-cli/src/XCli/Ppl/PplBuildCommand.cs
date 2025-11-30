using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using XCli.Simulation;

namespace XCli.Ppl;

public static class PplBuildCommand
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private sealed class BuildRequest
    {
        public string? RepoRoot { get; init; }
        public string? IconEditorRoot { get; init; }
        public int? MinimumSupportedLVVersion { get; init; }
        public int? Major { get; init; }
        public int? Minor { get; init; }
        public int? Patch { get; init; }
        public int? Build { get; init; }
        public string? Commit { get; init; }
        public string[]? BitnessTargets { get; init; }
    }

    private sealed record BuildResult(string Bitness, int ExitCode, string StdOut, string StdErr);

    private sealed class CommandResult
    {
        public string Schema { get; init; } = "icon-editor/ppl-build@v1";
        public string IconEditorRoot { get; init; } = string.Empty;
        public BuildResult[] Runs { get; init; } = Array.Empty<BuildResult>();
        public bool Success { get; init; }
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
                Console.Error.WriteLine($"[x-cli] ppl-build: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(requestPath))
        {
            Console.Error.WriteLine("[x-cli] ppl-build: --request PATH is required.");
            return new SimulationResult(false, 1);
        }

        requestPath = Path.GetFullPath(requestPath);
        if (!File.Exists(requestPath))
        {
            Console.Error.WriteLine($"[x-cli] ppl-build: request file not found at '{requestPath}'.");
            return new SimulationResult(false, 1);
        }

        BuildRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<BuildRequest>(File.ReadAllText(requestPath), JsonOptions);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] ppl-build: failed to parse request JSON: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        if (request == null)
        {
            Console.Error.WriteLine("[x-cli] ppl-build: empty request payload.");
            return new SimulationResult(false, 1);
        }

        var repoRoot = ResolveRepoRoot(request.RepoRoot);
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            Console.Error.WriteLine("[x-cli] ppl-build: unable to resolve repo root.");
            return new SimulationResult(false, 1);
        }

        string iconEditorRoot;
        try
        {
            iconEditorRoot = ResolveIconEditorRoot(repoRoot, request.IconEditorRoot);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] ppl-build: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        if (!Directory.Exists(iconEditorRoot))
        {
            Console.Error.WriteLine($"[x-cli] ppl-build: IconEditorRoot '{iconEditorRoot}' not found.");
            return new SimulationResult(false, 1);
        }

        // Use canonical script under scripts/build-lvlibp.
        var scriptPath = Path.Combine(iconEditorRoot, "scripts", "build-lvlibp", "Build_lvlibp.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"[x-cli] ppl-build: Build_lvlibp.ps1 not found at '{scriptPath}'.");
            return new SimulationResult(false, 1);
        }

        var bitnessTargets = request.BitnessTargets is { Length: > 0 }
            ? request.BitnessTargets!
            : new[] { "32", "64" };

        var runs = new List<BuildResult>();
        var pwsh = Environment.GetEnvironmentVariable("XCLI_PWSH") ?? "pwsh";
        foreach (var target in bitnessTargets)
        {
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

            if (request.MinimumSupportedLVVersion.HasValue)
            {
                psi.ArgumentList.Add("-MinimumSupportedLVVersion");
                psi.ArgumentList.Add(request.MinimumSupportedLVVersion.Value.ToString());
            }
            psi.ArgumentList.Add("-SupportedBitness");
            psi.ArgumentList.Add(target);
            psi.ArgumentList.Add("-IconEditorRoot");
            psi.ArgumentList.Add(iconEditorRoot);
            if (request.Major.HasValue) { psi.ArgumentList.Add("-Major"); psi.ArgumentList.Add(request.Major.Value.ToString()); }
            if (request.Minor.HasValue) { psi.ArgumentList.Add("-Minor"); psi.ArgumentList.Add(request.Minor.Value.ToString()); }
            if (request.Patch.HasValue) { psi.ArgumentList.Add("-Patch"); psi.ArgumentList.Add(request.Patch.Value.ToString()); }
            if (request.Build.HasValue) { psi.ArgumentList.Add("-Build"); psi.ArgumentList.Add(request.Build.Value.ToString()); }
            if (!string.IsNullOrWhiteSpace(request.Commit))
            {
                psi.ArgumentList.Add("-Commit");
                psi.ArgumentList.Add(request.Commit!);
            }

            using var process = Process.Start(psi);
            if (process == null)
            {
                Console.Error.WriteLine($"[x-cli] ppl-build: failed to launch PowerShell for bitness {target}.");
                return new SimulationResult(false, 1);
            }

            var stdOut = process.StandardOutput.ReadToEnd();
            var stdErr = process.StandardError.ReadToEnd();
            process.WaitForExit();

            if (!string.IsNullOrEmpty(stdOut)) Console.Write(stdOut);
            if (!string.IsNullOrEmpty(stdErr)) Console.Error.Write(stdErr);

            runs.Add(new BuildResult(target, process.ExitCode, stdOut, stdErr));
        }

        var success = runs.TrueForAll(r => r.ExitCode == 0);
        var response = new CommandResult
        {
            IconEditorRoot = iconEditorRoot,
            Runs = runs.ToArray(),
            Success = success
        };
        Console.WriteLine(JsonSerializer.Serialize(response, new JsonSerializerOptions { WriteIndented = true }));
        return new SimulationResult(success, success ? 0 : 1);
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

    private static string ResolveIconEditorRoot(string repoRoot, string? overridePath)
    {
        if (!string.IsNullOrWhiteSpace(overridePath))
        {
            var resolvedOverride = ResolvePath(overridePath!, repoRoot);
            if (Directory.Exists(resolvedOverride))
            {
                return resolvedOverride;
            }
            throw new InvalidOperationException($"IconEditorRoot override '{resolvedOverride}' not found.");
        }

        var configPath = Path.Combine(repoRoot, "configs", "icon-editor-vendor.json");
        if (File.Exists(configPath))
        {
            try
            {
                using var doc = JsonDocument.Parse(File.ReadAllText(configPath));
                if (doc.RootElement.TryGetProperty("vendorRoot", out var prop) && prop.ValueKind == JsonValueKind.String)
                {
                    var raw = prop.GetString();
                    if (!string.IsNullOrWhiteSpace(raw))
                    {
                        var expanded = ExpandWorkspacePlaceholder(raw!, repoRoot);
                        if (Directory.Exists(expanded))
                        {
                            return expanded;
                        }
                        Console.Error.WriteLine($"[x-cli] ppl-build: vendorRoot '{expanded}' from config not found.");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[x-cli] ppl-build: failed to read icon-editor vendor config: {ex.Message}");
            }
        }

        var fallback = FindVendorRootByScan(repoRoot);
        if (!string.IsNullOrWhiteSpace(fallback))
        {
            return fallback!;
        }

        throw new InvalidOperationException("Unable to resolve icon editor vendor root. Update configs/icon-editor-vendor.json or vendor the LabVIEW icon editor repo.");
    }

    private static string ExpandWorkspacePlaceholder(string path, string repoRoot)
    {
        var expanded = path.Replace("${workspaceFolder}", repoRoot, StringComparison.OrdinalIgnoreCase);
        return Path.GetFullPath(Path.IsPathRooted(expanded) ? expanded : Path.Combine(repoRoot, expanded));
    }

    private static string? FindVendorRootByScan(string repoRoot)
    {
        var vendorDir = Path.Combine(repoRoot, "vendor");
        if (!Directory.Exists(vendorDir)) { return null; }
        foreach (var dir in Directory.GetDirectories(vendorDir))
        {
            var vipbPath = Path.Combine(dir, "Tooling", "deployment", "NI_Icon_editor.vipb");
            if (File.Exists(vipbPath))
            {
                return dir;
            }
        }
        return null;
    }
}
