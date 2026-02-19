using System.Diagnostics;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace RunnerCli;

public static class ParityService
{
    private static readonly Regex ReleaseYearRegex = new(@"^(?<year>\d{4})", RegexOptions.Compiled);
    private const string DefaultContainerFallbackRelease = "2026q1";

    public static ParityContext BuildContext(
        string? repoRootOverride,
        string? lvReleaseInput,
        string? contractPathOverride,
        string? parityModeHint)
    {
        var repoRoot = RepoLocator.Resolve(repoRootOverride, Environment.CurrentDirectory);
        var versionInfo = LabVIEWVersionService.GetVersionInfo(versionInput: null, repoRoot: repoRoot);

        var contractPath = ResolveContractPath(repoRoot, contractPathOverride);
        if (!File.Exists(contractPath))
        {
            throw new FileNotFoundException($"Parity contract file was not found: {contractPath}", contractPath);
        }

        var contract = JsonSerializer.Deserialize(
            File.ReadAllText(contractPath),
            RunnerCliJsonContext.Default.ParityContractDefinition);
        if (contract is null)
        {
            throw new InvalidOperationException($"Failed to parse parity contract JSON: {contractPath}");
        }

        ValidateContract(contract, contractPath);

        var projectRelativePath = NormalizeRelativePath(contract.ProjectRelativePath, nameof(contract.ProjectRelativePath), contractPath);
        var targetDirRel = NormalizeRelativePath(contract.TargetDirRelativePath, nameof(contract.TargetDirRelativePath), contractPath);
        var buildOutputRel = NormalizeRelativePath(contract.BuildOutputRelativePath, nameof(contract.BuildOutputRelativePath), contractPath);
        var excludeFiles = contract.ExcludeFiles
            .Where(entry => !string.IsNullOrWhiteSpace(entry))
            .Select(entry => entry.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (excludeFiles.Count == 0)
        {
            throw new InvalidOperationException($"Parity contract must define at least one exclude file: {contractPath}");
        }

        var lvReleaseResolved = ResolveLvRelease(
            lvReleaseInput,
            versionInfo.Year,
            contract.DefaultReleaseSuffix,
            parityModeHint);

        var projectPath = ResolveRepoPath(repoRoot, projectRelativePath);
        if (!File.Exists(projectPath))
        {
            throw new FileNotFoundException($"Parity project file was not found: {projectPath}", projectPath);
        }

        return new ParityContext
        {
            RepoRoot = repoRoot,
            ContractPath = contractPath,
            ProjectPath = projectPath,
            ProjectRelativePath = projectRelativePath,
            TargetDirRel = targetDirRel,
            BuildOutputRelativePath = buildOutputRel,
            LvVersionRaw = versionInfo.Raw,
            LabVIEWYear = versionInfo.Year,
            LvReleaseResolved = lvReleaseResolved,
            BuildSpecName = contract.BuildSpecName.Trim(),
            TargetName = contract.TargetName.Trim(),
            ExcludeFiles = excludeFiles
        };
    }

    public static void WriteContext(ParityContext context, string outputPath)
    {
        var resolvedPath = Path.GetFullPath(outputPath);
        var outputDir = Path.GetDirectoryName(resolvedPath);
        if (!string.IsNullOrWhiteSpace(outputDir))
        {
            Directory.CreateDirectory(outputDir);
        }

        var json = JsonSerializer.Serialize(context, RunnerCliJsonContext.Default.ParityContext);
        File.WriteAllText(resolvedPath, json);
    }

    public static ParityContext LoadContext(string contextPath)
    {
        var resolvedPath = Path.GetFullPath(contextPath);
        if (!File.Exists(resolvedPath))
        {
            throw new FileNotFoundException($"Parity context file was not found: {resolvedPath}", resolvedPath);
        }

        var context = JsonSerializer.Deserialize(
            File.ReadAllText(resolvedPath),
            RunnerCliJsonContext.Default.ParityContext);
        if (context is null)
        {
            throw new InvalidOperationException($"Failed to parse parity context JSON: {resolvedPath}");
        }

        return context;
    }

    public static ParityRunResult Run(
        ParityContext context,
        string modeInput,
        bool buildSpecEnabled,
        string? labviewPathOverride,
        string labviewBitness)
    {
        if (context is null)
        {
            throw new ArgumentNullException(nameof(context));
        }
        if (!buildSpecEnabled)
        {
            throw new InvalidOperationException(
                "Build-spec disable is unsupported. Parity runs require build-spec execution.");
        }

        var mode = NormalizeMode(modeInput);
        var buildOutputPath = ResolveRepoPath(context.RepoRoot, context.BuildOutputRelativePath);

        switch (mode)
        {
            case "linux-container":
                RunLinuxContainer(context);
                break;
            case "windows-container":
                RunWindowsContainer(context);
                break;
            case "self-hosted-windows":
                RunSelfHostedWindows(context, labviewPathOverride, labviewBitness);
                break;
            default:
                throw new InvalidOperationException($"Unsupported parity mode '{modeInput}'.");
        }

        return new ParityRunResult
        {
            Mode = mode,
            RepoRoot = context.RepoRoot,
            ProjectPath = context.ProjectPath,
            BuildOutputPath = buildOutputPath,
            LabVIEWYear = context.LabVIEWYear,
            LvReleaseResolved = context.LvReleaseResolved,
            BuildSpecEnabled = buildSpecEnabled,
            ExitCode = 0
        };
    }

    private static void RunLinuxContainer(ParityContext context)
    {
        var selectedRelease = ResolveContainerRelease(context.LvReleaseResolved, "linux", context.RepoRoot);
        var containerYear = ResolveReleaseYear(selectedRelease, context.LabVIEWYear);
        var image = $"nationalinstruments/labview:{selectedRelease}-linux";
        Console.WriteLine($"Using image: {image}");
        Console.WriteLine($"Container parity LabVIEW year: {containerYear} (source .lvversion year: {context.LabVIEWYear})");

        var runArgs = new List<string>
        {
            "run",
            "--rm",
            "-v",
            $"{context.RepoRoot}:/workspace",
            "-e",
            "LVIE_REPO_ROOT=/workspace",
            "-e",
            "WORKSPACE_ROOT=/workspace",
            "-e",
            "REPO_ROOT=/workspace",
            "-e",
            $"LVIE_PROJECT_RELATIVE_PATH={ToUnixRelativePath(context.ProjectRelativePath)}",
            "-e",
            $"PROJECT_PATH_REL={ToUnixRelativePath(context.ProjectRelativePath)}",
            "-e",
            $"LVIE_PROJECT_PATH=/workspace/{ToUnixRelativePath(context.ProjectRelativePath)}",
            "-e",
            $"PROJECT_PATH=/workspace/{ToUnixRelativePath(context.ProjectRelativePath)}",
            "-e",
            $"TARGET_DIR_REL={ToUnixRelativePath(context.TargetDirRel)}",
            "-e",
            $"LV_YEAR={containerYear}",
            "-e",
            $"CONTAINER_PARITY_EXCLUDE_FILES={string.Join(';', context.ExcludeFiles)}",
            "-e",
            "CONTAINER_PARITY_BUILD_SPEC=true",
            "-e",
            $"CONTAINER_PARITY_BUILD_SPEC_NAME={context.BuildSpecName}",
            "-e",
            $"CONTAINER_PARITY_TARGET_NAME={context.TargetName}",
            "-e",
            $"CONTAINER_PARITY_BUILD_OUTPUT_RELATIVE_PATH={ToUnixRelativePath(context.BuildOutputRelativePath)}",
            "-e",
            $"CONTAINER_PARITY_LABVIEW_VERSION={containerYear}",
            image,
            "bash",
            "-lc",
            "chmod +x /workspace/Tooling/container-parity/runlabview-linux.sh && /workspace/Tooling/container-parity/runlabview-linux.sh"
        };

        RunProcess("docker", runArgs, context.RepoRoot);
        VerifyBuildOutput(context);
    }

    private static void RunWindowsContainer(ParityContext context)
    {
        if (!OperatingSystem.IsWindows())
        {
            throw new PlatformNotSupportedException("windows-container parity mode is only supported on Windows hosts.");
        }

        Console.WriteLine("Windows container parity script runs under powershell.exe (Windows PowerShell 5.1) inside the NI container.");
        RunProcess(
            "pwsh",
            new[]
            {
                "-NoProfile",
                "-File",
                Path.Combine(context.RepoRoot, "Tooling", "Test-PathContract.ps1"),
                "-WriteSummary"
            },
            context.RepoRoot);

        var selectedRelease = ResolveContainerRelease(context.LvReleaseResolved, "windows", context.RepoRoot);
        var containerYear = ResolveReleaseYear(selectedRelease, context.LabVIEWYear);
        var containerYearHint = EscapePwshSingleQuoted(containerYear);
        var image = $"nationalinstruments/labview:{selectedRelease}-windows";
        Console.WriteLine($"Using image: {image}");
        Console.WriteLine($"Container parity LabVIEW year: {containerYear} (source .lvversion year: {context.LabVIEWYear})");

        var runArgs = new List<string>
        {
            "run",
            "--rm",
            "-v",
            $"{context.RepoRoot}:C:\\workspace",
            "-e",
            "LVIE_REPO_ROOT=C:\\workspace",
            "-e",
            "WORKSPACE_ROOT=C:\\workspace",
            "-e",
            "REPO_ROOT=C:\\workspace",
            "-e",
            $"LVIE_PROJECT_RELATIVE_PATH={ToWindowsRelativePath(context.ProjectRelativePath)}",
            "-e",
            $"PROJECT_PATH_REL={ToWindowsRelativePath(context.ProjectRelativePath)}",
            "-e",
            $"LVIE_PROJECT_PATH=C:\\workspace\\{ToWindowsRelativePath(context.ProjectRelativePath)}",
            "-e",
            $"PROJECT_PATH=C:\\workspace\\{ToWindowsRelativePath(context.ProjectRelativePath)}",
            "-e",
            $"TARGET_DIR_REL={ToWindowsRelativePath(context.TargetDirRel)}",
            "-e",
            $"CONTAINER_PARITY_EXCLUDE_FILES={string.Join(';', context.ExcludeFiles)}",
            "-e",
            "CONTAINER_PARITY_BUILD_SPEC=true",
            "-e",
            $"CONTAINER_PARITY_BUILD_SPEC_NAME={context.BuildSpecName}",
            "-e",
            $"CONTAINER_PARITY_TARGET_NAME={context.TargetName}",
            "-e",
            $"CONTAINER_PARITY_BUILD_OUTPUT_RELATIVE_PATH={ToWindowsRelativePath(context.BuildOutputRelativePath)}",
            "-e",
            $"CONTAINER_PARITY_LABVIEW_VERSION={containerYear}",
            image,
            "powershell",
            "-NoProfile",
            "-Command",
            $"$ErrorActionPreference='Stop'; Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force; & 'C:\\workspace\\Tooling\\container-parity\\runlabview-windows.ps1' -LabVIEWVersion '{containerYearHint}'"
        };

        RunProcess("docker", runArgs, context.RepoRoot);
        VerifyBuildOutput(context);
    }

    private static void RunSelfHostedWindows(
        ParityContext context,
        string? labviewPathOverride,
        string labviewBitness)
    {
        if (!OperatingSystem.IsWindows())
        {
            throw new PlatformNotSupportedException("self-hosted-windows parity mode is only supported on Windows hosts.");
        }

        var bitness = string.IsNullOrWhiteSpace(labviewBitness) ? "64" : labviewBitness.Trim();
        if (!string.Equals(bitness, "32", StringComparison.Ordinal) &&
            !string.Equals(bitness, "64", StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Unsupported LabVIEW bitness '{labviewBitness}'. Use 32 or 64.");
        }

        var executionYear = ResolveSelfHostedExecutionYear(context);
        Console.WriteLine($"Self-hosted parity LabVIEW year: {executionYear} (source .lvversion year: {context.LabVIEWYear})");

        var labviewPath = string.IsNullOrWhiteSpace(labviewPathOverride)
            ? ResolveLabVIEWExecutablePath(context, bitness, executionYear)
            : Path.GetFullPath(labviewPathOverride);

        Console.WriteLine($"Using LabVIEW executable: {labviewPath}");
        if (!File.Exists(labviewPath))
        {
            throw new FileNotFoundException($"LabVIEW executable was not found: {labviewPath}", labviewPath);
        }

        var scriptPath = Path.Combine(context.RepoRoot, "Tooling", "container-parity", "runlabview-windows.ps1");
        if (!File.Exists(scriptPath))
        {
            throw new FileNotFoundException($"Self-hosted parity script was not found: {scriptPath}", scriptPath);
        }

        var args = new List<string>
        {
            "-NoProfile",
            "-File",
            scriptPath,
            "-WorkspaceRoot",
            context.RepoRoot,
            "-LabVIEWPath",
            labviewPath,
            "-ProjectPath",
            context.ProjectPath,
            "-BuildSpecName",
            context.BuildSpecName,
            "-TargetName",
            context.TargetName,
            "-LabVIEWVersion",
            executionYear,
            "-LabVIEWBitness",
            bitness
        };

        args.Add("-BuildProjectSpec");

        var parityEnvironment = BuildParityEnvironment(context, windowsStyle: true);
        parityEnvironment["CONTAINER_PARITY_LABVIEW_VERSION"] = executionYear;
        parityEnvironment["CONTAINER_PARITY_SOURCE_LABVIEW_VERSION"] = context.LabVIEWYear;
        parityEnvironment["CONTAINER_PARITY_LABVIEW_BITNESS"] = bitness;

        RunProcess(
            "pwsh",
            args,
            context.RepoRoot,
            parityEnvironment);

        VerifyBuildOutput(context);
    }

    private static void VerifyBuildOutput(ParityContext context)
    {
        var outputPath = ResolveRepoPath(context.RepoRoot, context.BuildOutputRelativePath);
        if (!File.Exists(outputPath))
        {
            throw new FileNotFoundException($"Build specification output was not found: {outputPath}", outputPath);
        }
    }

    private static Dictionary<string, string> BuildParityEnvironment(
        ParityContext context,
        bool windowsStyle)
    {
        var projectRelative = windowsStyle
            ? ToWindowsRelativePath(context.ProjectRelativePath)
            : ToUnixRelativePath(context.ProjectRelativePath);
        var targetDirRel = windowsStyle
            ? ToWindowsRelativePath(context.TargetDirRel)
            : ToUnixRelativePath(context.TargetDirRel);
        var buildOutputRel = windowsStyle
            ? ToWindowsRelativePath(context.BuildOutputRelativePath)
            : ToUnixRelativePath(context.BuildOutputRelativePath);

        return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["LVIE_REPO_ROOT"] = context.RepoRoot,
            ["WORKSPACE_ROOT"] = context.RepoRoot,
            ["REPO_ROOT"] = context.RepoRoot,
            ["LVIE_PROJECT_PATH"] = context.ProjectPath,
            ["PROJECT_PATH"] = context.ProjectPath,
            ["LVIE_PROJECT_RELATIVE_PATH"] = projectRelative,
            ["PROJECT_PATH_REL"] = projectRelative,
            ["TARGET_DIR_REL"] = targetDirRel,
            ["CONTAINER_PARITY_EXCLUDE_FILES"] = string.Join(';', context.ExcludeFiles),
            ["CONTAINER_PARITY_BUILD_SPEC"] = "true",
            ["CONTAINER_PARITY_BUILD_SPEC_NAME"] = context.BuildSpecName,
            ["CONTAINER_PARITY_TARGET_NAME"] = context.TargetName,
            ["CONTAINER_PARITY_BUILD_OUTPUT_RELATIVE_PATH"] = buildOutputRel,
            ["CONTAINER_PARITY_LABVIEW_VERSION"] = context.LabVIEWYear
        };
    }

    private static string ResolveSelfHostedExecutionYear(ParityContext context)
    {
        if (string.Equals(context.LabVIEWYear, "2020", StringComparison.Ordinal))
        {
            var mappedYear = ResolveReleaseYear(DefaultContainerFallbackRelease, context.LabVIEWYear);
            Console.WriteLine(
                $"Self-hosted parity compatibility mapping applied: source .lvversion year {context.LabVIEWYear} -> execution year {mappedYear}.");
            return mappedYear;
        }

        return context.LabVIEWYear;
    }

    private static string ResolveLabVIEWExecutablePath(ParityContext context, string bitness, string versionYear)
    {
        var scriptPath = Path.Combine(context.RepoRoot, "Tooling", "support", "LabVIEWExecutablePath.ps1");
        if (!File.Exists(scriptPath))
        {
            throw new FileNotFoundException($"LabVIEW executable path resolver was not found: {scriptPath}", scriptPath);
        }

        var command = $". '{EscapePwshSingleQuoted(scriptPath)}'; Resolve-LabVIEWExecutablePath -VersionYear '{EscapePwshSingleQuoted(versionYear)}' -Bitness '{EscapePwshSingleQuoted(bitness)}'";
        var result = RunProcess(
            "pwsh",
            new[] { "-NoProfile", "-Command", command },
            context.RepoRoot,
            throwOnError: true);

        var resolvedPath = result.StdOut
            .Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)
            .LastOrDefault();
        if (string.IsNullOrWhiteSpace(resolvedPath))
        {
            throw new InvalidOperationException("Failed to resolve LabVIEW executable path from Resolve-LabVIEWExecutablePath output.");
        }

        return Path.GetFullPath(resolvedPath.Trim());
    }

    private static string ResolveLvRelease(
        string? lvReleaseInput,
        string labviewYear,
        string defaultSuffix,
        string? parityModeHint)
    {
        var resolved = string.IsNullOrWhiteSpace(lvReleaseInput)
            ? $"{labviewYear}{(string.IsNullOrWhiteSpace(defaultSuffix) ? "q1" : defaultSuffix.Trim())}"
            : lvReleaseInput.Trim();

        var match = ReleaseYearRegex.Match(resolved);
        if (!match.Success)
        {
            throw new InvalidOperationException($"Invalid lv_release '{resolved}'. Expected format like '2020q1'.");
        }

        var releaseYear = match.Groups["year"].Value;
        var normalizedMode = string.IsNullOrWhiteSpace(parityModeHint)
            ? "self-hosted-windows"
            : NormalizeMode(parityModeHint);
        var enforceYearMatch = !string.Equals(normalizedMode, "linux-container", StringComparison.Ordinal) &&
                               !string.Equals(normalizedMode, "windows-container", StringComparison.Ordinal);
        if (enforceYearMatch && !string.Equals(releaseYear, labviewYear, StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                $".lvversion resolves to LabVIEW {labviewYear}, but lv_release is '{resolved}'. " +
                "Self-hosted parity lane requires matching year contracts.");
        }

        if (!enforceYearMatch && !string.Equals(releaseYear, labviewYear, StringComparison.Ordinal))
        {
            Console.WriteLine(
                $"Container parity context uses lv_release '{resolved}' (mode={normalizedMode}) " +
                $"with source .lvversion year {labviewYear}.");
        }

        return resolved;
    }

    private static string ResolveContractPath(string repoRoot, string? contractPathOverride)
    {
        if (!string.IsNullOrWhiteSpace(contractPathOverride))
        {
            return Path.GetFullPath(contractPathOverride);
        }

        return Path.GetFullPath(Path.Combine(repoRoot, "Tooling", "container-parity", "parity-contract.json"));
    }

    private static void ValidateContract(ParityContractDefinition contract, string contractPath)
    {
        if (string.IsNullOrWhiteSpace(contract.ProjectRelativePath))
            throw new InvalidOperationException($"project_relative_path is required in {contractPath}");
        if (string.IsNullOrWhiteSpace(contract.TargetDirRelativePath))
            throw new InvalidOperationException($"target_dir_relative_path is required in {contractPath}");
        if (string.IsNullOrWhiteSpace(contract.BuildOutputRelativePath))
            throw new InvalidOperationException($"build_output_relative_path is required in {contractPath}");
        if (string.IsNullOrWhiteSpace(contract.BuildSpecName))
            throw new InvalidOperationException($"build_spec_name is required in {contractPath}");
        if (string.IsNullOrWhiteSpace(contract.TargetName))
            throw new InvalidOperationException($"target_name is required in {contractPath}");
    }

    private static string NormalizeRelativePath(string value, string fieldName, string contractPath)
    {
        var trimmed = value.Trim();
        if (Path.IsPathRooted(trimmed))
        {
            throw new InvalidOperationException($"{fieldName} must be relative in {contractPath}: {trimmed}");
        }

        var normalized = trimmed.Replace('\\', '/').TrimStart('/');
        if (normalized.Split('/').Any(segment => string.Equals(segment, "..", StringComparison.Ordinal)))
        {
            throw new InvalidOperationException($"{fieldName} cannot contain '..' traversal in {contractPath}: {trimmed}");
        }

        if (string.IsNullOrWhiteSpace(normalized))
        {
            throw new InvalidOperationException($"{fieldName} cannot be empty in {contractPath}");
        }

        return normalized;
    }

    private static string ResolveRepoPath(string repoRoot, string relativePath)
    {
        var osRelativePath = relativePath
            .Replace('/', Path.DirectorySeparatorChar)
            .Replace('\\', Path.DirectorySeparatorChar);
        return Path.GetFullPath(Path.Combine(repoRoot, osRelativePath));
    }

    private static string ToUnixRelativePath(string relativePath) =>
        relativePath.Replace('\\', '/');

    private static string ToWindowsRelativePath(string relativePath) =>
        relativePath.Replace('/', '\\');

    private static string NormalizeMode(string modeInput)
    {
        var mode = (modeInput ?? string.Empty).Trim().ToLowerInvariant();
        return mode switch
        {
            "linux-container" => mode,
            "windows-container" => mode,
            "self-hosted-windows" => mode,
            _ => throw new InvalidOperationException(
                $"Unsupported parity mode '{modeInput}'. Supported modes: linux-container, windows-container, self-hosted-windows.")
        };
    }

    private static ProcessResult RunProcess(
        string fileName,
        IEnumerable<string> args,
        string workingDirectory,
        IDictionary<string, string>? environment = null,
        bool throwOnError = true)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            WorkingDirectory = workingDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        foreach (var arg in args)
        {
            psi.ArgumentList.Add(arg);
        }

        if (environment is not null)
        {
            foreach (var entry in environment)
            {
                psi.Environment[entry.Key] = entry.Value;
            }
        }

        using var process = Process.Start(psi);
        if (process is null)
        {
            throw new InvalidOperationException($"Failed to start process '{fileName}'.");
        }

        var stdOut = process.StandardOutput.ReadToEnd();
        var stdErr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (!string.IsNullOrWhiteSpace(stdOut))
        {
            Console.WriteLine(stdOut.TrimEnd());
        }
        if (!string.IsNullOrWhiteSpace(stdErr))
        {
            Console.Error.WriteLine(stdErr.TrimEnd());
        }

        if (throwOnError && process.ExitCode != 0)
        {
            throw new InvalidOperationException(
                $"Command '{fileName} {string.Join(' ', psi.ArgumentList)}' failed with exit code {process.ExitCode}.");
        }

        return new ProcessResult(process.ExitCode, stdOut, stdErr);
    }

    private static string ResolveContainerRelease(string requestedRelease, string osSuffix, string workingDirectory)
    {
        var fallbackRelease = Environment.GetEnvironmentVariable("LVIE_CONTAINER_PARITY_FALLBACK_RELEASE");
        if (string.IsNullOrWhiteSpace(fallbackRelease))
        {
            fallbackRelease = DefaultContainerFallbackRelease;
        }
        else
        {
            fallbackRelease = fallbackRelease.Trim();
        }

        var candidates = new List<string> { requestedRelease };
        if (!string.Equals(requestedRelease, fallbackRelease, StringComparison.OrdinalIgnoreCase))
        {
            candidates.Add(fallbackRelease);
        }

        var failures = new List<string>();
        foreach (var candidate in candidates)
        {
            var image = $"nationalinstruments/labview:{candidate}-{osSuffix}";
            var pullResult = RunProcess(
                "docker",
                new[] { "pull", image },
                workingDirectory,
                throwOnError: false);

            if (pullResult.ExitCode == 0)
            {
                if (!string.Equals(candidate, requestedRelease, StringComparison.OrdinalIgnoreCase))
                {
                    Console.Error.WriteLine(
                        $"WARNING: Requested container release '{requestedRelease}' is unavailable. Falling back to '{candidate}'.");
                }

                return candidate;
            }

            failures.Add($"{image} (exit={pullResult.ExitCode})");
        }

        throw new InvalidOperationException(
            $"Unable to pull LabVIEW container image for '{requestedRelease}'. Tried: {string.Join(", ", failures)}.");
    }

    private static string ResolveReleaseYear(string release, string defaultYear)
    {
        var match = ReleaseYearRegex.Match(release ?? string.Empty);
        return match.Success ? match.Groups["year"].Value : defaultYear;
    }

    private static string EscapePwshSingleQuoted(string input) =>
        input.Replace("'", "''", StringComparison.Ordinal);

    private readonly record struct ProcessResult(int ExitCode, string StdOut, string StdErr);
}
