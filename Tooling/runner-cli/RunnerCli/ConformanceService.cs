using System.Reflection;
using System.Text.RegularExpressions;

namespace RunnerCli;

public static class ConformanceService
{
    private static readonly HashSet<string> ValidProfiles = new(StringComparer.OrdinalIgnoreCase)
    {
        "core",
        "extended",
        "full"
    };

    private static readonly Regex RcIdRegex = new(@"RC-[A-Z]+-\d{3}", RegexOptions.Compiled);
    private static readonly Regex RcTokenRegex = new(@"RC-[A-Za-z0-9_-]+", RegexOptions.Compiled);
    private static readonly Regex RevisionLineRegex = new(@"\|\s*Semantic Revision\s*\|\s*([^|]+)\|", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex ChangeIdRegex = new(@"^V\d+(\.\d+)?-", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex ProfileTokenRegex = new(@"core|extended|full", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly StringComparer RcIdComparer = StringComparer.OrdinalIgnoreCase;

    public static RunnerCliManifest BuildManifest()
    {
        return new RunnerCliManifest
        {
            SpecDocumentId = "LVIE-RC-REQ-v5",
            SpecVersion = "v5.2",
            SupportedCommands = new List<string>
            {
                "validate-contract",
                "init-contract",
                "emit-env",
                "version-gate",
                "pylavi scan",
                "pylavi summarize",
                "pylavi fetch",
                "missing-in-project",
                "parity context",
                "parity run",
                "manifest",
                "conformance check"
            },
            SupportedProfiles = new List<string> { "core", "extended", "full" },
            BuildVersion = ResolveBuildVersion(),
            GeneratedUtc = DateTime.UtcNow.ToString("o")
        };
    }

    public static ConformanceCheckResult Run(
        string? profileInput,
        bool strict,
        string? hostedLinuxEvidence,
        string? hostedWindowsEvidence,
        string repoRoot,
        bool coverageFailOnGap,
        out ConformanceCoverageReport coverageReport
    )
    {
        var profile = NormalizeProfile(profileInput);
        var checks = new List<ConformanceCheckEntry>();

        // Core checks
        checks.Add(BuildHostedEvidenceCheck(
            id: "core.hosted.linux.evidence",
            evidence: hostedLinuxEvidence,
            platformName: "linux"));
        checks.Add(BuildHostedEvidenceCheck(
            id: "core.hosted.windows.evidence",
            evidence: hostedWindowsEvidence,
            platformName: "windows"));

        checks.Add(new ConformanceCheckEntry
        {
            Id = "core.windows-only.nonwindows-not-applicable",
            Status = "pass",
            Severity = "info",
            Message = "Windows-only checks are reported as not applicable on Linux/macOS and are not treated as failures.",
            Evidence = OperatingSystem.IsWindows()
                ? "Current execution platform is Windows."
                : "Current execution platform is non-Windows."
        });

        if (IsAtLeastExtended(profile))
        {
            checks.Add(new ConformanceCheckEntry
            {
                Id = "extended.command.manifest",
                Status = "pass",
                Severity = "info",
                Message = "manifest command surface is present.",
                Evidence = "runner-cli manifest"
            });
            checks.Add(new ConformanceCheckEntry
            {
                Id = "extended.command.conformance-check",
                Status = "pass",
                Severity = "info",
                Message = "conformance check command surface is present.",
                Evidence = "runner-cli conformance check"
            });
        }

        // v6 C1 coverage automation (forward-compatible, no command-surface break)
        var coverageContext = ComputeCoverage(profile, repoRoot);
        coverageReport = coverageContext.Report;

        if (coverageContext.Errors.Count == 0)
        {
            var uncovered = coverageReport.Coverage.RcUncovered;
            var summaryStatus = uncovered == 0 ? "pass" : "warn";
            var summarySeverity = uncovered == 0 ? "info" : "warning";
            checks.Add(new ConformanceCheckEntry
            {
                Id = "coverage.summary",
                Status = summaryStatus,
                Severity = summarySeverity,
                Message = uncovered == 0
                    ? "RC coverage set is fully represented by acceptance scenario targets."
                    : $"{uncovered} uncovered RC IDs were found in trace-derived coverage. Use --coverage-fail-on-gap to enforce failure.",
                Evidence = $"semantic_revision={coverageReport.SemanticRevision}; trace_path={coverageReport.TracePath}; acceptance_path={coverageReport.AcceptancePath}"
            });

            if (coverageFailOnGap && uncovered > 0)
            {
                foreach (var rcId in coverageReport.Coverage.UncoveredRcIds)
                {
                    checks.Add(new ConformanceCheckEntry
                    {
                        Id = BuildCoverageGapCheckId(rcId),
                        Status = "fail",
                        Severity = "error",
                        Message = $"Uncovered RC ID: {rcId}",
                        Evidence = $"trace_path={coverageReport.TracePath}; acceptance_path={coverageReport.AcceptancePath}; semantic_revision={coverageReport.SemanticRevision}"
                    });
                }
            }
        }
        else
        {
            checks.Add(new ConformanceCheckEntry
            {
                Id = "coverage.inputs",
                Status = "fail",
                Severity = "error",
                Message = "Coverage automation inputs could not be parsed.",
                Evidence = string.Join(" | ", coverageContext.Errors)
            });
        }

        if (IsAtLeastFull(profile))
        {
            var tracePath = Path.Combine(repoRoot, "docs", "runner-cli-requirements-v4-to-v5-trace.md");
            var acceptancePath = Path.Combine(repoRoot, "docs", "runner-cli-requirements-v5-acceptance.md");
            var traceExists = File.Exists(tracePath);
            var acceptanceExists = File.Exists(acceptancePath);

            if (traceExists && acceptanceExists)
            {
                checks.Add(new ConformanceCheckEntry
                {
                    Id = "full.governance.traceability",
                    Status = "pass",
                    Severity = "info",
                    Message = "Governance and traceability requirements are represented in the requirements artifacts.",
                    Evidence = "docs/runner-cli-requirements-v4-to-v5-trace.md; docs/runner-cli-requirements-v5-acceptance.md"
                });
            }
            else
            {
                checks.Add(new ConformanceCheckEntry
                {
                    Id = "full.governance.traceability",
                    Status = "fail",
                    Severity = "error",
                    Message = "Required governance traceability artifacts are missing for full profile conformance.",
                    Evidence = $"trace_exists={traceExists}; acceptance_exists={acceptanceExists}; repo_root={repoRoot}"
                });
            }
        }

        var summary = BuildSummary(checks);
        return new ConformanceCheckResult
        {
            Profile = profile,
            GeneratedUtc = DateTime.UtcNow.ToString("o"),
            Summary = new ConformanceCheckSummary
            {
                Total = summary.Total,
                Pass = summary.Pass,
                Warn = summary.Warn,
                Fail = summary.Fail,
                Coverage = coverageReport.Coverage
            },
            Checks = checks
        };
    }

    public static int ResolveExitCode(ConformanceCheckResult result, bool strict)
    {
        if (result.Summary.Fail > 0)
            return 2;
        if (strict && result.Summary.Warn > 0)
            return 3;
        return 0;
    }

    public static string ResolveProfile(string? profileOption)
    {
        var profile = profileOption;
        if (string.IsNullOrWhiteSpace(profile))
        {
            profile = Environment.GetEnvironmentVariable("RC_PROFILE");
        }
        return NormalizeProfile(profile);
    }

    public static bool ResolveStrict(bool? strictOption)
    {
        if (strictOption.HasValue)
            return strictOption.Value;

        var env = Environment.GetEnvironmentVariable("RC_STRICT_MODE");
        if (string.IsNullOrWhiteSpace(env))
            return false;
        return env.Equals("1", StringComparison.OrdinalIgnoreCase)
            || env.Equals("true", StringComparison.OrdinalIgnoreCase)
            || env.Equals("yes", StringComparison.OrdinalIgnoreCase);
    }

    public static string ResolveOutputPath(string outputPath, string repoRoot)
    {
        if (Path.IsPathRooted(outputPath))
        {
            return Path.GetFullPath(outputPath);
        }

        return Path.GetFullPath(Path.Combine(repoRoot, outputPath));
    }

    private static string NormalizeProfile(string? profileInput)
    {
        var value = (profileInput ?? "core").Trim().ToLowerInvariant();
        if (!ValidProfiles.Contains(value))
        {
            throw new ArgumentException($"Unsupported conformance profile '{profileInput}'. Use core|extended|full.");
        }
        return value;
    }

    private static (int Total, int Pass, int Warn, int Fail) BuildSummary(List<ConformanceCheckEntry> checks)
    {
        var pass = checks.Count(entry => string.Equals(entry.Status, "pass", StringComparison.OrdinalIgnoreCase));
        var warn = checks.Count(entry => string.Equals(entry.Status, "warn", StringComparison.OrdinalIgnoreCase));
        var fail = checks.Count(entry => string.Equals(entry.Status, "fail", StringComparison.OrdinalIgnoreCase));
        return (checks.Count, pass, warn, fail);
    }

    private static ConformanceCheckEntry BuildHostedEvidenceCheck(string id, string? evidence, string platformName)
    {
        if (!string.IsNullOrWhiteSpace(evidence))
        {
            return new ConformanceCheckEntry
            {
                Id = id,
                Status = "pass",
                Severity = "info",
                Message = $"Hosted {platformName} Core evidence is available.",
                Evidence = evidence.Trim()
            };
        }

        return new ConformanceCheckEntry
        {
            Id = id,
            Status = "warn",
            Severity = "warning",
            Message = $"Hosted {platformName} Core evidence is missing.",
            Evidence = "Set RC_HOSTED_LINUX_EVIDENCE / RC_HOSTED_WINDOWS_EVIDENCE before running conformance check."
        };
    }

    private static bool IsAtLeastExtended(string profile) =>
        profile.Equals("extended", StringComparison.OrdinalIgnoreCase)
        || profile.Equals("full", StringComparison.OrdinalIgnoreCase);

    private static bool IsAtLeastFull(string profile) =>
        profile.Equals("full", StringComparison.OrdinalIgnoreCase);

    private static string ResolveBuildVersion()
    {
        var assembly = Assembly.GetExecutingAssembly();
        var info = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
        if (!string.IsNullOrWhiteSpace(info))
            return info;
        return assembly.GetName().Version?.ToString() ?? "0.0.0";
    }

    private static CoverageComputation ComputeCoverage(string profile, string repoRoot)
    {
        var requirementsPath = Path.GetFullPath(Path.Combine(repoRoot, "docs", "runner-cli-requirements.md"));
        var acceptancePath = Path.GetFullPath(Path.Combine(repoRoot, "docs", "runner-cli-requirements-v5-acceptance.md"));
        var tracePath = Path.GetFullPath(Path.Combine(repoRoot, "docs", "runner-cli-requirements-v4-to-v5-trace.md"));
        var errors = new List<string>();
        var semanticRevision = "unknown";

        if (!File.Exists(requirementsPath))
            errors.Add($"requirements_missing={requirementsPath}");
        if (!File.Exists(acceptancePath))
            errors.Add($"acceptance_missing={acceptancePath}");
        if (!File.Exists(tracePath))
            errors.Add($"trace_missing={tracePath}");

        var coverage = new CoverageSummary();
        if (errors.Count == 0)
        {
            if (!TryReadSemanticRevision(requirementsPath, out semanticRevision))
            {
                errors.Add($"semantic_revision_missing={requirementsPath}");
            }
            else
            {
                var traceRcIds = ReadTraceCoverageRcIds(tracePath, semanticRevision, profile, errors);
                var acceptanceRcIds = ReadAcceptanceScenarioRcIds(acceptancePath, errors);
                var uncovered = traceRcIds
                    .Where(id => !acceptanceRcIds.Contains(id))
                    .OrderBy(id => id, StringComparer.OrdinalIgnoreCase)
                    .ToList();

                coverage = new CoverageSummary
                {
                    RcTotal = traceRcIds.Count,
                    RcCovered = traceRcIds.Count - uncovered.Count,
                    RcUncovered = uncovered.Count,
                    CoveragePercent = traceRcIds.Count == 0
                        ? 100.0
                        : Math.Round(((double)(traceRcIds.Count - uncovered.Count) / traceRcIds.Count) * 100.0, 2),
                    UncoveredRcIds = uncovered
                };

                if (traceRcIds.Count == 0)
                {
                    errors.Add($"coverage_set_empty=semantic_revision:{semanticRevision};profile:{profile}");
                }
            }
        }

        var report = new ConformanceCoverageReport
        {
            Profile = profile,
            GeneratedUtc = DateTime.UtcNow.ToString("o"),
            SemanticRevision = semanticRevision,
            RequirementsPath = requirementsPath,
            AcceptancePath = acceptancePath,
            TracePath = tracePath,
            Coverage = coverage
        };

        return new CoverageComputation(report, errors);
    }

    private static bool TryReadSemanticRevision(string requirementsPath, out string semanticRevision)
    {
        foreach (var line in File.ReadLines(requirementsPath))
        {
            var match = RevisionLineRegex.Match(line);
            if (match.Success)
            {
                semanticRevision = match.Groups[1].Value.Trim();
                return !string.IsNullOrWhiteSpace(semanticRevision);
            }
        }

        semanticRevision = string.Empty;
        return false;
    }

    private static HashSet<string> ReadTraceCoverageRcIds(
        string tracePath,
        string semanticRevision,
        string profile,
        List<string> errors)
    {
        var set = new HashSet<string>(RcIdComparer);
        foreach (var line in File.ReadLines(tracePath))
        {
            if (!line.StartsWith('|'))
                continue;

            var cells = line.Split('|');
            if (cells.Length < 6)
                continue;

            var changeId = cells[1].Trim();
            if (!ChangeIdRegex.IsMatch(changeId))
                continue;
            if (!IsTraceRowForSemanticRevision(changeId, semanticRevision))
                continue;

            var rowProfile = cells[4].Trim();
            if (!DoesTraceRowApplyToProfile(rowProfile, profile))
                continue;

            var rcCell = cells[3].Trim();
            foreach (Match token in RcTokenRegex.Matches(rcCell))
            {
                if (!RcIdRegex.IsMatch(token.Value))
                {
                    errors.Add($"trace_noncanonical_rc={token.Value};change_id={changeId}");
                }
            }

            foreach (Match match in RcIdRegex.Matches(rcCell))
            {
                set.Add(match.Value);
            }
        }

        return set;
    }

    private static HashSet<string> ReadAcceptanceScenarioRcIds(string acceptancePath, List<string> errors)
    {
        var set = new HashSet<string>(RcIdComparer);
        foreach (var line in File.ReadLines(acceptancePath))
        {
            if (line.StartsWith("Acceptance coverage summary:", StringComparison.OrdinalIgnoreCase))
                break;
            if (!line.StartsWith("| A-", StringComparison.Ordinal))
                continue;

            var cells = line.Split('|');
            if (cells.Length < 4)
                continue;

            var rcCell = cells[3].Trim();
            foreach (Match token in RcTokenRegex.Matches(rcCell))
            {
                if (!RcIdRegex.IsMatch(token.Value))
                {
                    errors.Add($"acceptance_noncanonical_rc={token.Value}");
                }
            }

            foreach (Match match in RcIdRegex.Matches(rcCell))
            {
                set.Add(match.Value);
            }
        }

        if (set.Count == 0)
        {
            errors.Add($"acceptance_target_set_empty={acceptancePath}");
        }

        return set;
    }

    private static bool IsTraceRowForSemanticRevision(string changeId, string semanticRevision)
    {
        var normalized = semanticRevision.Trim().TrimStart('v', 'V');
        if (string.IsNullOrWhiteSpace(normalized))
            return false;

        var major = normalized.Split('.', 2, StringSplitOptions.RemoveEmptyEntries)[0];
        return changeId.StartsWith($"V{normalized}-", StringComparison.OrdinalIgnoreCase)
            || changeId.StartsWith($"V{major}-", StringComparison.OrdinalIgnoreCase);
    }

    private static bool DoesTraceRowApplyToProfile(string rowProfileCell, string selectedProfile)
    {
        var rowProfiles = new HashSet<string>(
            ProfileTokenRegex.Matches(rowProfileCell).Select(m => m.Value.ToLowerInvariant()),
            StringComparer.OrdinalIgnoreCase);
        if (rowProfiles.Count == 0)
            return false;

        var effectiveProfiles = selectedProfile.ToLowerInvariant() switch
        {
            "core" => new HashSet<string>(new[] { "core" }, StringComparer.OrdinalIgnoreCase),
            "extended" => new HashSet<string>(new[] { "core", "extended" }, StringComparer.OrdinalIgnoreCase),
            "full" => new HashSet<string>(new[] { "core", "extended", "full" }, StringComparer.OrdinalIgnoreCase),
            _ => new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        };

        return rowProfiles.Overlaps(effectiveProfiles);
    }

    private static string BuildCoverageGapCheckId(string rcId)
    {
        return $"coverage.uncovered.{rcId.ToLowerInvariant()}";
    }

    private sealed class CoverageComputation
    {
        public CoverageComputation(ConformanceCoverageReport report, List<string> errors)
        {
            Report = report;
            Errors = errors;
        }

        public ConformanceCoverageReport Report { get; }
        public List<string> Errors { get; }
    }
}
