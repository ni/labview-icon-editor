using System.Text.RegularExpressions;

namespace RunnerCli;

public static class LabVIEWVersionService
{
    private static readonly Regex VersionRegex = new(@"^(?<major>\d{2,4})(?:\.(?<minor>\d+))?$", RegexOptions.Compiled);

    public static LabVIEWVersionInfo GetVersionInfo(string? versionInput, string? repoRoot)
    {
        var inputProvided = !string.IsNullOrWhiteSpace(versionInput);
        var raw = versionInput;
        string? repoRaw = null;

        if (string.IsNullOrWhiteSpace(raw))
        {
            if (string.IsNullOrWhiteSpace(repoRoot))
            {
                throw new InvalidOperationException("RepoRoot is required when version input is not provided.");
            }

            var versionPath = Path.Combine(repoRoot, ".lvversion");
            if (!File.Exists(versionPath))
            {
                throw new FileNotFoundException($".lvversion not found at {versionPath}");
            }

            repoRaw = File.ReadAllText(versionPath).Trim();
            raw = repoRaw;
        }
        else if (!string.IsNullOrWhiteSpace(repoRoot))
        {
            var versionPath = Path.Combine(repoRoot, ".lvversion");
            if (!File.Exists(versionPath))
            {
                throw new FileNotFoundException($".lvversion not found at {versionPath}");
            }
            repoRaw = File.ReadAllText(versionPath).Trim();
        }

        var info = Parse(raw!);

        if (inputProvided && !string.IsNullOrWhiteSpace(repoRaw))
        {
            var repoInfo = Parse(repoRaw!);
            if (info.Year != repoInfo.Year || info.MinorRevision != repoInfo.MinorRevision)
            {
                throw new InvalidOperationException($"LabVIEW version '{info.Raw}' does not match .lvversion '{repoInfo.Raw}'.");
            }
        }

        return info;
    }

    public static LabVIEWVersionInfo Parse(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            throw new ArgumentException("LabVIEW version input is empty.", nameof(raw));
        }

        var match = VersionRegex.Match(raw.Trim());
        if (!match.Success)
        {
            throw new InvalidOperationException($"LabVIEW version '{raw}' is invalid. Expected formats like '21.0' or '2021'.");
        }

        var majorRaw = int.Parse(match.Groups["major"].Value);
        var minor = match.Groups["minor"].Success ? int.Parse(match.Groups["minor"].Value) : 0;

        int year;
        int numericMajor;
        if (majorRaw >= 2000)
        {
            year = majorRaw;
            numericMajor = majorRaw - 2000;
        }
        else
        {
            numericMajor = majorRaw;
            year = 2000 + majorRaw;
        }

        if (numericMajor < 0)
        {
            throw new InvalidOperationException($"LabVIEW version '{raw}' produced an invalid numeric major.");
        }

        return new LabVIEWVersionInfo(
            raw.Trim(),
            year.ToString(),
            minor,
            numericMajor,
            $"{numericMajor}.{minor}"
        );
    }
}
