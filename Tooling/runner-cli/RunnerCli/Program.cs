using System.CommandLine;
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

// ── root ───────────────────────────────────────────────────────────
var rootCmd = new RootCommand("LVIE Runner CLI – contract management for stateless self-hosted runners.");
rootCmd.AddCommand(validateCmd);
rootCmd.AddCommand(initCmd);
rootCmd.AddCommand(emitCmd);

return await rootCmd.InvokeAsync(args);
