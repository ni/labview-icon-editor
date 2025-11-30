using System;
using System.IO;
using XCli.Labview.Providers;
using XCli.Simulation;

namespace XCli.ViAnalyzer;

public static class ViAnalyzerVerifyCommand
{
    public static SimulationResult Run(string[] args) => Run(args, LabviewProviderFactory.CreateDefault());

    public static SimulationResult Run(string[] args, ILabviewProvider provider)
    {
        string? labviewPath = null;
        string? labviewCliPath = null;

        for (var i = 0; i < args.Length; i++)
        {
            var arg = args[i];
            if (arg == "--labview-path" && i + 1 < args.Length)
            {
                labviewPath = args[++i];
            }
            else if (arg == "--labviewcli" && i + 1 < args.Length)
            {
                labviewCliPath = args[++i];
            }
            else
            {
                Console.Error.WriteLine($"[x-cli] vi-analyzer-verify: unknown argument '{arg}'.");
                return new SimulationResult(false, 1);
            }
        }

        if (string.IsNullOrWhiteSpace(labviewPath))
        {
            Console.Error.WriteLine("[x-cli] vi-analyzer-verify: --labview-path PATH is required.");
            return new SimulationResult(false, 1);
        }

        try
        {
            var resolvedLabviewPath = ResolveLabVIEWExecutable(labviewPath!);
            var resolvedCliPath = ResolveLabVIEWCliPath(labviewCliPath, resolvedLabviewPath);
            Console.WriteLine($"[x-cli] vi-analyzer-verify: LabVIEW executable found at '{resolvedLabviewPath}'.");
            Console.WriteLine($"[x-cli] vi-analyzer-verify: LabVIEWCLI.exe found at '{resolvedCliPath}'.");
            return new SimulationResult(true, 0);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[x-cli] vi-analyzer-verify: {ex.Message}");
            return new SimulationResult(false, 1);
        }
    }

    private static string ResolveLabVIEWExecutable(string candidate)
    {
        var fullPath = Path.GetFullPath(candidate);
        if (Directory.Exists(fullPath))
        {
            var exeCandidate = Path.Combine(fullPath, "LabVIEW.exe");
            if (!File.Exists(exeCandidate))
            {
                throw new FileNotFoundException($"LabVIEW.exe not found in '{fullPath}'.");
            }
            return exeCandidate;
        }

        if (!File.Exists(fullPath))
        {
            throw new FileNotFoundException($"LabVIEW path not found: '{fullPath}'.");
        }

        return fullPath;
    }

    private static string ResolveLabVIEWCliPath(string? explicitPath, string labviewExePath)
    {
        if (!string.IsNullOrWhiteSpace(explicitPath))
        {
            var cliPath = Path.GetFullPath(explicitPath);
            if (!File.Exists(cliPath))
            {
                throw new FileNotFoundException($"LabVIEWCLI.exe not found at '{cliPath}'.");
            }
            return cliPath;
        }

        var root = Path.GetDirectoryName(labviewExePath);
        if (string.IsNullOrWhiteSpace(root))
        {
            throw new InvalidOperationException("Unable to resolve LabVIEW installation root.");
        }

        var defaultCli = Path.Combine(root, "LabVIEWCLI.exe");
        if (!File.Exists(defaultCli))
        {
            throw new FileNotFoundException($"LabVIEWCLI.exe not found at '{defaultCli}'.");
        }
        return defaultCli;
    }
}
