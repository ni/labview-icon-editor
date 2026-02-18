using System.Diagnostics;
using System.Xml.Linq;

namespace RunnerCli;

public sealed record LunitRunOptions(
    string RepoRoot,
    string Year,
    string LabviewVersion,
    string Bitness,
    string ProjectPath,
    string? ReportPath,
    bool VerboseGcli,
    bool SkipValidate,
    bool SkipValidateOnGcliFail,
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
    private const string CanonicalBackendMarker = "lunit execution backend: g-cli (canonical)";
    private const string ParseOnlyValidateMarker = "lunit validate mode: parse-only (RunUnitTests.ps1 -SkipGcli)";

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
        var reportPath = ResolveReportPath(repoRoot, options.ReportPath, options.Bitness);
        var legacyReportPath = ResolveLegacyReportPath(repoRoot);
        Console.WriteLine(CanonicalBackendMarker);

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
        if (!options.DryRun &&
            !PathEquals(reportPath, legacyReportPath) &&
            File.Exists(legacyReportPath))
        {
            try
            {
                File.Delete(legacyReportPath);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"WARNING: Failed to clear legacy LUnit report '{legacyReportPath}': {ex.Message}");
            }
        }

        var gcliExitCode = RunGcliLunit(
            repoRoot: repoRoot,
            year: options.Year,
            bitness: options.Bitness,
            projectPath: projectPath,
            reportPath: reportPath,
            verboseGcli: options.VerboseGcli,
            dryRun: options.DryRun);

        Console.WriteLine($"g-cli lunit exit code: {gcliExitCode}");
        if (!options.DryRun && File.Exists(reportPath))
        {
            // Ensure parse-only validation can deterministically inspect the legacy alias path.
            TryWriteLegacyReportAlias(reportPath, legacyReportPath, overwriteExisting: false);
        }
        if (!options.DryRun && ShouldRunClassFallback(primaryExitCode: gcliExitCode, projectPath: projectPath, reportPath: reportPath))
        {
            Console.Error.WriteLine("Primary g-cli lunit run returned nonzero with no testcase output for .lvproj; attempting class fallback under Test/Unit Tests.");
            var fallbackResult = RunClassFallback(
                repoRoot: repoRoot,
                year: options.Year,
                bitness: options.Bitness,
                reportPath: reportPath,
                verboseGcli: options.VerboseGcli);

            if (fallbackResult.Succeeded)
            {
                gcliExitCode = 0;
                Console.Error.WriteLine($"LUnit class fallback succeeded with {fallbackResult.TestcaseCount} testcase(s) merged into: {reportPath}");
                TryWriteLegacyReportAlias(reportPath, legacyReportPath, overwriteExisting: true);
            }
            else
            {
                Console.Error.WriteLine($"LUnit class fallback did not recover the run: {fallbackResult.Message}");
            }
        }

        if (options.SkipValidate)
        {
            Console.Error.WriteLine("Skipping parser validation because --skip-validate is set.");
            return gcliExitCode;
        }
        if (gcliExitCode != 0 && options.SkipValidateOnGcliFail)
        {
            Console.Error.WriteLine("Skipping parser validation because g-cli returned nonzero and --skip-validate-on-gcli-fail is set.");
            return gcliExitCode;
        }

        var parserExitCode = Validate(new LunitValidateOptions(
            RepoRoot: repoRoot,
            LabviewVersion: options.LabviewVersion,
            Bitness: options.Bitness,
            ReportPath: reportPath,
            DryRun: options.DryRun));

        if (!options.DryRun && File.Exists(reportPath))
        {
            TryWriteLegacyReportAlias(reportPath, legacyReportPath, overwriteExisting: false);
        }

        Console.WriteLine($"RunUnitTests parser exit code: {parserExitCode}");
        return gcliExitCode != 0 ? gcliExitCode : parserExitCode;
    }

    public static int Validate(LunitValidateOptions options)
    {
        ValidateCommonInputs(options.RepoRoot, options.Bitness, options.LabviewVersion);
        Console.WriteLine(ParseOnlyValidateMarker);

        var repoRoot = Path.GetFullPath(options.RepoRoot);
        var reportPath = ResolveReportPath(repoRoot, options.ReportPath, options.Bitness);
        if (string.IsNullOrWhiteSpace(options.ReportPath) && !options.DryRun && !File.Exists(reportPath))
        {
            var legacyReportPath = ResolveLegacyReportPath(repoRoot);
            if (File.Exists(legacyReportPath))
            {
                Console.Error.WriteLine($"lunit validate fallback report path: {legacyReportPath}");
                reportPath = legacyReportPath;
            }
        }

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
        bool verboseGcli,
        bool dryRun)
    {
        var args = new List<string>();
        if (verboseGcli)
        {
            args.Add("--verbose");
        }

        args.AddRange(new[]
        {
            "--lv-ver", year,
            "--arch", bitness,
            "lunit", "--",
            "-r", reportPath,
            projectPath
        });

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

    private static bool ShouldRunClassFallback(int primaryExitCode, string projectPath, string reportPath)
    {
        if (primaryExitCode == 0)
        {
            return false;
        }
        if (!string.Equals(Path.GetExtension(projectPath), ".lvproj", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return GetTestcaseCount(reportPath) == 0;
    }

    private static LunitClassFallbackResult RunClassFallback(
        string repoRoot,
        string year,
        string bitness,
        string reportPath,
        bool verboseGcli)
    {
        var classPaths = DiscoverUnitTestClassPaths(repoRoot);
        if (classPaths.Count == 0)
        {
            return new LunitClassFallbackResult(
                Succeeded: false,
                TestcaseCount: 0,
                Message: $"No .lvclass files were found under '{Path.Combine(repoRoot, "Test", "Unit Tests")}'.");
        }

        var reportDir = Path.GetDirectoryName(reportPath) ?? repoRoot;
        Directory.CreateDirectory(reportDir);
        var fallbackDir = Path.Combine(
            reportDir,
            $"lunit-fallback-{ResolveOsSegment()}-{bitness}-{DateTime.UtcNow:yyyyMMdd-HHmmss}");
        Directory.CreateDirectory(fallbackDir);

        var fallbackReports = new List<string>();
        for (var index = 0; index < classPaths.Count; index++)
        {
            var classPath = classPaths[index];
            var classReportPath = Path.Combine(fallbackDir, $"class-{index + 1:D2}.xml");

            var classExitCode = RunGcliLunit(
                repoRoot: repoRoot,
                year: year,
                bitness: bitness,
                projectPath: classPath,
                reportPath: classReportPath,
                verboseGcli: verboseGcli,
                dryRun: false);

            Console.Error.WriteLine($"lunit class fallback exit code ({Path.GetFileName(classPath)}): {classExitCode}");
            if (classExitCode != 0)
            {
                return new LunitClassFallbackResult(
                    Succeeded: false,
                    TestcaseCount: 0,
                    Message: $"g-cli returned {classExitCode} for class path '{classPath}'.");
            }

            var classTestcaseCount = GetTestcaseCount(classReportPath);
            if (classTestcaseCount == 0)
            {
                return new LunitClassFallbackResult(
                    Succeeded: false,
                    TestcaseCount: 0,
                    Message: $"Class report has no <testcase> entries: {classReportPath}");
            }

            fallbackReports.Add(classReportPath);
        }

        var mergeResult = MergeReports(reportPaths: fallbackReports, outputPath: reportPath);
        if (!mergeResult.Succeeded)
        {
            return mergeResult;
        }

        return new LunitClassFallbackResult(
            Succeeded: true,
            TestcaseCount: mergeResult.TestcaseCount,
            Message: $"Fallback reports merged from '{fallbackDir}'.");
    }

    private static List<string> DiscoverUnitTestClassPaths(string repoRoot)
    {
        var unitTestRoot = Path.Combine(repoRoot, "Test", "Unit Tests");
        if (!Directory.Exists(unitTestRoot))
        {
            return new List<string>();
        }

        return Directory.EnumerateFiles(unitTestRoot, "*.lvclass", SearchOption.AllDirectories)
            .OrderBy(path => path, OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal)
            .ToList();
    }

    private static int GetTestcaseCount(string reportPath)
    {
        if (!File.Exists(reportPath))
        {
            return 0;
        }

        try
        {
            var doc = XDocument.Load(reportPath, LoadOptions.None);
            return doc.Descendants("testcase").Count();
        }
        catch
        {
            return 0;
        }
    }

    private static LunitClassFallbackResult MergeReports(IReadOnlyList<string> reportPaths, string outputPath)
    {
        try
        {
            var testsuites = new XElement("testsuites");
            foreach (var reportPath in reportPaths)
            {
                if (!File.Exists(reportPath))
                {
                    return new LunitClassFallbackResult(
                        Succeeded: false,
                        TestcaseCount: 0,
                        Message: $"Fallback report missing: {reportPath}");
                }

                var doc = XDocument.Load(reportPath, LoadOptions.None);
                var root = doc.Root;
                if (root is null)
                {
                    continue;
                }

                if (string.Equals(root.Name.LocalName, "testsuite", StringComparison.Ordinal))
                {
                    testsuites.Add(new XElement(root));
                    continue;
                }

                foreach (var suite in root.Elements("testsuite"))
                {
                    testsuites.Add(new XElement(suite));
                }
            }

            var mergedDoc = new XDocument(new XDeclaration("1.0", "UTF-8", "no"), testsuites);
            var outputDir = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrWhiteSpace(outputDir))
            {
                Directory.CreateDirectory(outputDir);
            }
            mergedDoc.Save(outputPath);

            var testcaseCount = GetTestcaseCount(outputPath);
            if (testcaseCount == 0)
            {
                return new LunitClassFallbackResult(
                    Succeeded: false,
                    TestcaseCount: 0,
                    Message: $"Merged fallback report has no <testcase> entries: {outputPath}");
            }

            return new LunitClassFallbackResult(
                Succeeded: true,
                TestcaseCount: testcaseCount,
                Message: "Merged fallback reports.");
        }
        catch (Exception ex)
        {
            return new LunitClassFallbackResult(
                Succeeded: false,
                TestcaseCount: 0,
                Message: $"Failed to merge fallback reports: {ex.Message}");
        }
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

    private static string ResolveReportPath(string repoRoot, string? reportPath, string bitness)
    {
        var os = ResolveOsSegment();
        var value = string.IsNullOrWhiteSpace(reportPath)
            ? $".github/actions/run-unit-tests/UnitTestReport-{os}-{bitness}.xml"
            : reportPath!;
        return ResolvePath(repoRoot, value);
    }

    private static string ResolveLegacyReportPath(string repoRoot)
    {
        return ResolvePath(repoRoot, ".github/actions/run-unit-tests/UnitTestReport.xml");
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

    private static string ResolveOsSegment()
    {
        if (OperatingSystem.IsWindows())
        {
            return "Windows";
        }

        if (OperatingSystem.IsLinux())
        {
            return "Linux";
        }

        if (OperatingSystem.IsMacOS())
        {
            return "macOS";
        }

        return "Unknown";
    }

    private static void TryWriteLegacyReportAlias(string reportPath, string legacyReportPath, bool overwriteExisting)
    {
        if (PathEquals(reportPath, legacyReportPath))
        {
            return;
        }
        if (!File.Exists(reportPath))
        {
            return;
        }

        try
        {
            var legacyDir = Path.GetDirectoryName(legacyReportPath);
            if (!string.IsNullOrWhiteSpace(legacyDir))
            {
                Directory.CreateDirectory(legacyDir);
            }

            if (File.Exists(legacyReportPath) && !overwriteExisting)
            {
                Console.Error.WriteLine($"lunit run legacy report alias already exists: {legacyReportPath}");
                return;
            }

            File.Copy(reportPath, legacyReportPath, overwrite: overwriteExisting);
            Console.Error.WriteLine($"lunit run legacy report alias written: {legacyReportPath}");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"WARNING: Failed to write legacy LUnit report alias '{legacyReportPath}': {ex.Message}");
        }
    }

    private static bool PathEquals(string left, string right)
    {
        return string.Equals(
            Path.GetFullPath(left),
            Path.GetFullPath(right),
            OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal);
    }

    private sealed record LunitClassFallbackResult(bool Succeeded, int TestcaseCount, string Message);
}
