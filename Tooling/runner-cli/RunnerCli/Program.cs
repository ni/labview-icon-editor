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
    getDefaultValue: () => "ci.yml",
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
        var workflow = context.ParseResult.GetValueForOption(workflowOption) ?? "ci.yml";
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
var missingDryRunOption = new Option<bool>(
    name: "--dry-run",
    getDefaultValue: () => false,
    description: "Emit the command line and exit without invoking the script.");

missingCmd.AddOption(repoRootOption);
missingCmd.AddOption(missingArchOption);
missingCmd.AddOption(missingProjectFileOption);
missingCmd.AddOption(missingLabviewOption);
missingCmd.AddOption(missingWorktreeRootOption);
missingCmd.AddOption(missingSkipWorktreeCheckOption);
missingCmd.AddOption(missingConnectTimeoutOption);
missingCmd.AddOption(missingDryRunOption);

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
        var dryRun = context.ParseResult.GetValueForOption(missingDryRunOption);

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
            connectTimeoutMs > 0 ? connectTimeoutMs : null,
            dryRun
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

// ── lunit run/validate ────────────────────────────────────────────
var lunitCmd = new Command("lunit", "Run and validate LUnit workflows using existing script contracts.");
var lunitRunCmd = new Command("run", "Run g-cli LUnit then parse/validate UnitTestReport-<os>-<bitness>.xml.");
var lunitValidateCmd = new Command("validate", "Validate UnitTestReport-<os>-<bitness>.xml using RunUnitTests.ps1 parse-only mode.");

var lunitYearOption = new Option<string>(
    name: "--year",
    description: "LabVIEW target year for g-cli LUnit execution (for example: 2026).")
{ IsRequired = true };

var lunitLabviewVersionOption = new Option<string>(
    name: "--labview-version",
    description: "LabVIEW .lvversion/raw value used by parser validation (for example: 26.1).")
{ IsRequired = true };

var lunitBitnessOption = new Option<string>(
    name: "--bitness",
    description: "LabVIEW bitness (32 or 64).")
{ IsRequired = true };

var lunitProjectPathOption = new Option<string>(
    name: "--project-path",
    description: "LabVIEW project path for g-cli LUnit execution.")
{ IsRequired = true };

var lunitReportPathOption = new Option<string?>(
    name: "--report-path",
    description: "Optional UnitTestReport path. Defaults to .github/actions/run-unit-tests/UnitTestReport-<os>-<bitness>.xml");

var lunitVerboseGcliOption = new Option<bool>(
    name: "--verbose-gcli",
    getDefaultValue: () => false,
    description: "Enable g-cli --verbose logging for LUnit diagnostics.");

var lunitDryRunOption = new Option<bool>(
    name: "--dry-run",
    getDefaultValue: () => false,
    description: "Emit underlying command lines without executing them.");

lunitRunCmd.AddOption(repoRootOption);
lunitRunCmd.AddOption(lunitYearOption);
lunitRunCmd.AddOption(lunitLabviewVersionOption);
lunitRunCmd.AddOption(lunitBitnessOption);
lunitRunCmd.AddOption(lunitProjectPathOption);
lunitRunCmd.AddOption(lunitReportPathOption);
lunitRunCmd.AddOption(lunitVerboseGcliOption);
lunitRunCmd.AddOption(lunitDryRunOption);
lunitRunCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = RepoLocator.Resolve(
            context.ParseResult.GetValueForOption(repoRootOption),
            Environment.CurrentDirectory);
        var options = new LunitRunOptions(
            RepoRoot: repoRoot,
            Year: context.ParseResult.GetValueForOption(lunitYearOption) ?? string.Empty,
            LabviewVersion: context.ParseResult.GetValueForOption(lunitLabviewVersionOption) ?? string.Empty,
            Bitness: context.ParseResult.GetValueForOption(lunitBitnessOption) ?? string.Empty,
            ProjectPath: context.ParseResult.GetValueForOption(lunitProjectPathOption) ?? string.Empty,
            ReportPath: context.ParseResult.GetValueForOption(lunitReportPathOption),
            VerboseGcli: context.ParseResult.GetValueForOption(lunitVerboseGcliOption),
            DryRun: context.ParseResult.GetValueForOption(lunitDryRunOption));
        var exitCode = LunitService.Run(options);
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

lunitValidateCmd.AddOption(repoRootOption);
lunitValidateCmd.AddOption(lunitLabviewVersionOption);
lunitValidateCmd.AddOption(lunitBitnessOption);
lunitValidateCmd.AddOption(lunitReportPathOption);
lunitValidateCmd.AddOption(lunitDryRunOption);
lunitValidateCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = RepoLocator.Resolve(
            context.ParseResult.GetValueForOption(repoRootOption),
            Environment.CurrentDirectory);
        var options = new LunitValidateOptions(
            RepoRoot: repoRoot,
            LabviewVersion: context.ParseResult.GetValueForOption(lunitLabviewVersionOption) ?? string.Empty,
            Bitness: context.ParseResult.GetValueForOption(lunitBitnessOption) ?? string.Empty,
            ReportPath: context.ParseResult.GetValueForOption(lunitReportPathOption),
            DryRun: context.ParseResult.GetValueForOption(lunitDryRunOption));
        var exitCode = LunitService.Validate(options);
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

lunitCmd.AddCommand(lunitRunCmd);
lunitCmd.AddCommand(lunitValidateCmd);

// ── ppl build ─────────────────────────────────────────────────────
var pplCmd = new Command("ppl", "Packed Library workflow helpers.");
var pplBuildCmd = new Command("build", "Build packed libraries via BuildProjectSpec.ps1.");

var pplBuildLabviewVersionOption = new Option<string>(
    name: "--labview-version",
    description: "LabVIEW version input (for example 2026 or 26.1).")
{ IsRequired = true };
var pplBuildBitnessOption = new Option<string>(
    name: "--supported-bitness",
    description: "LabVIEW bitness (32 or 64).")
{ IsRequired = true };
var pplBuildMajorOption = new Option<string>(
    name: "--major",
    description: "Semantic version major.")
{ IsRequired = true };
var pplBuildMinorOption = new Option<string>(
    name: "--minor",
    description: "Semantic version minor.")
{ IsRequired = true };
var pplBuildPatchOption = new Option<string>(
    name: "--patch",
    description: "Semantic version patch.")
{ IsRequired = true };
var pplBuildBuildOption = new Option<string>(
    name: "--build",
    description: "Semantic version build.")
{ IsRequired = true };
var pplBuildCommitOption = new Option<string>(
    name: "--commit",
    description: "Commit hash or identifier.")
{ IsRequired = true };
var pplBuildProjectSpecTypeOption = new Option<string?>(
    name: "--project-spec-type",
    description: "Optional project spec type override (PackedLibrary|SourceDistribution).");
var pplBuildSpecNameOption = new Option<string?>(
    name: "--build-spec-name",
    description: "Optional LabVIEW build specification name.");
var pplBuildOutputPathOption = new Option<string?>(
    name: "--output-relative-path",
    description: "Optional output path relative to repo root.");
var pplBuildTargetNameOption = new Option<string?>(
    name: "--target-name",
    description: "Optional LabVIEW target name.");
var pplBuildWorktreeRootOption = new Option<string?>(
    name: "--worktree-root",
    description: "Optional explicit worktree root.");
var pplBuildSkipWorktreeCheckOption = new Option<bool>(
    name: "--skip-worktree-root-check",
    getDefaultValue: () => false,
    description: "Skip worktree root guard.");
var pplBuildDryRunOption = new Option<bool>(
    name: "--dry-run",
    getDefaultValue: () => false,
    description: "Emit underlying command line without executing it.");

pplBuildCmd.AddOption(repoRootOption);
pplBuildCmd.AddOption(pplBuildLabviewVersionOption);
pplBuildCmd.AddOption(pplBuildBitnessOption);
pplBuildCmd.AddOption(pplBuildMajorOption);
pplBuildCmd.AddOption(pplBuildMinorOption);
pplBuildCmd.AddOption(pplBuildPatchOption);
pplBuildCmd.AddOption(pplBuildBuildOption);
pplBuildCmd.AddOption(pplBuildCommitOption);
pplBuildCmd.AddOption(pplBuildProjectSpecTypeOption);
pplBuildCmd.AddOption(pplBuildSpecNameOption);
pplBuildCmd.AddOption(pplBuildOutputPathOption);
pplBuildCmd.AddOption(pplBuildTargetNameOption);
pplBuildCmd.AddOption(pplBuildWorktreeRootOption);
pplBuildCmd.AddOption(pplBuildSkipWorktreeCheckOption);
pplBuildCmd.AddOption(pplBuildDryRunOption);
pplBuildCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = RepoLocator.Resolve(
            context.ParseResult.GetValueForOption(repoRootOption),
            Environment.CurrentDirectory);
        var options = new PplBuildOptions(
            RepoRoot: repoRoot,
            LabviewVersion: context.ParseResult.GetValueForOption(pplBuildLabviewVersionOption) ?? string.Empty,
            SupportedBitness: context.ParseResult.GetValueForOption(pplBuildBitnessOption) ?? string.Empty,
            Major: context.ParseResult.GetValueForOption(pplBuildMajorOption) ?? string.Empty,
            Minor: context.ParseResult.GetValueForOption(pplBuildMinorOption) ?? string.Empty,
            Patch: context.ParseResult.GetValueForOption(pplBuildPatchOption) ?? string.Empty,
            Build: context.ParseResult.GetValueForOption(pplBuildBuildOption) ?? string.Empty,
            Commit: context.ParseResult.GetValueForOption(pplBuildCommitOption) ?? string.Empty,
            ProjectSpecType: context.ParseResult.GetValueForOption(pplBuildProjectSpecTypeOption),
            BuildSpecName: context.ParseResult.GetValueForOption(pplBuildSpecNameOption),
            OutputRelativePath: context.ParseResult.GetValueForOption(pplBuildOutputPathOption),
            TargetName: context.ParseResult.GetValueForOption(pplBuildTargetNameOption),
            WorktreeRoot: context.ParseResult.GetValueForOption(pplBuildWorktreeRootOption),
            SkipWorktreeRootCheck: context.ParseResult.GetValueForOption(pplBuildSkipWorktreeCheckOption),
            DryRun: context.ParseResult.GetValueForOption(pplBuildDryRunOption));
        var exitCode = PplBuildService.Run(options);
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
pplCmd.AddCommand(pplBuildCmd);

// ── vip build ─────────────────────────────────────────────────────
var vipCmd = new Command("vip", "VI Package workflow helpers.");
var vipBuildCmd = new Command("build", "Build VI Package via Tooling/Invoke-VipBuild.ps1.");

var vipBuildBitnessOption = new Option<string>(
    name: "--supported-bitness",
    description: "LabVIEW bitness (32 or 64).")
{ IsRequired = true };
var vipbPathOption = new Option<string>(
    name: "--vipb-path",
    description: "Path to the .vipb file relative to repo root.")
{ IsRequired = true };
var vipBuildLabviewVersionOption = new Option<string?>("--labview-version", "LabVIEW version input.");
var vipBuildLabviewMinorOption = new Option<string?>("--labview-minor-revision", "LabVIEW minor revision.");
var vipBuildMajorOption = new Option<string?>("--major", "Version major.");
var vipBuildMinorOption = new Option<string?>("--minor", "Version minor.");
var vipBuildPatchOption = new Option<string?>("--patch", "Version patch.");
var vipBuildBuildOption = new Option<string?>("--build", "Version build.");
var vipBuildCommitOption = new Option<string?>("--commit", "Commit SHA.");
var vipBuildReleaseNotesOption = new Option<string?>("--release-notes-file", "Release notes markdown path.");
var vipBuildDisplayInfoOption = new Option<string>(
    name: "--display-information-json",
    description: "Display information JSON payload.");
var vipBuildDisplayInfoPathOption = new Option<string?>(
    name: "--display-information-json-path",
    description: "Path to display information JSON payload.");
var vipBuildVipmTimeoutOption = new Option<string?>("--vipm-timeout-seconds", "VIPM timeout in seconds.");
var vipBuildStatusPathOption = new Option<string?>("--status-path", "Optional explicit VIP status JSON output path.");
var vipBuildWorktreeRootOption = new Option<string?>("--worktree-root", "Optional explicit worktree root.");
var vipBuildSkipWorktreeCheckOption = new Option<bool>(
    name: "--skip-worktree-root-check",
    getDefaultValue: () => false,
    description: "Skip worktree root guard.");
var vipBuildDryRunOption = new Option<bool>(
    name: "--dry-run",
    getDefaultValue: () => false,
    description: "Emit underlying command lines without executing them.");

vipBuildCmd.AddOption(repoRootOption);
vipBuildCmd.AddOption(vipBuildBitnessOption);
vipBuildCmd.AddOption(vipbPathOption);
vipBuildCmd.AddOption(vipBuildLabviewVersionOption);
vipBuildCmd.AddOption(vipBuildLabviewMinorOption);
vipBuildCmd.AddOption(vipBuildMajorOption);
vipBuildCmd.AddOption(vipBuildMinorOption);
vipBuildCmd.AddOption(vipBuildPatchOption);
vipBuildCmd.AddOption(vipBuildBuildOption);
vipBuildCmd.AddOption(vipBuildCommitOption);
vipBuildCmd.AddOption(vipBuildReleaseNotesOption);
vipBuildCmd.AddOption(vipBuildDisplayInfoOption);
vipBuildCmd.AddOption(vipBuildDisplayInfoPathOption);
vipBuildCmd.AddOption(vipBuildVipmTimeoutOption);
vipBuildCmd.AddOption(vipBuildStatusPathOption);
vipBuildCmd.AddOption(vipBuildWorktreeRootOption);
vipBuildCmd.AddOption(vipBuildSkipWorktreeCheckOption);
vipBuildCmd.AddOption(vipBuildDryRunOption);
vipBuildCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = RepoLocator.Resolve(
            context.ParseResult.GetValueForOption(repoRootOption),
            Environment.CurrentDirectory);
        var options = new VipBuildOptions(
            RepoRoot: repoRoot,
            SupportedBitness: context.ParseResult.GetValueForOption(vipBuildBitnessOption) ?? string.Empty,
            VipbPath: context.ParseResult.GetValueForOption(vipbPathOption) ?? string.Empty,
            LabviewVersion: context.ParseResult.GetValueForOption(vipBuildLabviewVersionOption),
            LabviewMinorRevision: context.ParseResult.GetValueForOption(vipBuildLabviewMinorOption),
            Major: context.ParseResult.GetValueForOption(vipBuildMajorOption),
            Minor: context.ParseResult.GetValueForOption(vipBuildMinorOption),
            Patch: context.ParseResult.GetValueForOption(vipBuildPatchOption),
            Build: context.ParseResult.GetValueForOption(vipBuildBuildOption),
            Commit: context.ParseResult.GetValueForOption(vipBuildCommitOption),
            ReleaseNotesFile: context.ParseResult.GetValueForOption(vipBuildReleaseNotesOption),
            DisplayInformationJson: context.ParseResult.GetValueForOption(vipBuildDisplayInfoOption) ?? string.Empty,
            DisplayInformationJsonPath: context.ParseResult.GetValueForOption(vipBuildDisplayInfoPathOption),
            VipmTimeoutSeconds: context.ParseResult.GetValueForOption(vipBuildVipmTimeoutOption),
            StatusPath: context.ParseResult.GetValueForOption(vipBuildStatusPathOption),
            WorktreeRoot: context.ParseResult.GetValueForOption(vipBuildWorktreeRootOption),
            SkipWorktreeRootCheck: context.ParseResult.GetValueForOption(vipBuildSkipWorktreeCheckOption),
            DryRun: context.ParseResult.GetValueForOption(vipBuildDryRunOption));
        var exitCode = VipBuildService.Run(options);
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
vipCmd.AddCommand(vipBuildCmd);

// ── vipc apply/assert ─────────────────────────────────────────────
var vipcCmd = new Command("vipc", "VIPC workflow helpers.");
var vipcApplyCmd = new Command("apply", "Apply VIPC dependencies via ApplyVIPC.ps1.");
var vipcAssertCmd = new Command("assert", "Audit VIPC dependencies via Assert-VipcApplied.ps1.");

var vipcBitnessOption = new Option<string>(
    name: "--supported-bitness",
    description: "LabVIEW bitness (32 or 64).")
{ IsRequired = true };
var vipcPathOption = new Option<string>(
    name: "--vipc-path",
    description: "Path to the .vipc file relative to repo root.")
{ IsRequired = true };
var vipcLabviewVersionOption = new Option<string?>("--labview-version", "LabVIEW version input.");
var vipcWorktreeRootOption = new Option<string?>("--worktree-root", "Optional explicit worktree root.");
var vipcSkipWorktreeCheckOption = new Option<bool>(
    name: "--skip-worktree-root-check",
    getDefaultValue: () => false,
    description: "Skip worktree root guard.");
var vipcAllowTargetMismatchOption = new Option<bool>(
    name: "--allow-vipc-target-mismatch",
    getDefaultValue: () => false,
    description: "Allow VIPC target/version mismatch.");
var vipcOutputPathOption = new Option<string>(
    name: "--output-path",
    description: "Path to write VIPC audit JSON output.")
{ IsRequired = true };
var vipcFailOnMismatchOption = new Option<bool>(
    name: "--fail-on-mismatch",
    getDefaultValue: () => true,
    description: "Fail when expected package/version mismatches are detected.");
var vipcDryRunOption = new Option<bool>(
    name: "--dry-run",
    getDefaultValue: () => false,
    description: "Emit underlying command lines without executing them.");

vipcApplyCmd.AddOption(repoRootOption);
vipcApplyCmd.AddOption(vipcBitnessOption);
vipcApplyCmd.AddOption(vipcPathOption);
vipcApplyCmd.AddOption(vipcLabviewVersionOption);
vipcApplyCmd.AddOption(vipcAllowTargetMismatchOption);
vipcApplyCmd.AddOption(vipcWorktreeRootOption);
vipcApplyCmd.AddOption(vipcSkipWorktreeCheckOption);
vipcApplyCmd.AddOption(vipcDryRunOption);
vipcApplyCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = RepoLocator.Resolve(
            context.ParseResult.GetValueForOption(repoRootOption),
            Environment.CurrentDirectory);
        var options = new VipcApplyOptions(
            RepoRoot: repoRoot,
            SupportedBitness: context.ParseResult.GetValueForOption(vipcBitnessOption) ?? string.Empty,
            VipcPath: context.ParseResult.GetValueForOption(vipcPathOption) ?? string.Empty,
            LabviewVersion: context.ParseResult.GetValueForOption(vipcLabviewVersionOption),
            AllowVipcTargetMismatch: context.ParseResult.GetValueForOption(vipcAllowTargetMismatchOption),
            WorktreeRoot: context.ParseResult.GetValueForOption(vipcWorktreeRootOption),
            SkipWorktreeRootCheck: context.ParseResult.GetValueForOption(vipcSkipWorktreeCheckOption),
            DryRun: context.ParseResult.GetValueForOption(vipcDryRunOption));
        var exitCode = VipcService.Apply(options);
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

vipcAssertCmd.AddOption(repoRootOption);
vipcAssertCmd.AddOption(vipcBitnessOption);
vipcAssertCmd.AddOption(vipcPathOption);
vipcAssertCmd.AddOption(vipcLabviewVersionOption);
vipcAssertCmd.AddOption(vipcOutputPathOption);
vipcAssertCmd.AddOption(vipcFailOnMismatchOption);
vipcAssertCmd.AddOption(vipcDryRunOption);
vipcAssertCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = RepoLocator.Resolve(
            context.ParseResult.GetValueForOption(repoRootOption),
            Environment.CurrentDirectory);
        var options = new VipcAssertOptions(
            RepoRoot: repoRoot,
            SupportedBitness: context.ParseResult.GetValueForOption(vipcBitnessOption) ?? string.Empty,
            VipcPath: context.ParseResult.GetValueForOption(vipcPathOption) ?? string.Empty,
            LabviewVersion: context.ParseResult.GetValueForOption(vipcLabviewVersionOption),
            OutputPath: context.ParseResult.GetValueForOption(vipcOutputPathOption) ?? string.Empty,
            FailOnMismatch: context.ParseResult.GetValueForOption(vipcFailOnMismatchOption),
            DryRun: context.ParseResult.GetValueForOption(vipcDryRunOption));
        var exitCode = VipcService.AssertApplied(options);
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

vipcCmd.AddCommand(vipcApplyCmd);
vipcCmd.AddCommand(vipcAssertCmd);

// ── parity context/run ────────────────────────────────────────────
var parityCmd = new Command("parity", "Resolve and execute LabVIEW parity lanes.");
var parityContextCmd = new Command("context", "Resolve parity context from .lvversion and parity contract.");
var lvReleaseOption = new Option<string?>(
    name: "--lv-release",
    description: "LabVIEW release tag (for example 2020q1). When omitted, derived from .lvversion.");
var parityContextModeOption = new Option<string?>(
    name: "--mode",
    description: "Optional parity mode hint for lv_release validation: linux-container|windows-container|self-hosted-windows.");
var parityContractPathOption = new Option<string?>(
    name: "--contract-path",
    description: "Optional parity contract JSON path.");
var parityContextOutputOption = new Option<string?>(
    name: "--output",
    description: "Optional output path to write parity context JSON.");

parityContextCmd.AddOption(repoRootOption);
parityContextCmd.AddOption(lvReleaseOption);
parityContextCmd.AddOption(parityContextModeOption);
parityContextCmd.AddOption(parityContractPathOption);
parityContextCmd.AddOption(parityContextOutputOption);
parityContextCmd.AddOption(jsonOption);
parityContextCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        var lvRelease = context.ParseResult.GetValueForOption(lvReleaseOption);
        var parityMode = context.ParseResult.GetValueForOption(parityContextModeOption);
        var contractPath = context.ParseResult.GetValueForOption(parityContractPathOption);
        var outputPath = context.ParseResult.GetValueForOption(parityContextOutputOption);
        var emitJson = context.ParseResult.GetValueForOption(jsonOption);

        var parityContext = ParityService.BuildContext(repoRoot, lvRelease, contractPath, parityMode);
        if (!string.IsNullOrWhiteSpace(outputPath))
        {
            ParityService.WriteContext(parityContext, outputPath);
        }

        if (emitJson)
        {
            Console.WriteLine(JsonSerializer.Serialize(parityContext, RunnerCliJsonContext.Default.ParityContext));
            return;
        }

        Console.WriteLine($"repo_root={parityContext.RepoRoot}");
        Console.WriteLine($"contract_path={parityContext.ContractPath}");
        Console.WriteLine($"project_path={parityContext.ProjectPath}");
        Console.WriteLine($"project_relative_path={parityContext.ProjectRelativePath}");
        Console.WriteLine($"target_dir_rel={parityContext.TargetDirRel}");
        Console.WriteLine($"build_output_relative_path={parityContext.BuildOutputRelativePath}");
        Console.WriteLine($"lvversion_raw={parityContext.LvVersionRaw}");
        Console.WriteLine($"labview_year={parityContext.LabVIEWYear}");
        Console.WriteLine($"lv_release_resolved={parityContext.LvReleaseResolved}");
        Console.WriteLine($"build_spec_name={parityContext.BuildSpecName}");
        Console.WriteLine($"target_name={parityContext.TargetName}");
        Console.WriteLine($"exclude_files={string.Join(';', parityContext.ExcludeFiles)}");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
        context.ExitCode = 1;
    }
});

var parityRunCmd = new Command("run", "Run parity lane by mode using a parity context JSON.");
var parityModeOption = new Option<string>(
    name: "--mode",
    description: "Parity mode: linux-container|windows-container|self-hosted-windows.")
{ IsRequired = true };
var parityRunContextOption = new Option<string>(
    name: "--context",
    description: "Path to parity context JSON produced by runner-cli parity context.")
{ IsRequired = true };
var parityBuildSpecOption = new Option<bool>(
    name: "--build-spec",
    getDefaultValue: () => true,
    description: "Execute build specification parity path (mandatory; only true is supported).");
var parityLabVIEWPathOption = new Option<string?>(
    name: "--labview-path",
    description: "Optional LabVIEW executable override (self-hosted-windows mode).");
var parityLabVIEWBitnessOption = new Option<string>(
    name: "--labview-bitness",
    getDefaultValue: () => "64",
    description: "LabVIEW bitness for self-hosted-windows mode (32 or 64).");

parityRunCmd.AddOption(parityModeOption);
parityRunCmd.AddOption(parityRunContextOption);
parityRunCmd.AddOption(parityBuildSpecOption);
parityRunCmd.AddOption(parityLabVIEWPathOption);
parityRunCmd.AddOption(parityLabVIEWBitnessOption);
parityRunCmd.AddOption(jsonOption);
parityRunCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var mode = context.ParseResult.GetValueForOption(parityModeOption);
        var contextPath = context.ParseResult.GetValueForOption(parityRunContextOption);
        var buildSpec = context.ParseResult.GetValueForOption(parityBuildSpecOption);
        var labviewPath = context.ParseResult.GetValueForOption(parityLabVIEWPathOption);
        var labviewBitness = context.ParseResult.GetValueForOption(parityLabVIEWBitnessOption);
        var emitJson = context.ParseResult.GetValueForOption(jsonOption);

        if (string.IsNullOrWhiteSpace(mode))
        {
            throw new InvalidOperationException("--mode is required.");
        }
        if (string.IsNullOrWhiteSpace(contextPath))
        {
            throw new InvalidOperationException("--context is required.");
        }
        if (string.IsNullOrWhiteSpace(labviewBitness))
        {
            labviewBitness = "64";
        }
        if (!buildSpec)
        {
            throw new InvalidOperationException(
                "Build-spec disable is unsupported. Parity runs require build-spec execution; omit --build-spec or set --build-spec true.");
        }

        var parityContext = ParityService.LoadContext(contextPath);
        var result = ParityService.Run(parityContext, mode, buildSpec, labviewPath, labviewBitness);

        if (emitJson)
        {
            Console.WriteLine(JsonSerializer.Serialize(result, RunnerCliJsonContext.Default.ParityRunResult));
            return;
        }

        Console.WriteLine($"mode={result.Mode}");
        Console.WriteLine($"repo_root={result.RepoRoot}");
        Console.WriteLine($"project_path={result.ProjectPath}");
        Console.WriteLine($"build_output_path={result.BuildOutputPath}");
        Console.WriteLine($"labview_year={result.LabVIEWYear}");
        Console.WriteLine($"lv_release_resolved={result.LvReleaseResolved}");
        Console.WriteLine($"build_spec_enabled={result.BuildSpecEnabled}");
        Console.WriteLine($"exit_code={result.ExitCode}");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
        context.ExitCode = 1;
    }
});

var paritySelfHostedCmd = new Command("self-hosted", "Resolve parity context and run self-hosted Windows parity in one command.");
var paritySelfHostedLabVIEWPathOption = new Option<string?>(
    name: "--labview-path",
    description: "Optional LabVIEW executable override (self-hosted-windows mode).");
var paritySelfHostedLabVIEWBitnessOption = new Option<string>(
    name: "--labview-bitness",
    getDefaultValue: () => "64",
    description: "LabVIEW bitness for self-hosted-windows mode (32 or 64).");
var paritySelfHostedBuildSpecOption = new Option<bool>(
    name: "--build-spec",
    getDefaultValue: () => true,
    description: "Execute build specification parity path (mandatory; only true is supported).");

paritySelfHostedCmd.AddOption(repoRootOption);
paritySelfHostedCmd.AddOption(lvReleaseOption);
paritySelfHostedCmd.AddOption(parityContractPathOption);
paritySelfHostedCmd.AddOption(paritySelfHostedLabVIEWPathOption);
paritySelfHostedCmd.AddOption(paritySelfHostedLabVIEWBitnessOption);
paritySelfHostedCmd.AddOption(paritySelfHostedBuildSpecOption);
paritySelfHostedCmd.AddOption(jsonOption);
paritySelfHostedCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        var lvRelease = context.ParseResult.GetValueForOption(lvReleaseOption);
        var contractPath = context.ParseResult.GetValueForOption(parityContractPathOption);
        var labviewPath = context.ParseResult.GetValueForOption(paritySelfHostedLabVIEWPathOption);
        var labviewBitness = context.ParseResult.GetValueForOption(paritySelfHostedLabVIEWBitnessOption);
        var buildSpec = context.ParseResult.GetValueForOption(paritySelfHostedBuildSpecOption);
        var emitJson = context.ParseResult.GetValueForOption(jsonOption);

        if (string.IsNullOrWhiteSpace(labviewBitness))
        {
            labviewBitness = "64";
        }
        if (!buildSpec)
        {
            throw new InvalidOperationException(
                "Build-spec disable is unsupported. Parity runs require build-spec execution; omit --build-spec or set --build-spec true.");
        }

        var parityContext = ParityService.BuildContext(repoRoot, lvRelease, contractPath, "self-hosted-windows");
        var result = ParityService.Run(
            parityContext,
            modeInput: "self-hosted-windows",
            buildSpecEnabled: buildSpec,
            labviewPathOverride: labviewPath,
            labviewBitness: labviewBitness);

        if (emitJson)
        {
            Console.WriteLine(JsonSerializer.Serialize(result, RunnerCliJsonContext.Default.ParityRunResult));
            return;
        }

        Console.WriteLine($"mode={result.Mode}");
        Console.WriteLine($"repo_root={result.RepoRoot}");
        Console.WriteLine($"project_path={result.ProjectPath}");
        Console.WriteLine($"build_output_path={result.BuildOutputPath}");
        Console.WriteLine($"labview_year={result.LabVIEWYear}");
        Console.WriteLine($"lv_release_resolved={result.LvReleaseResolved}");
        Console.WriteLine($"build_spec_enabled={result.BuildSpecEnabled}");
        Console.WriteLine($"exit_code={result.ExitCode}");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: {ex.Message}");
        Environment.ExitCode = 1;
        context.ExitCode = 1;
    }
});

parityCmd.AddCommand(parityContextCmd);
parityCmd.AddCommand(parityRunCmd);
parityCmd.AddCommand(paritySelfHostedCmd);

// ── dev-mode prepare-source/restore-source ───────────────────────
var devModeCmd = new Command("dev-mode", "Development mode source orchestration helpers.");
var devModePrepareSourceCmd = new Command("prepare-source", "Prepare LabVIEW source overlays via Prepare_LabVIEW_source.ps1.");
var devModeRestoreSourceCmd = new Command("restore-source", "Restore LabVIEW source overlays via RestoreSetupLVSource.ps1.");

var devModeLabviewVersionOption = new Option<string>(
    name: "--labview-version",
    description: "LabVIEW version input (for example 2026 or 26.1).")
{ IsRequired = true };
var devModeBitnessOption = new Option<string>(
    name: "--supported-bitness",
    description: "LabVIEW bitness (32 or 64).")
{ IsRequired = true };
var devModeConnectTimeoutOption = new Option<string?>(
    name: "--connect-timeout-ms",
    description: "Optional g-cli connect timeout in milliseconds.");
var devModeProcessTimeoutOption = new Option<string?>(
    name: "--process-timeout-ms",
    description: "Optional g-cli process timeout in milliseconds.");
var devModeDryRunOption = new Option<bool>(
    name: "--dry-run",
    getDefaultValue: () => false,
    description: "Emit underlying command line without executing it.");

devModePrepareSourceCmd.AddOption(repoRootOption);
devModePrepareSourceCmd.AddOption(devModeLabviewVersionOption);
devModePrepareSourceCmd.AddOption(devModeBitnessOption);
devModePrepareSourceCmd.AddOption(devModeConnectTimeoutOption);
devModePrepareSourceCmd.AddOption(devModeProcessTimeoutOption);
devModePrepareSourceCmd.AddOption(devModeDryRunOption);
devModePrepareSourceCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = RepoLocator.Resolve(
            context.ParseResult.GetValueForOption(repoRootOption),
            Environment.CurrentDirectory);
        var options = new DevModeSourceOptions(
            RepoRoot: repoRoot,
            LabviewVersion: context.ParseResult.GetValueForOption(devModeLabviewVersionOption) ?? string.Empty,
            SupportedBitness: context.ParseResult.GetValueForOption(devModeBitnessOption) ?? string.Empty,
            ConnectTimeoutMs: context.ParseResult.GetValueForOption(devModeConnectTimeoutOption),
            ProcessTimeoutMs: context.ParseResult.GetValueForOption(devModeProcessTimeoutOption),
            DryRun: context.ParseResult.GetValueForOption(devModeDryRunOption));
        var exitCode = DevModeSourceService.PrepareSource(options);
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

devModeRestoreSourceCmd.AddOption(repoRootOption);
devModeRestoreSourceCmd.AddOption(devModeLabviewVersionOption);
devModeRestoreSourceCmd.AddOption(devModeBitnessOption);
devModeRestoreSourceCmd.AddOption(devModeConnectTimeoutOption);
devModeRestoreSourceCmd.AddOption(devModeProcessTimeoutOption);
devModeRestoreSourceCmd.AddOption(devModeDryRunOption);
devModeRestoreSourceCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = RepoLocator.Resolve(
            context.ParseResult.GetValueForOption(repoRootOption),
            Environment.CurrentDirectory);
        var options = new DevModeSourceOptions(
            RepoRoot: repoRoot,
            LabviewVersion: context.ParseResult.GetValueForOption(devModeLabviewVersionOption) ?? string.Empty,
            SupportedBitness: context.ParseResult.GetValueForOption(devModeBitnessOption) ?? string.Empty,
            ConnectTimeoutMs: context.ParseResult.GetValueForOption(devModeConnectTimeoutOption),
            ProcessTimeoutMs: context.ParseResult.GetValueForOption(devModeProcessTimeoutOption),
            DryRun: context.ParseResult.GetValueForOption(devModeDryRunOption));
        var exitCode = DevModeSourceService.RestoreSource(options);
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

devModeCmd.AddCommand(devModePrepareSourceCmd);
devModeCmd.AddCommand(devModeRestoreSourceCmd);

// ── manifest ──────────────────────────────────────────────────────
var manifestCmd = new Command("manifest", "Emit runner-cli capability and spec metadata.");
manifestCmd.AddOption(repoRootOption);
manifestCmd.AddOption(jsonOption);
manifestCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        var resolvedRoot = RepoLocator.Resolve(repoRoot, Environment.CurrentDirectory);
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
var coverageReportOption = new Option<string?>(
    name: "--coverage-report",
    description: "Optional output path for ConformanceCoverageReport JSON.");
var coverageFailOnGapOption = new Option<bool>(
    name: "--coverage-fail-on-gap",
    getDefaultValue: () => false,
    description: "Fail when uncovered RC IDs are found in trace-derived coverage.");
conformanceCheckCmd.AddOption(profileOption);
conformanceCheckCmd.AddOption(repoRootOption);
conformanceCheckCmd.AddOption(jsonOption);
conformanceCheckCmd.AddOption(strictOption);
conformanceCheckCmd.AddOption(coverageReportOption);
conformanceCheckCmd.AddOption(coverageFailOnGapOption);
conformanceCheckCmd.SetHandler((InvocationContext context) =>
{
    try
    {
        var repoRoot = context.ParseResult.GetValueForOption(repoRootOption);
        var resolvedRoot = RepoLocator.Resolve(repoRoot, Environment.CurrentDirectory);
        var coverageReportPath = context.ParseResult.GetValueForOption(coverageReportOption);
        var coverageFailOnGap = context.ParseResult.GetValueForOption(coverageFailOnGapOption);

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
            Environment.GetEnvironmentVariable("RC_HOSTED_WINDOWS_EVIDENCE"),
            resolvedRoot,
            coverageFailOnGap,
            out var coverageReport);

        var exitCode = ConformanceService.ResolveExitCode(result, strict);
        if (!string.IsNullOrWhiteSpace(coverageReportPath))
        {
            var resolvedCoveragePath = ConformanceService.ResolveOutputPath(coverageReportPath, resolvedRoot);
            var coverageDir = Path.GetDirectoryName(resolvedCoveragePath);
            if (!string.IsNullOrWhiteSpace(coverageDir))
            {
                Directory.CreateDirectory(coverageDir);
            }

            File.WriteAllText(
                resolvedCoveragePath,
                JsonSerializer.Serialize(coverageReport, RunnerCliJsonContext.Default.ConformanceCoverageReport));
        }

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
            if (result.Summary.Coverage is not null)
            {
                Console.WriteLine($"coverage_rc_total={result.Summary.Coverage.RcTotal}");
                Console.WriteLine($"coverage_rc_covered={result.Summary.Coverage.RcCovered}");
                Console.WriteLine($"coverage_rc_uncovered={result.Summary.Coverage.RcUncovered}");
                Console.WriteLine($"coverage_percent={result.Summary.Coverage.CoveragePercent}");
            }
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
rootCmd.AddCommand(lunitCmd);
rootCmd.AddCommand(pplCmd);
rootCmd.AddCommand(vipCmd);
rootCmd.AddCommand(vipcCmd);
rootCmd.AddCommand(parityCmd);
rootCmd.AddCommand(devModeCmd);
rootCmd.AddCommand(manifestCmd);
rootCmd.AddCommand(conformanceCmd);

return await rootCmd.InvokeAsync(args);
