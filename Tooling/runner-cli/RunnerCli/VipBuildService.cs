namespace RunnerCli;

public sealed record VipBuildOptions(
    string RepoRoot,
    string SupportedBitness,
    string VipbPath,
    string? LabviewVersion,
    string? LabviewMinorRevision,
    string? Major,
    string? Minor,
    string? Patch,
    string? Build,
    string? Commit,
    string? ReleaseNotesFile,
    string DisplayInformationJson,
    string? DisplayInformationJsonPath,
    string? VipmTimeoutSeconds,
    string? MaxAttempts,
    string? RetryDelaySeconds,
    string? StatusPath,
    string? WorktreeRoot,
    bool SkipWorktreeRootCheck,
    bool DryRun
);

public static class VipBuildService
{
    public static int Run(VipBuildOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.RepoRoot))
        {
            throw new ArgumentException("RepoRoot is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.SupportedBitness))
        {
            throw new ArgumentException("SupportedBitness is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.VipbPath))
        {
            throw new ArgumentException("VipbPath is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.DisplayInformationJson) &&
            string.IsNullOrWhiteSpace(options.DisplayInformationJsonPath))
        {
            throw new ArgumentException(
                "Either DisplayInformationJson or DisplayInformationJsonPath is required.",
                nameof(options));
        }

        var repoRoot = Path.GetFullPath(options.RepoRoot);
        var args = new List<string>
        {
            "-SupportedBitness", options.SupportedBitness,
            "-RepoRoot", repoRoot,
            "-VIPBPath", options.VipbPath
        };

        if (!string.IsNullOrWhiteSpace(options.DisplayInformationJsonPath))
        {
            var displayInfoPath = options.DisplayInformationJsonPath!;
            if (!Path.IsPathRooted(displayInfoPath))
            {
                displayInfoPath = Path.Combine(repoRoot, displayInfoPath);
            }
            displayInfoPath = Path.GetFullPath(displayInfoPath);
            if (!File.Exists(displayInfoPath))
            {
                throw new FileNotFoundException(
                    $"Display information JSON file not found at '{displayInfoPath}'.",
                    displayInfoPath);
            }

            args.Add("-DisplayInformationJsonPath");
            args.Add(displayInfoPath);
        }
        else
        {
            args.Add("-DisplayInformationJSON");
            args.Add(options.DisplayInformationJson);
        }

        AddValueArg(args, "-LabVIEWVersion", options.LabviewVersion);
        AddValueArg(args, "-LabVIEWMinorRevision", options.LabviewMinorRevision);
        AddValueArg(args, "-Major", options.Major);
        AddValueArg(args, "-Minor", options.Minor);
        AddValueArg(args, "-Patch", options.Patch);
        AddValueArg(args, "-Build", options.Build);
        AddValueArg(args, "-Commit", options.Commit);
        AddValueArg(args, "-ReleaseNotesFile", options.ReleaseNotesFile);
        AddValueArg(args, "-VipmTimeoutSeconds", options.VipmTimeoutSeconds);
        AddValueArg(args, "-MaxAttempts", options.MaxAttempts);
        AddValueArg(args, "-RetryDelaySeconds", options.RetryDelaySeconds);
        AddValueArg(args, "-StatusPath", options.StatusPath);
        AddValueArg(args, "-WorktreeRoot", options.WorktreeRoot);
        if (options.SkipWorktreeRootCheck)
        {
            args.Add("-SkipWorktreeRootCheck");
        }

        return PowerShellScriptRunner.Run(
            repoRoot: repoRoot,
            scriptRelativePath: "Tooling/Invoke-VipBuild.ps1",
            scriptArguments: args,
            commandLabel: "vip build",
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
