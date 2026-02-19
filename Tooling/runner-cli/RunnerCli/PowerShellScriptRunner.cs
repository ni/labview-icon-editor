using System.Diagnostics;

namespace RunnerCli;

internal static class PowerShellScriptRunner
{
    private static readonly HashSet<string> AllowedExecutionPolicies = new(StringComparer.OrdinalIgnoreCase)
    {
        "RemoteSigned",
        "AllSigned",
        "Restricted",
        "Undefined",
        "Default"
    };

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
        ValidateExecutionPolicyArgs(args, commandLabel);

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

    private static void ValidateExecutionPolicyArgs(IReadOnlyList<string> args, string commandLabel)
    {
        for (var i = 0; i < args.Count; i++)
        {
            if (!string.Equals(args[i], "-ExecutionPolicy", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (i + 1 >= args.Count)
            {
                throw new InvalidOperationException($"{commandLabel} command includes an execution policy switch without a value.");
            }

            var value = args[i + 1];
            if (!AllowedExecutionPolicies.Contains(value))
            {
                throw new InvalidOperationException(
                    $"{commandLabel} command includes non-allowlisted execution policy value '{value}'.");
            }
        }
    }
}
