namespace RunnerCli;

public sealed record PplBuildOptions(
    string RepoRoot,
    string LabviewVersion,
    string SupportedBitness,
    string Major,
    string Minor,
    string Patch,
    string Build,
    string Commit,
    string? ProjectSpecType,
    string? BuildSpecName,
    string? OutputRelativePath,
    string? TargetName,
    string? WorktreeRoot,
    bool SkipWorktreeRootCheck,
    bool DryRun
);

public static class PplBuildService
{
    public static int Run(PplBuildOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.RepoRoot))
        {
            throw new ArgumentException("RepoRoot is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.LabviewVersion))
        {
            throw new ArgumentException("LabviewVersion is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.SupportedBitness))
        {
            throw new ArgumentException("SupportedBitness is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.Major))
        {
            throw new ArgumentException("Major is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.Minor))
        {
            throw new ArgumentException("Minor is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.Patch))
        {
            throw new ArgumentException("Patch is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.Build))
        {
            throw new ArgumentException("Build is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.Commit))
        {
            throw new ArgumentException("Commit is required.", nameof(options));
        }

        var repoRoot = Path.GetFullPath(options.RepoRoot);
        var args = new List<string>
        {
            "-RepoRoot", repoRoot,
            "-LabVIEWVersion", options.LabviewVersion,
            "-SupportedBitness", options.SupportedBitness,
            "-Major", options.Major,
            "-Minor", options.Minor,
            "-Patch", options.Patch,
            "-Build", options.Build,
            "-Commit", options.Commit
        };

        AddValueArg(args, "-ProjectSpecType", options.ProjectSpecType);
        AddValueArg(args, "-BuildSpecName", options.BuildSpecName);
        AddValueArg(args, "-OutputRelativePath", options.OutputRelativePath);
        AddValueArg(args, "-TargetName", options.TargetName);
        AddValueArg(args, "-WorktreeRoot", options.WorktreeRoot);
        if (options.SkipWorktreeRootCheck)
        {
            args.Add("-SkipWorktreeRootCheck");
        }

        return PowerShellScriptRunner.Run(
            repoRoot: repoRoot,
            scriptRelativePath: ".github/actions/build-lvlibp/BuildProjectSpec.ps1",
            scriptArguments: args,
            commandLabel: "ppl build",
            dryRun: options.DryRun);
    }

    private static void AddValueArg(ICollection<string> args, string name, string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return;
        }

        args.Add(name);
        args.Add(value);
    }
}
