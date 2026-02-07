using System.CommandLine;
using System.CommandLine.Invocation;
using System.Text;
using System.Text.Json;
using RunnerCli;

var contractPathOption = new Option<string>(
    name: "--contract-path",
    description: "Path to the runner contract JSON file.")
{ IsRequired = true };

var failOnSafeDirOption = new Option<bool>(
    name: "--fail-on-missing-safe-directory",
    getDefaultValue: () => true,
    description: "Fail if git safe.directory is not configured for the work root.");

// ── validate-contract ──────────────────────────────────────────────
var validateCmd = new Command("validate-contract", "Validates runner contract paths and safe.directory state.");
validateCmd.AddOption(contractPathOption);
validateCmd.AddOption(failOnSafeDirOption);
validateCmd.SetHandler((string path, bool failOnSafeDir) =>
{
    var contract = ContractService.Load(path);
    var errors = ContractService.Validate(contract);
    if (errors.Count > 0)
    {
        foreach (var e in errors)
            Console.Error.WriteLine($"ERROR: {e}");
        Environment.ExitCode = 1;
        return;
    }
    if (!ContractService.HasSafeDirectory(contract, out var safeMessage))
    {
        if (failOnSafeDir)
        {
            Console.Error.WriteLine($"ERROR: {safeMessage}");
            Environment.ExitCode = 1;
            return;
        }
        Console.Error.WriteLine($"WARNING: {safeMessage}");
    }
    Console.WriteLine($"Runner contract OK: {path}");
}, contractPathOption, failOnSafeDirOption);

// ── init-contract ──────────────────────────────────────────────────
var initContractPathOption = new Option<string>(
    name: "--contract-path",
    description: "Path to write the runner contract JSON file.")
{ IsRequired = true };

var runnerRootOption = new Option<string>("--runner-root", "Runner installation root.") { IsRequired = true };
var workRootOption = new Option<string>("--work-root", "Runner work root.") { IsRequired = true };
var runnerLabelOption = new Option<string>("--runner-label", getDefaultValue: () => "self-hosted-windows-lv", "Primary runner label.");
var canonicalLabelOption = new Option<string>("--canonical-label", getDefaultValue: () => "self-hosted-windows-lv", "Canonical runner label.");

var initCmd = new Command("init-contract", "Writes or refreshes the runner contract JSON.");
initCmd.AddOption(initContractPathOption);
initCmd.AddOption(runnerRootOption);
initCmd.AddOption(workRootOption);
initCmd.AddOption(runnerLabelOption);
initCmd.AddOption(canonicalLabelOption);
initCmd.SetHandler((string path, string runnerRoot, string workRoot, string label, string canonical) =>
{
    RunnerContract? existing = null;
    if (File.Exists(path))
    {
        try { existing = ContractService.Load(path); }
        catch (Exception ex) { Console.Error.WriteLine($"WARNING: Could not load existing contract: {ex.Message}"); }
    }

    var now = DateTime.UtcNow.ToString("o");
    var contract = new RunnerContract
    {
        Version = 1,
        RunnerRoot = runnerRoot,
        WorkRoot = workRoot,
        WorktreeRoot = Path.Combine(workRoot, "lvie", "w"),
        ArtifactRoot = Path.Combine(workRoot, "lvie", "artifacts"),
        LockRoot = Path.Combine(workRoot, "lvie", "locks"),
        LogRoot = Path.Combine(workRoot, "lvie", "logs"),
        RunnerLabel = label,
        RunnerLabels = ContractService.NormalizeLabels(new[] { label, canonical }),
        CanonicalRunnerLabel = canonical,
        UpdatedAtUtc = now,
        CreatedAtUtc = existing?.CreatedAtUtc ?? now
    };

    ContractService.Save(path, contract);
    Console.WriteLine($"Runner contract written: {path}");
}, initContractPathOption, runnerRootOption, workRootOption, runnerLabelOption, canonicalLabelOption);

// ── emit-env ───────────────────────────────────────────────────────
var emitContractPathOption = new Option<string>(
    name: "--contract-path",
    description: "Path to the runner contract JSON file.")
{ IsRequired = true };

var githubEnvOption = new Option<string>(
    name: "--github-env",
    description: "Path to the GITHUB_ENV file for exporting variables.");

var emitCmd = new Command("emit-env", "Writes LVIE_* variables to GITHUB_ENV.");
emitCmd.AddOption(emitContractPathOption);
emitCmd.AddOption(githubEnvOption);
emitCmd.SetHandler((string path, string? githubEnv) =>
{
    var contract = ContractService.Load(path);

    var envFile = githubEnv ?? Environment.GetEnvironmentVariable("GITHUB_ENV");
    if (string.IsNullOrWhiteSpace(envFile))
    {
        Console.Error.WriteLine("WARNING: GITHUB_ENV not set; printing to stdout only.");
    }

    var lines = new List<string>
    {
        $"LVIE_RUNNER_ROOT={contract.RunnerRoot}",
        $"LVIE_RUNNER_WORK_ROOT={contract.WorkRoot}",
        $"LVIE_WORKTREE_ROOT={contract.WorktreeRoot}",
        $"LVIE_ARTIFACT_ROOT={contract.ArtifactRoot}",
        $"LVIE_LOCK_ROOT={contract.LockRoot}",
        $"LVIE_LOG_ROOT={contract.LogRoot}",
        $"LVIE_RUNNER_CONTRACT_PATH={path}",
        $"LVIE_RUNNER_LABEL={contract.RunnerLabel}",
        $"LVIE_RUNNER_LABELS={string.Join(',', contract.RunnerLabels)}",
        $"LVIE_CANONICAL_RUNNER_LABEL={contract.CanonicalRunnerLabel}"
    };

    foreach (var line in lines)
        Console.WriteLine(line);

    if (!string.IsNullOrWhiteSpace(envFile))
    {
        File.AppendAllLines(envFile, lines);
        Console.WriteLine($"Exported {lines.Count} variables to {envFile}");
    }
}, emitContractPathOption, githubEnvOption);

// ── version-gate ───────────────────────────────────────────────────
var repoRootOption = new Option<string?>(
    name: "--repo-root",
    description: "Repository root (defaults to git root or current directory).");

var versionInputOption = new Option<string?>(
    name: "--version",
    description: "LabVIEW version input (year or numeric). When provided, must match .lvversion.");

var jsonOption = new Option<bool>(
    name: "--json",
    getDefaultValue: () => false,
    description: "Emit JSON output.");

var versionCmd = new Command("version-gate", "Validates .lvversion and optional version input.");
versionCmd.AddOption(repoRootOption);
versionCmd.AddOption(versionInputOption);
versionCmd.AddOption(jsonOption);
versionCmd.SetHandler((string? repoRoot, string? versionInput, bool json) =>
{
    try
    {
        var resolvedRoot = RepoLocator.Resolve(repoRoot, Environment.CurrentDirectory);
        var info = LabVIEWVersionService.GetVersionInfo(versionInput, resolvedRoot);

        if (json)
        {
            Console.WriteLine(JsonSerializer.Serialize(info, RunnerCliJsonContext.Default.LabVIEWVersionInfo));
        }
        else
        {
            Console.WriteLine($"raw={info.Raw}");
            Console.WriteLine($"year={info.Year}");
            Console.WriteLine($"minor={info.MinorRevision}");
            Console.WriteLine($"numeric={info.NumericVersion}");
        }
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
    }
}, repoRootOption, versionInputOption, jsonOption);

// ── pylavi scan ────────────────────────────────────────────────────
var pylaviCmd = new Command("pylavi", "Pylavi helpers for cross-platform parity.");
var pylaviScanCmd = new Command("scan", "Run vi_validate and write a top offenders report.");
var pylaviSummarizeCmd = new Command("summarize", "Summarize a pylavi offenders report.");
var pylaviFetchCmd = new Command("fetch", "Fetch pylavi offenders artifacts from CI.");

var configOption = new Option<string>(
    name: "--config",
    getDefaultValue: () => "Tooling/pylavi/vi-validate.yml",
    description: "Path to vi_validate config file (relative to repo root).");

var labelOption = new Option<string>(
    name: "--label",
    getDefaultValue: () => "pylavi",
    description: "Label used in warnings and reports.");

var labviewOption = new Option<string?>(
    name: "--labview",
    description: "LabVIEW version input (year or numeric). Defaults to .lvversion.");

var skipVersionGateOption = new Option<bool>(
    name: "--skip-version-gate",
    getDefaultValue: () => false,
    description: "Skip passing --eq to vi_validate.");

var reportOnlyOption = new Option<bool>(
    name: "--report-only",
    getDefaultValue: () => false,
    description: "Emit warnings but do not fail when vi_validate returns non-zero.");

var absoluteRootsOption = new Option<string?>(
    name: "--absolute-roots",
    description: "Semicolon-delimited absolute path roots to flag (optional).");

var logPathOption = new Option<string?>(
    name: "--log-path",
    description: "Optional path to write a redacted vi_validate log.");

var offendersPathOption = new Option<string?>(
    name: "--offenders-path",
    description: "Optional path to write the offenders JSON report.");

var quietOption = new Option<bool>(
    name: "--quiet",
    getDefaultValue: () => false,
    description: "Suppress warnings and summary output.");

pylaviScanCmd.AddOption(repoRootOption);
pylaviScanCmd.AddOption(configOption);
pylaviScanCmd.AddOption(labelOption);
pylaviScanCmd.AddOption(labviewOption);
pylaviScanCmd.AddOption(skipVersionGateOption);
pylaviScanCmd.AddOption(reportOnlyOption);
pylaviScanCmd.AddOption(absoluteRootsOption);
pylaviScanCmd.AddOption(logPathOption);
pylaviScanCmd.AddOption(offendersPathOption);
pylaviScanCmd.AddOption(jsonOption);
pylaviScanCmd.AddOption(quietOption);

pylaviScanCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        var config = context.ParseResult.GetValueForOption(configOption) ?? "Tooling/pylavi/vi-validate.yml";
        var label = context.ParseResult.GetValueForOption(labelOption) ?? "pylavi";
        var labview = context.ParseResult.GetValueForOption(labviewOption);
        var skipGate = context.ParseResult.GetValueForOption(skipVersionGateOption);
        var reportOnly = context.ParseResult.GetValueForOption(reportOnlyOption);
        var absoluteRoots = context.ParseResult.GetValueForOption(absoluteRootsOption);
        var logPath = context.ParseResult.GetValueForOption(logPathOption);
        var offendersPath = context.ParseResult.GetValueForOption(offendersPathOption);
        var json = context.ParseResult.GetValueForOption(jsonOption);
        var quiet = context.ParseResult.GetValueForOption(quietOption);

        var resolvedRoot = RepoLocator.Resolve(repoRoot, Environment.CurrentDirectory);
        var resolvedOffendersPath = offendersPath;
        if (string.IsNullOrWhiteSpace(resolvedOffendersPath))
        {
            resolvedOffendersPath = Path.Combine(resolvedRoot, "vi_validate_offenders.json");
        }

        var options = new PylaviScanOptions(
            resolvedRoot,
            config,
            label,
            labview,
            skipGate,
            reportOnly,
            absoluteRoots,
            logPath,
            resolvedOffendersPath,
            quiet,
            json
        );

        var result = PylaviService.Run(options);
        Environment.ExitCode = result.ExitCode;
        context.ExitCode = result.ExitCode;
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
        context.ExitCode = 1;
    }
});

pylaviSummarizeCmd.AddOption(repoRootOption);
var reportPathOption = new Option<string?>(
    name: "--path",
    description: "Optional path to the offenders report JSON.");
var summarizeLabelOption = new Option<string?>(
    name: "--label",
    description: "Label to resolve a label-specific report.");
var summarizeShaOption = new Option<string?>(
    name: "--sha",
    description: "Commit SHA to resolve a deterministic report.");
var topOption = new Option<int>(
    name: "--top",
    getDefaultValue: () => 10,
    description: "Maximum number of offenders to print.");
var outputPathOption = new Option<string?>(
    name: "--output-path",
    description: "Optional path to write a summary JSON for automation.");
var writeSummaryOption = new Option<bool>(
    name: "--write-summary",
    getDefaultValue: () => false,
    description: "Append a summary to GITHUB_STEP_SUMMARY.");
var validateExistsOption = new Option<bool>(
    name: "--validate-exists",
    getDefaultValue: () => false,
    description: "Only validate the report exists (exit 2 if missing).");
var failOnEmptyOption = new Option<bool>(
    name: "--fail-on-empty",
    getDefaultValue: () => false,
    description: "Exit non-zero if the report contains no entries.");
var failOnFindingsOption = new Option<bool>(
    name: "--fail-on-findings",
    getDefaultValue: () => false,
    description: "Exit non-zero if offender entries are present.");
var failOnThresholdOption = new Option<int>(
    name: "--fail-on-threshold",
    getDefaultValue: () => -1,
    description: "Exit non-zero if total FAILs exceed this threshold.");
var baselinePathOption = new Option<string?>(
    name: "--baseline",
    description: "Optional baseline offenders report to compute deltas.");
var baselineRequiredOption = new Option<bool>(
    name: "--baseline-required",
    getDefaultValue: () => false,
    description: "Exit non-zero if the baseline file is missing.");
var failOnDeltaOption = new Option<bool>(
    name: "--fail-on-delta",
    getDefaultValue: () => false,
    description: "Exit non-zero if new offenders are detected compared to the baseline.");

pylaviSummarizeCmd.AddOption(reportPathOption);
pylaviSummarizeCmd.AddOption(summarizeLabelOption);
pylaviSummarizeCmd.AddOption(summarizeShaOption);
pylaviSummarizeCmd.AddOption(topOption);
pylaviSummarizeCmd.AddOption(outputPathOption);
pylaviSummarizeCmd.AddOption(writeSummaryOption);
pylaviSummarizeCmd.AddOption(quietOption);
pylaviSummarizeCmd.AddOption(jsonOption);
pylaviSummarizeCmd.AddOption(validateExistsOption);
pylaviSummarizeCmd.AddOption(failOnEmptyOption);
pylaviSummarizeCmd.AddOption(failOnFindingsOption);
pylaviSummarizeCmd.AddOption(failOnThresholdOption);
pylaviSummarizeCmd.AddOption(baselinePathOption);
pylaviSummarizeCmd.AddOption(baselineRequiredOption);
pylaviSummarizeCmd.AddOption(failOnDeltaOption);

pylaviSummarizeCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        var path = context.ParseResult.GetValueForOption(reportPathOption);
        var label = context.ParseResult.GetValueForOption(summarizeLabelOption);
        var sha = context.ParseResult.GetValueForOption(summarizeShaOption);
        var top = context.ParseResult.GetValueForOption(topOption);
        var outputPath = context.ParseResult.GetValueForOption(outputPathOption);
        var writeSummary = context.ParseResult.GetValueForOption(writeSummaryOption);
        var quiet = context.ParseResult.GetValueForOption(quietOption);
        var json = context.ParseResult.GetValueForOption(jsonOption);
        var validateExists = context.ParseResult.GetValueForOption(validateExistsOption);
        var failOnEmpty = context.ParseResult.GetValueForOption(failOnEmptyOption);
        var failOnFindings = context.ParseResult.GetValueForOption(failOnFindingsOption);
        var failOnThreshold = context.ParseResult.GetValueForOption(failOnThresholdOption);
        var baselineInput = context.ParseResult.GetValueForOption(baselinePathOption);
        var baselineRequired = context.ParseResult.GetValueForOption(baselineRequiredOption);
        var failOnDelta = context.ParseResult.GetValueForOption(failOnDeltaOption);

        var resolvedRoot = RepoLocator.Resolve(repoRoot, Environment.CurrentDirectory);
        var resolvedPath = PylaviOffendersService.ResolveReportPath(resolvedRoot, path, label, sha);

        if (!File.Exists(resolvedPath))
        {
            var message = $"Pylavi offenders report not found at {resolvedPath}.";
            if (validateExists)
            {
                Console.Error.WriteLine($"ERROR: {message}");
                if (!json)
                {
                    var shaHint = PylaviOffendersService.ResolveSha(sha, resolvedPath, null);
                    var labelValueHint = string.IsNullOrWhiteSpace(label) ? "pylavi" : label;
                    PylaviOffendersService.WriteMachineLines(resolvedPath, labelValueHint, shaHint, false, 0, 2);
                }
                Environment.ExitCode = 2;
                context.ExitCode = 2;
                return;
            }
            throw new FileNotFoundException(message, resolvedPath);
        }

        if (validateExists)
        {
            if (!json)
            {
                var shaHint = PylaviOffendersService.ResolveSha(sha, resolvedPath, null);
                var labelValueHint = string.IsNullOrWhiteSpace(label) ? "pylavi" : label;
                PylaviOffendersService.WriteMachineLines(resolvedPath, labelValueHint, shaHint, false, 0, 0);
            }
            context.ExitCode = 0;
            return;
        }

        var report = PylaviOffendersService.LoadReport(resolvedPath);
        report.TopOffenders = PylaviOffendersService.SortOffenders(report.TopOffenders);
        report.TopAbsoluteOffenders = PylaviOffendersService.SortOffenders(report.TopAbsoluteOffenders);
        var labelValue = !string.IsNullOrWhiteSpace(report.Label) ? report.Label : (label ?? string.Empty);
        if (string.IsNullOrWhiteSpace(labelValue))
        {
            labelValue = "pylavi";
        }
        var shaValue = PylaviOffendersService.ResolveSha(sha, resolvedPath, report);
        var hasFindings = report.TotalFails > 0 || report.TopOffenders.Count > 0;

        var baselinePath = string.IsNullOrWhiteSpace(baselineInput)
            ? null
            : (Path.IsPathRooted(baselineInput) ? baselineInput : Path.Combine(resolvedRoot, baselineInput));
        var baselineMissing = false;
        PylaviOffendersReport? baselineReport = null;
        if (!string.IsNullOrWhiteSpace(baselinePath))
        {
            if (!File.Exists(baselinePath))
            {
                baselineMissing = true;
                Console.WriteLine($"WARNING: Baseline report not found at {baselinePath}.");
            }
            else
            {
                baselineReport = PylaviOffendersService.LoadReport(baselinePath);
            }
        }

        var deltaTotalFails = (int?)null;
        var deltaOffenders = (List<PylaviOffenderEntry>?)null;
        var deltaAbsolute = (List<PylaviOffenderEntry>?)null;
        var hasDelta = (bool?)null;
        if (baselineReport is not null)
        {
            deltaTotalFails = report.TotalFails - baselineReport.TotalFails;
            var baselineOffenders = new HashSet<string>(
                baselineReport.TopOffenders.Select(entry => entry.Item),
                StringComparer.OrdinalIgnoreCase);
            var baselineAbsolute = new HashSet<string>(
                baselineReport.TopAbsoluteOffenders.Select(entry => entry.Item),
                StringComparer.OrdinalIgnoreCase);

            deltaOffenders = report.TopOffenders
                .Where(entry => !baselineOffenders.Contains(entry.Item))
                .ToList();
            deltaAbsolute = report.TopAbsoluteOffenders
                .Where(entry => !baselineAbsolute.Contains(entry.Item))
                .ToList();
            deltaOffenders = PylaviOffendersService.SortOffenders(deltaOffenders);
            deltaAbsolute = PylaviOffendersService.SortOffenders(deltaAbsolute);

            hasDelta = (deltaTotalFails > 0)
                || (deltaOffenders.Count > 0)
                || (deltaAbsolute.Count > 0);
        }

        var exitCode = 0;
        string? exitMessage = null;
        if (baselineRequired && string.IsNullOrWhiteSpace(baselinePath))
        {
            exitCode = 7;
            exitMessage = "Baseline is required but no baseline path was provided.";
        }
        else if (baselineRequired && baselineMissing)
        {
            exitCode = 7;
            exitMessage = $"Baseline report not found at {baselinePath}.";
        }
        else if (failOnEmpty && !hasFindings)
        {
            exitCode = 3;
            exitMessage = "Pylavi offenders report contains no entries.";
        }
        else if (failOnThreshold >= 0 && report.TotalFails > failOnThreshold)
        {
            exitCode = 5;
            exitMessage = $"Pylavi offenders report exceeds threshold ({report.TotalFails} > {failOnThreshold}).";
        }
        else if (failOnFindings && hasFindings)
        {
            exitCode = 4;
            exitMessage = "Pylavi offenders report contains offender entries.";
        }
        else if (failOnDelta && hasDelta == true)
        {
            exitCode = 6;
            exitMessage = "Pylavi offenders report contains new entries compared to the baseline.";
        }

        if (!string.IsNullOrWhiteSpace(outputPath))
        {
            var summaryReport = new PylaviSummarizeOutput
            {
                Label = labelValue,
                GeneratedUtc = report.GeneratedUtc,
                TotalFails = report.TotalFails,
                ConfiguredRootCount = report.ConfiguredRootCount,
                HasFindings = hasFindings,
                File = resolvedPath,
                TopOffenders = report.TopOffenders.Take(top).ToList(),
                TopAbsoluteOffenders = report.TopAbsoluteOffenders.Take(top).ToList(),
                SourceSha = string.IsNullOrWhiteSpace(shaValue) ? null : shaValue,
                BaselineFile = baselinePath,
                BaselineTotalFails = baselineReport?.TotalFails,
                BaselineConfiguredRootCount = baselineReport?.ConfiguredRootCount,
                BaselineHasFindings = baselineReport is null ? null : (baselineReport.TotalFails > 0 || baselineReport.TopOffenders.Count > 0),
                HasDelta = hasDelta,
                DeltaTotalFails = deltaTotalFails,
                DeltaOffenders = deltaOffenders,
                DeltaAbsoluteOffenders = deltaAbsolute
            };

            var summaryDir = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrWhiteSpace(summaryDir) && !Directory.Exists(summaryDir))
            {
                Directory.CreateDirectory(summaryDir);
            }
            File.WriteAllText(outputPath, JsonSerializer.Serialize(summaryReport, RunnerCliJsonContext.Default.PylaviSummarizeOutput));
        }

        if (json)
        {
            if (!string.IsNullOrWhiteSpace(shaValue) && string.IsNullOrWhiteSpace(report.SourceSha))
            {
                report.SourceSha = shaValue;
            }
            Console.WriteLine(JsonSerializer.Serialize(report, RunnerCliJsonContext.Default.PylaviOffendersReport));
            if (exitCode != 0)
            {
                Console.Error.WriteLine($"ERROR: {exitMessage}");
                Environment.ExitCode = exitCode;
                context.ExitCode = exitCode;
            }
            return;
        }

        if (!quiet)
        {
            Console.WriteLine($"Label: {labelValue}");
            Console.WriteLine($"Generated (UTC): {report.GeneratedUtc}");
            Console.WriteLine($"Total FAILs: {report.TotalFails}");
            if (!string.IsNullOrWhiteSpace(shaValue))
            {
                Console.WriteLine($"Source SHA: {shaValue}");
            }
            Console.WriteLine($"Configured roots: <redacted> (count: {report.ConfiguredRootCount})");
            if (baselineReport is not null)
            {
                Console.WriteLine();
                Console.WriteLine($"Baseline file: {baselinePath}");
                Console.WriteLine($"Baseline FAILs: {baselineReport.TotalFails}");
                Console.WriteLine($"Baseline configured roots: <redacted> (count: {baselineReport.ConfiguredRootCount})");
                if (hasDelta == true)
                {
                    Console.WriteLine($"Delta FAILs: {deltaTotalFails}");
                    if (deltaOffenders is { Count: > 0 })
                    {
                        Console.WriteLine($"New offenders: {deltaOffenders.Count}");
                    }
                    if (deltaAbsolute is { Count: > 0 })
                    {
                        Console.WriteLine($"New absolute-path offenders: {deltaAbsolute.Count}");
                    }
                }
                else
                {
                    Console.WriteLine("Delta FAILs: 0");
                }
            }
            else if (!string.IsNullOrWhiteSpace(baselinePath))
            {
                Console.WriteLine();
                Console.WriteLine($"Baseline file: {baselinePath} (missing)");
            }

            if (report.TopOffenders.Count > 0)
            {
                Console.WriteLine();
                Console.WriteLine($"Top offenders (max {top}):");
                foreach (var entry in report.TopOffenders.Take(top))
                {
                    Console.WriteLine($"- {entry.Item} (count: {entry.Count})");
                }
            }

            if (report.TopAbsoluteOffenders.Count > 0)
            {
                Console.WriteLine();
                Console.WriteLine($"Top absolute-path offenders (max {top}):");
                foreach (var entry in report.TopAbsoluteOffenders.Take(top))
                {
                    Console.WriteLine($"- {entry.Item} (count: {entry.Count})");
                }
            }
        }

        var summaryPath = writeSummary ? Environment.GetEnvironmentVariable("GITHUB_STEP_SUMMARY") : null;
        PylaviOffendersService.WriteSummary(labelValue, report, top, shaValue, summaryPath);
        if (!string.IsNullOrWhiteSpace(summaryPath) && (baselineReport is not null || !string.IsNullOrWhiteSpace(baselinePath)))
        {
            var summaryLines = new List<string>
            {
                "### Pylavi Delta",
                ""
            };
            if (baselineReport is null)
            {
                summaryLines.Add($"- Baseline: {PylaviOffendersService.EscapeMarkdown(baselinePath ?? string.Empty)} (missing)");
            }
            else
            {
                summaryLines.Add($"- Baseline: {PylaviOffendersService.EscapeMarkdown(baselinePath ?? string.Empty)}");
                summaryLines.Add($"- Baseline FAILs: {baselineReport.TotalFails}");
                summaryLines.Add($"- Baseline configured roots: <redacted> (count: {baselineReport.ConfiguredRootCount})");
                summaryLines.Add($"- Delta FAILs: {deltaTotalFails}");
                summaryLines.Add($"- New offenders: {deltaOffenders?.Count ?? 0}");
                summaryLines.Add($"- New absolute-path offenders: {deltaAbsolute?.Count ?? 0}");
            }
            summaryLines.Add("");
            File.AppendAllLines(summaryPath, summaryLines, Encoding.UTF8);
        }

        PylaviOffendersService.WriteMachineLines(resolvedPath, labelValue, shaValue, hasFindings, report.TotalFails, exitCode);

        if (exitCode != 0)
        {
            Console.Error.WriteLine($"ERROR: {exitMessage}");
            Environment.ExitCode = exitCode;
            context.ExitCode = exitCode;
        }
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
        context.ExitCode = 1;
    }
});

pylaviFetchCmd.AddOption(repoRootOption);
var repoOption = new Option<string?>(
    name: "--repo",
    description: "GitHub repository (owner/name).");
var tokenOption = new Option<string?>(
    name: "--token",
    description: "GitHub token (or set GH_TOKEN/GITHUB_TOKEN).");
var workflowOption = new Option<string>(
    name: "--workflow",
    getDefaultValue: () => "ci-composite.yml",
    description: "Workflow file name to query.");
var branchOption = new Option<string?>(
    name: "--branch",
    getDefaultValue: () => "develop",
    description: "Branch name to query.");
var fetchShaOption = new Option<string?>(
    name: "--sha",
    description: "Commit SHA to fetch (deterministic).");
var runIdOption = new Option<long>(
    name: "--run-id",
    getDefaultValue: () => 0,
    description: "Workflow run id to fetch (deterministic).");
var fetchLabelOption = new Option<string?>(
    name: "--label",
    description: "Label suffix to fetch (e.g., strict).");
var artifactPrefixOption = new Option<string>(
    name: "--artifact-prefix",
    getDefaultValue: () => "pylavi-validate-offenders",
    description: "Artifact name prefix to match.");
var outDirOption = new Option<string>(
    name: "--out-dir",
    getDefaultValue: () => "TestResults/agent-logs",
    description: "Output directory for reports.");
var preferLabelOption = new Option<string>(
    name: "--prefer-label",
    getDefaultValue: () => "strict",
    description: "Preferred label for pylavi-offenders.latest.json.");

pylaviFetchCmd.AddOption(repoOption);
pylaviFetchCmd.AddOption(tokenOption);
pylaviFetchCmd.AddOption(workflowOption);
pylaviFetchCmd.AddOption(branchOption);
pylaviFetchCmd.AddOption(fetchShaOption);
pylaviFetchCmd.AddOption(runIdOption);
pylaviFetchCmd.AddOption(fetchLabelOption);
pylaviFetchCmd.AddOption(artifactPrefixOption);
pylaviFetchCmd.AddOption(outDirOption);
pylaviFetchCmd.AddOption(preferLabelOption);

pylaviFetchCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        var repo = context.ParseResult.GetValueForOption(repoOption);
        var token = context.ParseResult.GetValueForOption(tokenOption);
        var workflow = context.ParseResult.GetValueForOption(workflowOption) ?? "ci-composite.yml";
        var branch = context.ParseResult.GetValueForOption(branchOption);
        var sha = context.ParseResult.GetValueForOption(fetchShaOption);
        var runId = context.ParseResult.GetValueForOption(runIdOption);
        var label = context.ParseResult.GetValueForOption(fetchLabelOption);
        var artifactPrefix = context.ParseResult.GetValueForOption(artifactPrefixOption) ?? "pylavi-validate-offenders";
        var outDir = context.ParseResult.GetValueForOption(outDirOption) ?? "TestResults/agent-logs";
        var preferLabel = context.ParseResult.GetValueForOption(preferLabelOption) ?? "strict";

        var resolvedRoot = RepoLocator.Resolve(repoRoot, Environment.CurrentDirectory);
        var options = new PylaviFetchOptions(
            repo,
            token,
            workflow,
            sha,
            runId,
            branch,
            label,
            artifactPrefix,
            resolvedRoot,
            outDir,
            preferLabel
        );
        PylaviFetchService.Fetch(options);
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
        context.ExitCode = 1;
    }
});

pylaviCmd.AddCommand(pylaviScanCmd);
pylaviCmd.AddCommand(pylaviSummarizeCmd);
pylaviCmd.AddCommand(pylaviFetchCmd);

// ── missing-in-project ────────────────────────────────────────────
var missingCmd = new Command("missing-in-project", "Run missing-in-project check via g-cli.");
var missingArchOption = new Option<string>(
    name: "--arch",
    description: "LabVIEW bitness (32 or 64).")
{ IsRequired = true };
var missingProjectFileOption = new Option<string>(
    name: "--project-file",
    description: "Path to the .lvproj to inspect.")
{ IsRequired = true };
var missingLabviewOption = new Option<string?>(
    name: "--labview",
    description: "LabVIEW version input (year or numeric). Defaults to .lvversion.");
var missingWorktreeRootOption = new Option<string?>(
    name: "--worktree-root",
    description: "Optional worktree root override.");
var missingSkipWorktreeCheckOption = new Option<bool>(
    name: "--skip-worktree-root-check",
    getDefaultValue: () => false,
    description: "Skip worktree root validation.");
var missingConnectTimeoutOption = new Option<int>(
    name: "--connect-timeout-ms",
    getDefaultValue: () => 0,
    description: "Connect timeout override for g-cli (ms).");

missingCmd.AddOption(repoRootOption);
missingCmd.AddOption(missingArchOption);
missingCmd.AddOption(missingProjectFileOption);
missingCmd.AddOption(missingLabviewOption);
missingCmd.AddOption(missingWorktreeRootOption);
missingCmd.AddOption(missingSkipWorktreeCheckOption);
missingCmd.AddOption(missingConnectTimeoutOption);

missingCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        var arch = context.ParseResult.GetValueForOption(missingArchOption);
        var projectFile = context.ParseResult.GetValueForOption(missingProjectFileOption);
        var labviewInput = context.ParseResult.GetValueForOption(missingLabviewOption);
        var worktreeRoot = context.ParseResult.GetValueForOption(missingWorktreeRootOption);
        var skipWorktreeRootCheck = context.ParseResult.GetValueForOption(missingSkipWorktreeCheckOption);
        var connectTimeoutMs = context.ParseResult.GetValueForOption(missingConnectTimeoutOption);

        if (string.IsNullOrWhiteSpace(arch))
        {
            Console.Error.WriteLine("ERROR: --arch is required.");
            Environment.ExitCode = 1;
            context.ExitCode = 1;
            return;
        }
        if (string.IsNullOrWhiteSpace(projectFile))
        {
            Console.Error.WriteLine("ERROR: --project-file is required.");
            Environment.ExitCode = 1;
            context.ExitCode = 1;
            return;
        }

        var resolvedRoot = RepoLocator.Resolve(repoRoot, Environment.CurrentDirectory);
        var options = new MissingInProjectOptions(
            resolvedRoot,
            arch,
            projectFile,
            labviewInput,
            worktreeRoot,
            skipWorktreeRootCheck,
            connectTimeoutMs > 0 ? connectTimeoutMs : null
        );

        var exitCode = MissingInProjectService.Run(options);
        Environment.ExitCode = exitCode;
        context.ExitCode = exitCode;
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
        context.ExitCode = 1;
    }
});

// ── manifest ──────────────────────────────────────────────────────
var manifestCmd = new Command("manifest", "Emit runner-cli capability and spec metadata.");
manifestCmd.AddOption(repoRootOption);
manifestCmd.AddOption(jsonOption);
manifestCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        _ = RepoLocator.Resolve(repoRoot, Environment.CurrentDirectory);
        var manifest = ConformanceService.BuildManifest();

        if (context.ParseResult.GetValueForOption(jsonOption))
        {
            Console.WriteLine(JsonSerializer.Serialize(manifest, RunnerCliJsonContext.Default.RunnerCliManifest));
        }
        else
        {
            Console.WriteLine($"spec_document_id={manifest.SpecDocumentId}");
            Console.WriteLine($"spec_version={manifest.SpecVersion}");
            Console.WriteLine($"build_version={manifest.BuildVersion}");
            Console.WriteLine($"generated_utc={manifest.GeneratedUtc}");
            Console.WriteLine($"supported_profiles={string.Join(',', manifest.SupportedProfiles)}");
            Console.WriteLine($"supported_commands={string.Join(',', manifest.SupportedCommands)}");
        }
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
        context.ExitCode = 1;
    }
});

// ── conformance check ─────────────────────────────────────────────
var conformanceCmd = new Command("conformance", "Conformance profile checks.");
var conformanceCheckCmd = new Command("check", "Evaluate profile-scoped conformance checks.");
var profileOption = new Option<string?>(
    name: "--profile",
    description: "Conformance profile to evaluate (core|extended|full).");
var strictOption = new Option<bool>(
    name: "--strict",
    getDefaultValue: () => false,
    description: "Treat warning checks as failures.");
conformanceCheckCmd.AddOption(profileOption);
conformanceCheckCmd.AddOption(repoRootOption);
conformanceCheckCmd.AddOption(jsonOption);
conformanceCheckCmd.AddOption(strictOption);
conformanceCheckCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        _ = RepoLocator.Resolve(repoRoot, Environment.CurrentDirectory);

        var profileOptionValue = context.ParseResult.GetValueForOption(profileOption);
        var strictProvided = context.ParseResult.Tokens.Any(token =>
            string.Equals(token.Value, "--strict", StringComparison.OrdinalIgnoreCase));
        var strictOverride = strictProvided ? context.ParseResult.GetValueForOption(strictOption) : (bool?)null;
        var strict = ConformanceService.ResolveStrict(strictOverride);
        var profile = ConformanceService.ResolveProfile(profileOptionValue);

        var result = ConformanceService.Run(
            profile,
            strict,
            Environment.GetEnvironmentVariable("RC_HOSTED_LINUX_EVIDENCE"),
            Environment.GetEnvironmentVariable("RC_HOSTED_WINDOWS_EVIDENCE"));

        var exitCode = ConformanceService.ResolveExitCode(result, strict);
        if (context.ParseResult.GetValueForOption(jsonOption))
        {
            Console.WriteLine(JsonSerializer.Serialize(result, RunnerCliJsonContext.Default.ConformanceCheckResult));
        }
        else
        {
            Console.WriteLine($"profile={result.Profile}");
            Console.WriteLine($"generated_utc={result.GeneratedUtc}");
            Console.WriteLine($"total={result.Summary.Total}");
            Console.WriteLine($"pass={result.Summary.Pass}");
            Console.WriteLine($"warn={result.Summary.Warn}");
            Console.WriteLine($"fail={result.Summary.Fail}");
            foreach (var check in result.Checks)
            {
                Console.WriteLine($"- [{check.Status}] {check.Id}: {check.Message}");
                Console.WriteLine($"  evidence={check.Evidence}");
            }
        }

        Environment.ExitCode = exitCode;
        context.ExitCode = exitCode;
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
        context.ExitCode = 1;
    }
});
conformanceCmd.AddCommand(conformanceCheckCmd);

// ── root ───────────────────────────────────────────────────────────
var rootCmd = new RootCommand("LVIE Runner CLI – contract and parity helpers for stateless runners.");
rootCmd.AddCommand(validateCmd);
rootCmd.AddCommand(initCmd);
rootCmd.AddCommand(emitCmd);
rootCmd.AddCommand(versionCmd);
rootCmd.AddCommand(pylaviCmd);
rootCmd.AddCommand(missingCmd);
rootCmd.AddCommand(manifestCmd);
rootCmd.AddCommand(conformanceCmd);

return await rootCmd.InvokeAsync(args);
