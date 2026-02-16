namespace RunnerCli;

public sealed record DevModeSourceOptions(
    string RepoRoot,
    string LabviewVersion,
    string SupportedBitness,
    string? ConnectTimeoutMs,
    string? ProcessTimeoutMs,
    bool DryRun
);

public static class DevModeSourceService
{
    public static int PrepareSource(DevModeSourceOptions options)
    {
        return Run(
            options: options,
            scriptRelativePath: ".github/actions/prepare-labview-source/Prepare_LabVIEW_source.ps1",
            commandLabel: "dev-mode prepare-source");
    }

    public static int RestoreSource(DevModeSourceOptions options)
    {
        return Run(
            options: options,
            scriptRelativePath: ".github/actions/restore-setup-lv-source/RestoreSetupLVSource.ps1",
            commandLabel: "dev-mode restore-source");
    }

    private static int Run(DevModeSourceOptions options, string scriptRelativePath, string commandLabel)
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

        var repoRoot = Path.GetFullPath(options.RepoRoot);
        var args = new List<string>
        {
            "-LabVIEWVersion", options.LabviewVersion,
            "-SupportedBitness", options.SupportedBitness,
            "-RepoRoot", repoRoot
        };

        AddValueArg(args, "-ConnectTimeoutMs", options.ConnectTimeoutMs);
        AddValueArg(args, "-ProcessTimeoutMs", options.ProcessTimeoutMs);

        return PowerShellScriptRunner.Run(
            repoRoot: repoRoot,
            scriptRelativePath: scriptRelativePath,
            scriptArguments: args,
            commandLabel: commandLabel,
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
