using System.Diagnostics;
using System.Text;

internal static class Program
{
    private static readonly string[] Subcommands =
    {
        "devmode-bind", "devmode-unbind", "labview-close", "apply-deps", "restore-sources",
        "vi-analyzer", "vi-compare", "vi-compare-preflight", "missing-check", "unit-tests",
        "vipm-verify", "vipm-install", "package-build", "local-sd", "sd-ppl-lvcli",
        "source-dist-verify", "ollama",
        "devmode-agent"
    };

    private static int Main(string[] args)
    {
        if (args.Length == 0 || args.Any(IsHelp))
        {
            PrintUsage();
            return 0;
        }

        var repoPath = FindRepoPath(args) ?? Directory.GetCurrentDirectory();
        var dispatch = ResolveTarget(repoPath, args);
        if (dispatch == null) return 1;

        var psi = new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = BuildArguments(dispatch.Value.ProjectPath, dispatch.Value.ForwardArgs),
            WorkingDirectory = repoPath,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        using var proc = Process.Start(psi);
        if (proc == null)
        {
            Console.Error.WriteLine("Failed to start OrchestrationCli process.");
            return 1;
        }

        proc.OutputDataReceived += (_, e) => { if (e.Data != null) Console.WriteLine(e.Data); };
        proc.ErrorDataReceived += (_, e) => { if (e.Data != null) Console.Error.WriteLine(e.Data); };
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();
        proc.WaitForExit();
        return proc.ExitCode;
    }

    private static (string ProjectPath, string[] ForwardArgs)? ResolveTarget(string repoPath, string[] args)
    {
        var first = args[0];
        if (string.Equals(first, "devmode-agent", StringComparison.OrdinalIgnoreCase))
        {
            var proj = Path.Combine(repoPath, "Tooling", "dotnet", "DevModeAgentCli", "DevModeAgentCli.csproj");
            if (!File.Exists(proj))
            {
                Console.Error.WriteLine($"DevModeAgentCli project not found at {proj}");
                return null;
            }
            return (proj, args.Skip(1).ToArray());
        }

        var orchProj = Path.Combine(repoPath, "Tooling", "dotnet", "OrchestrationCli", "OrchestrationCli.csproj");
        if (!File.Exists(orchProj))
        {
            Console.Error.WriteLine($"OrchestrationCli project not found at {orchProj}");
            return null;
        }
        return (orchProj, args);
    }

    private static string BuildArguments(string projPath, string[] args)
    {
        var sb = new StringBuilder();
        sb.Append("run --project ");
        sb.Append(Escape(projPath));
        sb.Append(" -- ");
        for (int i = 0; i < args.Length; i++)
        {
            if (i > 0) sb.Append(' ');
            sb.Append(Escape(args[i]));
        }
        return sb.ToString();
    }

    private static string Escape(string value)
    {
        if (string.IsNullOrEmpty(value)) return "\"\"";
        if (value.IndexOfAny(new[] { ' ', '\t', '\"' }) < 0) return value;
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static bool IsHelp(string arg)
    {
        var a = arg.ToLowerInvariant();
        return a == "-h" || a == "--help" || a == "/?";
    }

    private static string? FindRepoPath(string[] args)
    {
        for (int i = 0; i < args.Length - 1; i++)
        {
            if (args[i].Equals("--repo", StringComparison.OrdinalIgnoreCase) ||
                args[i].Equals("-repo", StringComparison.OrdinalIgnoreCase))
            {
                return args[i + 1];
            }
        }
        return null;
    }

    private static void PrintUsage()
    {
        Console.WriteLine("OrchestrationCompatCli (pass-through to OrchestrationCli)");
        Console.WriteLine("Usage:");
        Console.WriteLine("  OrchestrationCompatCli <subcommand> [options]");
        Console.WriteLine("Subcommands:");
        Console.WriteLine("  " + string.Join(", ", Subcommands));
        Console.WriteLine("Notes:");
        Console.WriteLine("  - All arguments are forwarded to OrchestrationCli unless subcommand is devmode-agent (for DevModeAgentCli).");
        Console.WriteLine("  - Use --repo <path> to set the repository root (defaults to current directory).");
    }
}
