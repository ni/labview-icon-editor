namespace RunnerCli;

public sealed record VipcApplyOptions(
    string RepoRoot,
    string SupportedBitness,
    string VipcPath,
    string? LabviewVersion,
    bool AllowVipcTargetMismatch,
    string? WorktreeRoot,
    bool SkipWorktreeRootCheck,
    bool DryRun
);

public sealed record VipcAssertOptions(
    string RepoRoot,
    string SupportedBitness,
    string VipcPath,
    string? LabviewVersion,
    string OutputPath,
    bool FailOnMismatch,
    bool DryRun
);

public static class VipcService
{
    public static int Apply(VipcApplyOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.RepoRoot))
        {
            throw new ArgumentException("RepoRoot is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.SupportedBitness))
        {
            throw new ArgumentException("SupportedBitness is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.VipcPath))
        {
            throw new ArgumentException("VipcPath is required.", nameof(options));
        }

        var repoRoot = Path.GetFullPath(options.RepoRoot);
        var args = new List<string>
        {
            "-SupportedBitness", options.SupportedBitness,
            "-RepoRoot", repoRoot,
            "-VIPCPath", options.VipcPath
        };

        AddValueArg(args, "-LabVIEWVersion", options.LabviewVersion);
        if (options.AllowVipcTargetMismatch)
        {
            args.Add("-AllowVipcTargetMismatch");
        }
        AddValueArg(args, "-WorktreeRoot", options.WorktreeRoot);
        if (options.SkipWorktreeRootCheck)
        {
            args.Add("-SkipWorktreeRootCheck");
        }

        return PowerShellScriptRunner.Run(
            repoRoot: repoRoot,
            scriptRelativePath: ".github/actions/apply-vipc/ApplyVIPC.ps1",
            scriptArguments: args,
            commandLabel: "vipc apply",
            dryRun: options.DryRun);
    }

    public static int AssertApplied(VipcAssertOptions options)
    {
        if (string.IsNullOrWhiteSpace(options.RepoRoot))
        {
            throw new ArgumentException("RepoRoot is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.SupportedBitness))
        {
            throw new ArgumentException("SupportedBitness is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.VipcPath))
        {
            throw new ArgumentException("VipcPath is required.", nameof(options));
        }
        if (string.IsNullOrWhiteSpace(options.OutputPath))
        {
            throw new ArgumentException("OutputPath is required.", nameof(options));
        }

        var repoRoot = Path.GetFullPath(options.RepoRoot);
        var args = new List<string>
        {
            "-RepoRoot", repoRoot,
            "-VIPCPath", options.VipcPath,
            "-SupportedBitness", options.SupportedBitness,
            "-OutputPath", options.OutputPath
        };

        AddValueArg(args, "-LabVIEWVersion", options.LabviewVersion);
        if (!options.FailOnMismatch)
        {
            args.Add("-FailOnMismatch");
            args.Add("false");
        }

        return PowerShellScriptRunner.Run(
            repoRoot: repoRoot,
            scriptRelativePath: "Tooling/Assert-VipcApplied.ps1",
            scriptArguments: args,
            commandLabel: "vipc assert",
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
