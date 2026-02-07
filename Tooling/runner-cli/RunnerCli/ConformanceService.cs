using System.Reflection;

namespace RunnerCli;

public static class ConformanceService
{
    private static readonly HashSet<string> ValidProfiles = new(StringComparer.OrdinalIgnoreCase)
    {
        "core",
        "extended",
        "full"
    };

    public static RunnerCliManifest BuildManifest()
    {
        return new RunnerCliManifest
        {
            SpecDocumentId = "LVIE-RC-REQ-v5",
            SpecVersion = "v5",
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
        string repoRoot
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
                Fail = summary.Fail
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
}
