using System;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace XCli.Labview;

/// <summary>
/// Helpers for recording LabVIEW dev-mode invocations in a canonical JSONL format.
/// </summary>
public static class LabviewDevmodeCommand
{
    private sealed class ScenarioOverride
    {
        public int? ExitCode { get; init; }
        public bool? Success { get; init; }
        public string[]? StderrLines { get; init; }
    }

    private sealed class MatrixOverride
    {
        public string[]? Degraded { get; init; }
        public string[]? Succeeded { get; init; }
    }

    private sealed class ScenarioConfig
    {
        public System.Collections.Generic.Dictionary<string, ScenarioOverride>? Scenarios { get; init; }
        public MatrixOverride? Matrix { get; init; }
    }

    private sealed record DevmodeRecord(
        string Kind,
        string Mode,
        string? LvaddonRoot,
        string? Script,
        string? LvVersion,
        string? Bitness,
        string? Operation,
        string[] Args,
        string? RunId,
        int ExitCode,
        bool ConfigError,
        string? ConfigErrorDetail,
        bool ResourceError,
        string? ResourceErrorDetail,
        bool ToolchainError,
        string? ToolchainErrorDetail,
        string? Scenario
    );

    private static ScenarioConfig? _scenarioConfig;
    private static bool _scenarioConfigLoaded;
    private static bool _scenarioConfigError;
    private static string? _scenarioConfigErrorDetail;

    private static string? ValidateLocalHostRequirement(string? repoRoot)
    {
        var requiredPath = XCli.Util.Env.Get("XCLI_LOCALHOST_REQUIRED_PATH");
        if (string.IsNullOrWhiteSpace(requiredPath))
        {
            requiredPath = repoRoot;
        }
        if (string.IsNullOrWhiteSpace(requiredPath))
        {
            return null;
        }

        var iniPath = XCli.Util.Env.Get("XCLI_LABVIEW_INI_PATH");
        if (string.IsNullOrWhiteSpace(iniPath))
        {
            return "LocalHost.LibraryPaths enforcement requires XCLI_LABVIEW_INI_PATH.";
        }
        if (!File.Exists(iniPath))
        {
            return $"LabVIEW.ini not found at '{iniPath}'.";
        }

        static string NormalizePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return string.Empty;
            try
            {
                return Path.GetFullPath(path).TrimEnd('\\', '/');
            }
            catch
            {
                return path.Trim().TrimEnd('\\', '/');
            }
        }

        var requiredNormalized = NormalizePath(requiredPath);
        var lines = File.ReadAllLines(iniPath);
        var entry = lines.FirstOrDefault(l => l.TrimStart()
            .StartsWith("LocalHost.LibraryPaths", StringComparison.OrdinalIgnoreCase));
        if (entry == null)
        {
            return "LocalHost.LibraryPaths entry not found in LabVIEW.ini.";
        }

        var idx = entry.IndexOf('=');
        if (idx < 0)
        {
            return "LocalHost.LibraryPaths entry in LabVIEW.ini is malformed.";
        }

        var value = entry.Substring(idx + 1);
        var paths = value.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var match = paths.Any(p => NormalizePath(p.Trim('"'))
            .Equals(requiredNormalized, StringComparison.OrdinalIgnoreCase));
        if (!match)
        {
            return $"LocalHost.LibraryPaths missing required path '{requiredNormalized}'.";
        }

        return null;
    }

    private static ScenarioConfig? GetScenarioConfig()
    {
        if (_scenarioConfigLoaded)
            return _scenarioConfig;

        _scenarioConfigLoaded = true;
        _scenarioConfigError = false;
        _scenarioConfigErrorDetail = null;

        var path = XCli.Util.Env.Get("XCLI_LVDEVMODE_CONFIG_PATH");
        if (string.IsNullOrWhiteSpace(path))
        {
            _scenarioConfig = null;
            return _scenarioConfig;
        }

        try
        {
            if (!System.IO.File.Exists(path))
            {
                _scenarioConfigError = true;
                _scenarioConfigErrorDetail = "file-not-found";
                Console.Error.WriteLine($"lvdevmode-config: file not found '{path}'");
                _scenarioConfig = null;
                return _scenarioConfig;
            }

            var json = System.IO.File.ReadAllText(path);
            var cfg = JsonSerializer.Deserialize<ScenarioConfig>(
                json,
                new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });
            if (cfg is null)
            {
                _scenarioConfigError = true;
                _scenarioConfigErrorDetail = "invalid-json";
                Console.Error.WriteLine($"lvdevmode-config: invalid JSON in '{path}' (null root).");
                _scenarioConfig = null;
            }
            else
            {
                _scenarioConfig = cfg;
            }
        }
        catch (System.Text.Json.JsonException ex)
        {
            _scenarioConfigError = true;
            _scenarioConfigErrorDetail = "invalid-json";
            Console.Error.WriteLine($"lvdevmode-config: invalid JSON in '{path}': {ex.Message}");
            _scenarioConfig = null;
        }
        catch (System.IO.IOException ex)
        {
            _scenarioConfigError = true;
            _scenarioConfigErrorDetail = "io-error";
            Console.Error.WriteLine($"lvdevmode-config: error loading '{path}': {ex.Message}");
            _scenarioConfig = null;
        }
        catch (System.UnauthorizedAccessException ex)
        {
            _scenarioConfigError = true;
            _scenarioConfigErrorDetail = "io-error";
            Console.Error.WriteLine($"lvdevmode-config: error loading '{path}': {ex.Message}");
            _scenarioConfig = null;
        }

        return _scenarioConfig;
    }

    private static bool TryApplyScenarioOverride(
        string canonicalName,
        string stage,
        string opTag,
        ref bool success,
        ref int exitCode)
    {
        var cfg = GetScenarioConfig();
        var scenarios = cfg?.Scenarios;
        if (scenarios == null || !scenarios.TryGetValue(canonicalName, out var ov) || ov == null)
            return false;

        if (ov.StderrLines != null)
        {
            foreach (var raw in ov.StderrLines)
            {
                if (raw == null)
                    continue;
                var line = raw
                    .Replace("{stage}", stage ?? string.Empty)
                    .Replace("{opTag}", opTag ?? string.Empty);
                Console.Error.WriteLine(line);
            }
        }

        if (ov.ExitCode.HasValue)
            exitCode = ov.ExitCode.Value;
        if (ov.Success.HasValue)
            success = ov.Success.Value;
        else
            success = exitCode == 0;

        return true;
    }

    private static bool TryApplyMatrixOverride(
        string? lvVersion,
        string? bitness,
        string stage,
        ref bool success,
        ref int exitCode)
    {
        var cfg = GetScenarioConfig();
        var matrix = cfg?.Matrix;
        if (matrix == null)
            return false;

        var key = string.Concat(lvVersion ?? string.Empty, "-", bitness ?? string.Empty);

        bool IsMatch(string[]? arr) =>
            arr != null && System.Array.Exists(arr, v => string.Equals(v, key, System.StringComparison.OrdinalIgnoreCase));

        if (IsMatch(matrix.Degraded))
        {
            Console.Error.WriteLine($"[x-cli] labview-devmode: partial failure for stage '{stage}' on {key} (config, simulated, recoverable).");
            success = false;
            exitCode = 2;
            return true;
        }

        if (IsMatch(matrix.Succeeded))
        {
            Console.Error.WriteLine($"[x-cli] labview-devmode: success for stage '{stage}' on {key} (config, simulated).");
            success = true;
            exitCode = 0;
            return true;
        }

        return false;
    }

    public static XCli.Simulation.SimulationResult Run(string subcommand, string[] payloadArgs)
    {
        var mode = subcommand == "labview-devmode-enable" ? "enable" : "disable";

        string? lvaddonRoot = null;
        string? script = null;
        string? lvVersion = null;
        string? bitness = null;
        string? operation = null;
        string? scenario = null;
        string? argsJson = null;
        string? runId = null;

        for (var i = 0; i < payloadArgs.Length; i++)
        {
            var arg = payloadArgs[i];
            if (arg == "--lvaddon-root" && i + 1 < payloadArgs.Length)
                lvaddonRoot = payloadArgs[++i];
            else if (arg == "--script" && i + 1 < payloadArgs.Length)
                script = payloadArgs[++i];
            else if (arg == "--lv-version" && i + 1 < payloadArgs.Length)
                lvVersion = payloadArgs[++i];
            else if (arg == "--bitness" && i + 1 < payloadArgs.Length)
                bitness = payloadArgs[++i];
            else if (arg == "--operation" && i + 1 < payloadArgs.Length)
                operation = payloadArgs[++i];
            else if (arg == "--args-json" && i + 1 < payloadArgs.Length)
                argsJson = payloadArgs[++i];
            else if (arg == "--scenario" && i + 1 < payloadArgs.Length)
                scenario = payloadArgs[++i];
            else if (arg == "--run-id" && i + 1 < payloadArgs.Length)
                runId = payloadArgs[++i];
        }

        string[] args = System.Array.Empty<string>();
        if (!string.IsNullOrWhiteSpace(argsJson))
        {
            try
            {
                args = JsonSerializer.Deserialize<string[]>(argsJson!) ?? System.Array.Empty<string>();
            }
            catch
            {
                // leave args empty but continue recording the raw fields
            }
        }

        var root = XCli.Util.Env.Get("XCLI_DEV_MODE_ROOT");
        if (string.IsNullOrWhiteSpace(root))
        {
            root = System.IO.Path.Combine(System.Environment.CurrentDirectory, "temp_telemetry");
        }

        var logDir = System.IO.Path.Combine(root!, "labview-devmode");
        System.IO.Directory.CreateDirectory(logDir);

        var scenarioKey = scenario?.ToLowerInvariant() ?? "happy-path";
        var success = true;
        var exitCode = 0;
        var resourceError = false;
        string? resourceErrorDetail = null;
        var toolchainError = false;
        string? toolchainErrorDetail = null;

        var stage = string.IsNullOrWhiteSpace(operation) ? "dev-mode" : operation;
        var opTag = string.IsNullOrWhiteSpace(operation) ? string.Empty : $" [{operation}]";

        var localhostError = ValidateLocalHostRequirement(lvaddonRoot);
        if (localhostError != null)
        {
            Console.Error.WriteLine($"[x-cli] labview-devmode: {localhostError}");
            return new XCli.Simulation.SimulationResult(false, 1);
        }

        var handledByScenarioConfig = false;
        if (TryApplyScenarioOverride(scenarioKey, stage, opTag, ref success, ref exitCode))
        {
            handledByScenarioConfig = true;
        }

        // Combined behaviors: timeout + rogue diagnostics.
        if (!handledByScenarioConfig && (scenarioKey.Contains("timeout+rogue") || scenarioKey.Contains("rogue+timeout")))
        {
            Console.Error.WriteLine($"Error:{opTag} No connection established with application.");
            Console.Error.WriteLine("Caused by: Timed out waiting for app to connect to g-cli");
            var rogueMsg = $"Rogue LabVIEW processes detected during stage '{stage}'. See temp_telemetry/labview-devmode/rogue-sim.log for details.";
            Console.Error.WriteLine(rogueMsg);
            success = false;
            exitCode = 1;
        }
        // Combined behaviors: partial failure plus a soft timeout hint.
        else if (!handledByScenarioConfig && (scenarioKey.Contains("partial+timeout-soft") || scenarioKey.Contains("timeout-soft+partial")))
        {
            Console.Error.WriteLine($"[x-cli] labview-devmode: partial failure for stage '{stage}' (simulated, recoverable).");
            Console.Error.WriteLine($"Warning:{opTag} Soft timeout while communicating with application (simulated).");
            Console.Error.WriteLine("Caused by: Timed out waiting for app to connect to g-cli (soft)");
            success = false;
            exitCode = 2;
        }
        // Version/bitness matrix: partial only for 2026/32, success for 2025/64.
        else if (!handledByScenarioConfig && scenarioKey.Contains("matrix"))
        {
            if (!TryApplyMatrixOverride(lvVersion, bitness, stage, ref success, ref exitCode))
            {
                var is2026x32 = string.Equals(lvVersion, "2026", System.StringComparison.OrdinalIgnoreCase)
                                && string.Equals(bitness, "32", System.StringComparison.OrdinalIgnoreCase);
                var is2025x64 = string.Equals(lvVersion, "2025", System.StringComparison.OrdinalIgnoreCase)
                                && string.Equals(bitness, "64", System.StringComparison.OrdinalIgnoreCase);

                if (is2026x32)
                {
                    Console.Error.WriteLine($"[x-cli] labview-devmode: partial failure for stage '{stage}' on 2026 x32 (simulated, recoverable).");
                    success = false;
                    exitCode = 2;
                }
                else if (is2025x64)
                {
                    Console.Error.WriteLine($"[x-cli] labview-devmode: success for stage '{stage}' on 2025 x64 (simulated).");
                    success = true;
                    exitCode = 0;
                }
                else
                {
                    Console.Error.WriteLine($"[x-cli] labview-devmode: unsupported matrix combination '{lvVersion}-{bitness}' for stage '{stage}' (simulated failure).");
                    success = false;
                    exitCode = 1;
                }
            }
        }
        // Retry-then-succeed: first invocation for a given RunId fails, subsequent succeed.
        else if (!handledByScenarioConfig && scenarioKey.Contains("retry-success"))
        {
            var runKey = string.IsNullOrWhiteSpace(runId) ? "default" : runId!;
            var retryStatePath = System.IO.Path.Combine(root!, "labview-devmode", $"retry-{runKey}.txt");
            int attempt = 0;
            try
            {
                if (System.IO.File.Exists(retryStatePath))
                {
                    var raw = System.IO.File.ReadAllText(retryStatePath).Trim();
                    _ = int.TryParse(raw, out attempt);
                }
            }
            catch
            {
                // ignore state read issues, treat as first attempt
                attempt = 0;
            }

            attempt++;
            try
            {
                System.IO.File.WriteAllText(retryStatePath, attempt.ToString());
            }
            catch
            {
                // ignore state write issues
            }

            if (attempt == 1)
            {
                Console.Error.WriteLine($"Error:{opTag} No connection established with application (retry 1, simulated).");
                Console.Error.WriteLine("Caused by: Timed out waiting for app to connect to g-cli");
                success = false;
                exitCode = 1;
            }
            else
            {
                Console.Error.WriteLine($"[x-cli] labview-devmode: retry-success for stage '{stage}' on attempt {attempt} (simulated).");
                success = true;
                exitCode = 0;
            }
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("timeout-soft"))
        {
            Console.Error.WriteLine($"Warning:{opTag} Soft timeout while communicating with application (simulated).");
            Console.Error.WriteLine("Caused by: Timed out waiting for app to connect to g-cli (soft)");
            success = true;
            exitCode = 0;
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("timeout"))
        {
            Console.Error.WriteLine($"Error:{opTag} No connection established with application.");
            Console.Error.WriteLine("Caused by: Timed out waiting for app to connect to g-cli");
            success = false;
            exitCode = 1;
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("rogue"))
        {
            var rogueMsg = $"Rogue LabVIEW processes detected during stage '{stage}'. See temp_telemetry/labview-devmode/rogue-sim.log for details.";
            Console.Error.WriteLine(rogueMsg);
            success = false;
            exitCode = 1;
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("partial"))
        {
            Console.Error.WriteLine($"[x-cli] labview-devmode: partial failure for stage '{stage}' (simulated, recoverable).");
            success = false;
            exitCode = 2;
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("noisy"))
        {
            Console.Error.WriteLine($"[x-cli] labview-devmode: simulated noisy stderr for stage '{stage}'.");
            success = true;
            exitCode = 0;
        }
        else if (!handledByScenarioConfig && (scenarioKey.Contains("abort") || scenarioKey.Contains("ctrlc") || scenarioKey.Contains("cancel")))
        {
            Console.Error.WriteLine($"[x-cli] labview-devmode: operation aborted by user during stage '{stage}' (simulated Ctrl-C).");
            success = false;
            exitCode = 130;
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("disk-full"))
        {
            Console.Error.WriteLine($"Error:{opTag} failed to write LabVIEW output to disk (simulated disk full).");
            Console.Error.WriteLine("[x-cli] labview-devmode: resource error 'disk-full' during dev-mode stage.");
            success = false;
            exitCode = 1;
            resourceError = true;
            resourceErrorDetail = "disk-full";
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("log-write-fail"))
        {
            Console.Error.WriteLine($"Warning:{opTag} failed to write x-cli devmode log (simulated).");
            Console.Error.WriteLine("[x-cli] labview-devmode: resource warning 'log-write-fail' during dev-mode stage (operation succeeded).");
            success = true;
            exitCode = 0;
            resourceError = true;
            resourceErrorDetail = "log-write-fail";
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("temp-missing"))
        {
            Console.Error.WriteLine($"Error:{opTag} temp directory for dev-mode logs is missing or cannot be created (simulated).");
            Console.Error.WriteLine("[x-cli] labview-devmode: resource error 'temp-missing' during dev-mode stage.");
            success = false;
            exitCode = 1;
            resourceError = true;
            resourceErrorDetail = "temp-missing";
        }
        else if (!handledByScenarioConfig && (scenarioKey.Contains("gcli-missing") || scenarioKey.Contains("g-cli-missing")))
        {
            Console.Error.WriteLine("[x-cli] labview-devmode: g-cli not found on PATH (simulated).");
            success = false;
            exitCode = 1;
            toolchainError = true;
            toolchainErrorDetail = "gcli-missing";
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("lv-version-unsupported"))
        {
            var ver = string.IsNullOrWhiteSpace(lvVersion) ? "<unknown>" : lvVersion;
            Console.Error.WriteLine($"Error:{opTag} requested LabVIEW version '{ver}' is not supported by this toolchain (simulated).");
            success = false;
            exitCode = 1;
            toolchainError = true;
            toolchainErrorDetail = "lv-version-unsupported";
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("arch-mismatch"))
        {
            var ver = string.IsNullOrWhiteSpace(lvVersion) ? "<unknown>" : lvVersion;
            var arch = string.IsNullOrWhiteSpace(bitness) ? "<unknown>" : bitness;
            Console.Error.WriteLine($"Error:{opTag} requested architecture '{arch}' is not available for LabVIEW {ver} (simulated).");
            success = false;
            exitCode = 1;
            toolchainError = true;
            toolchainErrorDetail = "arch-mismatch";
        }
        else if (!handledByScenarioConfig && scenarioKey.Contains("fail"))
        {
            Console.Error.WriteLine($"[x-cli] labview-devmode: failure in stage '{stage}' (simulated)");
            success = false;
            exitCode = 1;
        }

        var record = new DevmodeRecord(
            Kind: "labview-devmode",
            Mode: mode,
            LvaddonRoot: lvaddonRoot,
            Script: script,
            LvVersion: lvVersion,
            Bitness: bitness,
            Operation: operation,
            Args: args,
            RunId: runId,
            ExitCode: exitCode,
            ConfigError: _scenarioConfigError,
            ConfigErrorDetail: _scenarioConfigErrorDetail,
            ResourceError: resourceError,
            ResourceErrorDetail: resourceErrorDetail,
            ToolchainError: toolchainError,
            ToolchainErrorDetail: toolchainErrorDetail,
            Scenario: scenarioKey
        );

        var logPath = System.IO.Path.Combine(logDir, "invocations.jsonl");
        var line = JsonSerializer.Serialize(record);
        System.IO.File.AppendAllText(logPath, line + System.Environment.NewLine);

        return new XCli.Simulation.SimulationResult(success, exitCode);
    }
}
