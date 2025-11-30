using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using XCli.Tests.TestInfra;
using Xunit;

public class LabviewDevmodeToolchainScenarioTests
{
    private static ProcessRunner.CliResult Run(string sub, IDictionary<string, string>? env = null, params string[] payload)
        => ProcessRunner.RunAsync(sub, payload, env).GetAwaiter().GetResult();

    public LabviewDevmodeToolchainScenarioTests() => XCli.Util.Env.ResetCacheForTests();

    private static string LastRecordLine(string root)
    {
        var logDir = Path.Combine(root, "labview-devmode");
        var path = Path.Combine(logDir, "invocations.jsonl");
        Assert.True(File.Exists(path), $"Expected invocations log at '{path}'.");
        var lines = File.ReadAllLines(path);
        Assert.NotEmpty(lines);
        return lines[^1];
    }

    [Fact]
    public void GcliMissingScenarioSetsToolchainErrorAndFails()
    {
        var root = Path.Combine(Path.GetTempPath(), "xcli-devmode-gcli-" + Guid.NewGuid().ToString("n"));
        Directory.CreateDirectory(root);

        var env = new Dictionary<string, string>
        {
            { "XCLI_DEV_MODE_ROOT", root }
        };

        var r = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--script", "AddTokenToLabVIEW.ps1",
            "--scenario", "gcli-missing");

        Assert.Equal(1, r.ExitCode);
        Assert.Contains("g-cli not found", r.StdErr, StringComparison.OrdinalIgnoreCase);

        var line = LastRecordLine(root);
        using var doc = JsonDocument.Parse(line);
        var rec = doc.RootElement;
        Assert.Equal(1, rec.GetProperty("ExitCode").GetInt32());
        Assert.True(rec.GetProperty("ToolchainError").GetBoolean());
        Assert.Equal("gcli-missing", rec.GetProperty("ToolchainErrorDetail").GetString());
    }

    [Fact]
    public void LvVersionUnsupportedScenarioSetsToolchainErrorAndFails()
    {
        var root = Path.Combine(Path.GetTempPath(), "xcli-devmode-lvver-" + Guid.NewGuid().ToString("n"));
        Directory.CreateDirectory(root);

        var env = new Dictionary<string, string>
        {
            { "XCLI_DEV_MODE_ROOT", root }
        };

        var r = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2020",
            "--script", "AddTokenToLabVIEW.ps1",
            "--scenario", "lv-version-unsupported");

        Assert.Equal(1, r.ExitCode);
        Assert.Contains("version '2020' is not supported", r.StdErr, StringComparison.OrdinalIgnoreCase);

        var line = LastRecordLine(root);
        using var doc = JsonDocument.Parse(line);
        var rec = doc.RootElement;
        Assert.Equal(1, rec.GetProperty("ExitCode").GetInt32());
        Assert.True(rec.GetProperty("ToolchainError").GetBoolean());
        Assert.Equal("lv-version-unsupported", rec.GetProperty("ToolchainErrorDetail").GetString());
    }

    [Fact]
    public void ArchMismatchScenarioSetsToolchainErrorAndFails()
    {
        var root = Path.Combine(Path.GetTempPath(), "xcli-devmode-arch-" + Guid.NewGuid().ToString("n"));
        Directory.CreateDirectory(root);

        var env = new Dictionary<string, string>
        {
            { "XCLI_DEV_MODE_ROOT", root }
        };

        var r = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2026",
            "--bitness", "32",
            "--script", "AddTokenToLabVIEW.ps1",
            "--scenario", "arch-mismatch");

        Assert.Equal(1, r.ExitCode);
        Assert.Contains("requested architecture '32'", r.StdErr, StringComparison.OrdinalIgnoreCase);

        var line = LastRecordLine(root);
        using var doc = JsonDocument.Parse(line);
        var rec = doc.RootElement;
        Assert.Equal(1, rec.GetProperty("ExitCode").GetInt32());
        Assert.True(rec.GetProperty("ToolchainError").GetBoolean());
        Assert.Equal("arch-mismatch", rec.GetProperty("ToolchainErrorDetail").GetString());
    }
}

