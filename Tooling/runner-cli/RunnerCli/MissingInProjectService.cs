using System.Diagnostics;

namespace RunnerCli;

public sealed record MissingInProjectOptions(
    string RepoRoot,
    string Arch,
    string ProjectFile,
    string? LabviewInput,
    string? WorktreeRoot,
    bool SkipWorktreeRootCheck,
    int? ConnectTimeoutMs
);

public static class MissingInProjectService
{
    public static int Run(MissingInProjectOptions options)
    {
        if (!OperatingSystem.IsWindows())
        {
            Console.Error.WriteLine("ERROR: missing-in-project is only supported on Windows.");
            return 1;
        }

        if (string.IsNullOrWhiteSpace(options.RepoRoot))
        {
            throw new ArgumentException("RepoRoot is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.Arch))
        {
            throw new ArgumentException("Arch is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.ProjectFile))
        {
            throw new ArgumentException("Project file is required.", nameof(options));
        }

        var repoRoot = Path.GetFullPath(options.RepoRoot);
        var scriptPath = Path.Combine(repoRoot, ".github", "actions", "missing-in-project", "Invoke-MissingInProjectCLI.ps1");
        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"ERROR: missing-in-project script not found: {scriptPath}");
            return 1;
        }

        var projectFile = options.ProjectFile;
        if (!Path.IsPathRooted(projectFile))
        {
            projectFile = Path.Combine(repoRoot, projectFile);
        }

        var args = new List<string>
        {
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", scriptPath,
            "-Arch", options.Arch,
            "-ProjectFile", projectFile
        };

        if (!string.IsNullOrWhiteSpace(options.LabviewInput))
        {
            args.Add("-LVVersion");
            args.Add(options.LabviewInput!);
        }

        if (!string.IsNullOrWhiteSpace(options.WorktreeRoot))
        {
            args.Add("-WorktreeRoot");
            args.Add(options.WorktreeRoot!);
        }

        if (options.SkipWorktreeRootCheck)
        {
            args.Add("-SkipWorktreeRootCheck");
        }

        if (options.ConnectTimeoutMs.HasValue && options.ConnectTimeoutMs.Value > 0)
        {
            args.Add("-ConnectTimeoutMs");
            args.Add(options.ConnectTimeoutMs.Value.ToString());
        }

        var commandLine = $"pwsh {string.Join(' ', args.Select(QuoteIfNeeded))}";
        Console.Error.WriteLine($"missing-in-project command: {commandLine}");

        var psi = new ProcessStartInfo
        {
            FileName = "pwsh",
            WorkingDirectory = repoRoot,
            UseShellExecute = false
        };
        foreach (var arg in args)
        {
            psi.ArgumentList.Add(arg);
        }

        using var process = Process.Start(psi);
        if (process is null)
        {
            Console.Error.WriteLine("ERROR: Failed to start pwsh for missing-in-project.");
            return 1;
        }

        process.WaitForExit();
        return process.ExitCode;
    }

    private static string QuoteIfNeeded(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return "\"\"";
        return value.Contains(' ') ? $"\"{value}\"" : value;
    }
}
