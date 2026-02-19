namespace RunnerCli;

public sealed record LabVIEWExecutionYearResolution(
    LabVIEWVersionInfo SourceVersion,
    string ExecutionYear,
    bool CompatMappingApplied
);

public static class LabVIEWExecutionYearCompatibilityService
{
    public const string SourceYearLv2020 = "2020";
    public const string FallbackExecutionYear = "2026";

    public static LabVIEWExecutionYearResolution Resolve(
        string? sourceLabviewVersion,
        string repoRoot,
        string commandLabel)
    {
        if (string.IsNullOrWhiteSpace(repoRoot))
        {
            throw new ArgumentException("Repo root is required.", nameof(repoRoot));
        }

        var sourceVersion = LabVIEWVersionService.GetVersionInfo(sourceLabviewVersion, repoRoot);
        var compatMappingApplied = string.Equals(
            sourceVersion.Year,
            SourceYearLv2020,
            StringComparison.Ordinal);
        var executionYear = compatMappingApplied ? FallbackExecutionYear : sourceVersion.Year;

        Console.Error.WriteLine(
            $"{commandLabel} LabVIEW source contract: raw={sourceVersion.Raw}; year={sourceVersion.Year}; minor={sourceVersion.MinorRevision}.");
        if (compatMappingApplied)
        {
            Console.Error.WriteLine(
                $"{commandLabel} LabVIEW execution-year compatibility mapping applied: source year {sourceVersion.Year} -> execution year {executionYear}.");
        }
        else
        {
            Console.Error.WriteLine(
                $"{commandLabel} LabVIEW execution year: {executionYear} (compatibility mapping not applied).");
        }

        return new LabVIEWExecutionYearResolution(
            SourceVersion: sourceVersion,
            ExecutionYear: executionYear,
            CompatMappingApplied: compatMappingApplied);
    }
}
