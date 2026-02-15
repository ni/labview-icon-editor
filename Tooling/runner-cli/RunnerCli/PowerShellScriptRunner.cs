using System.Diagnostics;

namespace RunnerCli;

internal static class PowerShellScriptRunner
{
    public static int Run(
        string repoRoot,
        string scriptRelativePath,
        IReadOnlyList<string> scriptArguments,
        string commandLabel,
        bool dryRun)
    {
        var resolvedRepoRoot = Path.GetFullPath(repoRoot);
        var relativeParts = scriptRelativePath
            .Split(new[] { '/', '\\' }, StringSplitOptions.RemoveEmptyEntries);
        var scriptPath = Path.Combine(new[] { resolvedRepoRoot }.Concat(relativeParts).ToArray());

        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine($"ERROR: {commandLabel} script not found: {scriptPath}");
            return 1;
        }

        var args = new List<string>
        {
            "-NoProfile",
            "-File",
            scriptPath
        };
        args.AddRange(scriptArguments);

        var commandLine = $"pwsh {string.Join(' ', args.Select(QuoteIfNeeded))}";
        Console.Error.WriteLine($"{commandLabel} command: {commandLine}");

        if (dryRun)
        {
            return 0;
        }

        var psi = new ProcessStartInfo
        {
            FileName = "pwsh",
            WorkingDirectory = resolvedRepoRoot,
            UseShellExecute = false
        };

        foreach (var arg in args)
        {
            psi.ArgumentList.Add(arg);
        }

        using var process = Process.Start(psi);
        if (process is null)
        {
            Console.Error.WriteLine($"ERROR: Failed to start pwsh for {commandLabel}.");
            return 1;
        }

        process.WaitForExit();
        return process.ExitCode;
    }

    private static string QuoteIfNeeded(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "\"\"";
        }

        return value.Contains(' ', StringComparison.Ordinal)
            ? $"\"{value}\""
            : value;
    }
}
