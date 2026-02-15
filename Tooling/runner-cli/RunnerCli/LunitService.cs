using System.Diagnostics;

namespace RunnerCli;

public sealed record LunitRunOptions(
    string RepoRoot,
    string Year,
    string LabviewVersion,
    string Bitness,
    string ProjectPath,
    string? ReportPath,
    bool DryRun
);

public sealed record LunitValidateOptions(
    string RepoRoot,
    string LabviewVersion,
    string Bitness,
    string? ReportPath,
    bool DryRun
);

public static class LunitService
{
    public static int Run(LunitRunOptions options)
    {
        ValidateCommonInputs(options.RepoRoot, options.Bitness, options.LabviewVersion);

        if (string.IsNullOrWhiteSpace(options.Year))
        {
            throw new ArgumentException("Year is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.ProjectPath))
        {
            throw new ArgumentException("ProjectPath is required.", nameof(options));
        }

        var repoRoot = Path.GetFullPath(options.RepoRoot);
        var projectPath = ResolvePath(repoRoot, options.ProjectPath);
        var reportPath = ResolveReportPath(repoRoot, options.ReportPath);

        if (!options.DryRun && !File.Exists(projectPath))
        {
            Console.Error.WriteLine($"ERROR: LUnit project path not found: {projectPath}");
            return 1;
        }

        if (!options.DryRun && File.Exists(reportPath))
        {
            try
            {
                File.Delete(reportPath);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"ERROR: Failed to clear existing LUnit report '{reportPath}': {ex.Message}");
                return 1;
            }
        }

        var gcliExitCode = RunGcliLunit(
            repoRoot: repoRoot,
            year: options.Year,
            bitness: options.Bitness,
            projectPath: projectPath,
            reportPath: reportPath,
            dryRun: options.DryRun);

        Console.WriteLine($"g-cli lunit exit code: {gcliExitCode}");

        var parserExitCode = Validate(new LunitValidateOptions(
            RepoRoot: repoRoot,
            LabviewVersion: options.LabviewVersion,
            Bitness: options.Bitness,
            ReportPath: reportPath,
            DryRun: options.DryRun));

        Console.WriteLine($"RunUnitTests parser exit code: {parserExitCode}");
        return gcliExitCode != 0 ? gcliExitCode : parserExitCode;
    }

    public static int Validate(LunitValidateOptions options)
    {
        ValidateCommonInputs(options.RepoRoot, options.Bitness, options.LabviewVersion);

        var repoRoot = Path.GetFullPath(options.RepoRoot);
        var reportPath = ResolveReportPath(repoRoot, options.ReportPath);

        var parserArgs = new List<string>
        {
            "-LabVIEWVersion",
            options.LabviewVersion,
            "-SupportedBitness",
            options.Bitness,
            "-SkipGcli",
            "-ReportPath",
            reportPath
        };

        return PowerShellScriptRunner.Run(
            repoRoot: repoRoot,
            scriptRelativePath: ".github/actions/run-unit-tests/RunUnitTests.ps1",
            scriptArguments: parserArgs,
            commandLabel: "lunit validate",
            dryRun: options.DryRun);
    }

    private static int RunGcliLunit(
        string repoRoot,
        string year,
        string bitness,
        string projectPath,
        string reportPath,
        bool dryRun)
    {
        var args = new[]
        {
            "--lv-ver", year,
            "--arch", bitness,
            "lunit", "--",
            "-r", reportPath,
            projectPath
        };

        var commandLine = $"g-cli {string.Join(' ', args.Select(QuoteIfNeeded))}";
        Console.Error.WriteLine($"lunit run g-cli command: {commandLine}");
        if (dryRun)
        {
            return 0;
        }

        var psi = new ProcessStartInfo
        {
            FileName = "g-cli",
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
            Console.Error.WriteLine("ERROR: Failed to start g-cli for lunit run.");
            return 1;
        }

        process.WaitForExit();
        return process.ExitCode;
    }

    private static void ValidateCommonInputs(string repoRoot, string bitness, string labviewVersion)
    {
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            throw new ArgumentException("RepoRoot is required.", nameof(repoRoot));
        }
        if (string.IsNullOrWhiteSpace(labviewVersion))
        {
            throw new ArgumentException("LabviewVersion is required.", nameof(labviewVersion));
        }
        if (!string.Equals(bitness, "32", StringComparison.Ordinal) &&
            !string.Equals(bitness, "64", StringComparison.Ordinal))
        {
            throw new ArgumentException("Bitness must be 32 or 64.", nameof(bitness));
        }
    }

    private static string ResolveReportPath(string repoRoot, string? reportPath)
    {
        var value = string.IsNullOrWhiteSpace(reportPath)
            ? ".github/actions/run-unit-tests/UnitTestReport.xml"
            : reportPath!;
        return ResolvePath(repoRoot, value);
    }

    private static string ResolvePath(string repoRoot, string path)
    {
        if (Path.IsPathRooted(path))
        {
            return Path.GetFullPath(path);
        }

        return Path.GetFullPath(Path.Combine(repoRoot, path));
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
