// ModuleIndex: local-ci handshake simulation command.
using System.Text.Json;
using XCli.Simulation;

namespace XCli.Localci;

public static class LocalciHandshakeCommand
{
    private sealed record HandshakeSummary(
        string Schema,
        string Runner,
        string Scenario,
        string UbuntuManifestPath,
        string WindowsRunRoot,
        string? UbuntuRunId,
        string? UbuntuCreatedUtc,
        string? UbuntuCoveragePercent,
        string? UbuntuCommit
    );

    public static SimulationResult Run(string[] args)
    {
        var manifestPath = GetOption(args, "--ubuntu-manifest");
        var windowsRunRoot = GetOption(args, "--windows-run-root");
        var scenario = GetOption(args, "--scenario") ?? "ok";

        if (string.IsNullOrWhiteSpace(manifestPath))
        {
            Console.Error.WriteLine("[localci-handshake] --ubuntu-manifest is required.");
            return new SimulationResult(false, 1);
        }

        if (string.IsNullOrWhiteSpace(windowsRunRoot))
        {
            Console.Error.WriteLine("[localci-handshake] --windows-run-root is required.");
            return new SimulationResult(false, 1);
        }

        manifestPath = Path.GetFullPath(manifestPath);
        windowsRunRoot = Path.GetFullPath(windowsRunRoot);

        if (!File.Exists(manifestPath))
        {
            Console.Error.WriteLine($"[localci-handshake] Ubuntu manifest not found at '{manifestPath}'.");
            return new SimulationResult(false, 1);
        }

        string? runId = null;
        string? createdUtc = null;
        string? coveragePercent = null;
        string? commit = null;

        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(manifestPath));
            var root = doc.RootElement;

            if (root.TryGetProperty("run_id", out var runIdElem) && runIdElem.ValueKind == JsonValueKind.String)
            {
                runId = runIdElem.GetString();
            }

            if (root.TryGetProperty("created_utc", out var createdElem) && createdElem.ValueKind == JsonValueKind.String)
            {
                createdUtc = createdElem.GetString();
            }

            if (root.TryGetProperty("git", out var gitElem) &&
                gitElem.ValueKind == JsonValueKind.Object &&
                gitElem.TryGetProperty("commit", out var commitElem) &&
                commitElem.ValueKind == JsonValueKind.String)
            {
                commit = commitElem.GetString();
            }

            if (root.TryGetProperty("coverage", out var covElem) &&
                covElem.ValueKind == JsonValueKind.Object &&
                covElem.TryGetProperty("percent", out var percentElem) &&
                percentElem.ValueKind == JsonValueKind.Number)
            {
                coveragePercent = percentElem.GetRawText();
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[localci-handshake] Failed to parse Ubuntu manifest '{manifestPath}': {ex.Message}");
            return new SimulationResult(false, 1);
        }

        try
        {
            Directory.CreateDirectory(windowsRunRoot);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[localci-handshake] Failed to create Windows run root '{windowsRunRoot}': {ex.Message}");
            return new SimulationResult(false, 1);
        }

        var summary = new HandshakeSummary(
            Schema: "localci/windows-run@v1",
            Runner: "XCliSim",
            Scenario: scenario,
            UbuntuManifestPath: manifestPath,
            WindowsRunRoot: windowsRunRoot,
            UbuntuRunId: runId,
            UbuntuCreatedUtc: createdUtc,
            UbuntuCoveragePercent: coveragePercent,
            UbuntuCommit: commit
        );

        var summaryPath = Path.Combine(windowsRunRoot, "handshake-sim.json");
        try
        {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(summary, options);
            File.WriteAllText(summaryPath, json);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[localci-handshake] Failed to write handshake summary '{summaryPath}': {ex.Message}");
            return new SimulationResult(false, 1);
        }

        // Emit a minimal vi-compare summary so the path can be exercised end-to-end.
        var viDir = Path.Combine(windowsRunRoot, "vi-comparison");
        try
        {
            Directory.CreateDirectory(viDir);
            var viSummary = new
            {
                schema = "icon-editor/vi-diff-summary@v1",
                generatedAt = DateTime.UtcNow.ToString("o"),
                counts = new
                {
                    total = 0,
                    compared = 0,
                    same = 0,
                    different = 0
                },
                requests = Array.Empty<object>()
            };
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(viSummary, options);
            File.WriteAllText(Path.Combine(viDir, "vi-comparison-summary.json"), json);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[localci-handshake] Failed to write vi-comparison summary: {ex.Message}");
            return new SimulationResult(false, 1);
        }

        Console.WriteLine($"[localci-handshake] Simulated Windows run at '{windowsRunRoot}' for scenario '{scenario}'.");
        return new SimulationResult(true, 0);
    }

    private static string? GetOption(string[] args, string name)
    {
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == name && i + 1 < args.Length)
            {
                return args[i + 1];
            }
        }

        return null;
    }
}

