using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using XCli.Tests.TestInfra;
using Xunit;

public class LabviewDevmodeResourceScenarioTests
{
    private static ProcessRunner.CliResult Run(string sub, IDictionary<string, string>? env = null, params string[] payload)
        => ProcessRunner.RunAsync(sub, payload, env).GetAwaiter().GetResult();

    public LabviewDevmodeResourceScenarioTests() => XCli.Util.Env.ResetCacheForTests();

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
    public void DiskFullScenarioSetsResourceErrorAndFails()
    {
        var root = Path.Combine(Path.GetTempPath(), "xcli-devmode-diskfull-" + Guid.NewGuid().ToString("n"));
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
            "--scenario", "disk-full");

        Assert.Equal(1, r.ExitCode);
        Assert.Contains("disk full", r.StdErr, StringComparison.OrdinalIgnoreCase);

        var line = LastRecordLine(root);
        using var doc = JsonDocument.Parse(line);
        var rec = doc.RootElement;
        Assert.Equal(1, rec.GetProperty("ExitCode").GetInt32());
        Assert.True(rec.GetProperty("ResourceError").GetBoolean());
        Assert.Equal("disk-full", rec.GetProperty("ResourceErrorDetail").GetString());
    }

    [Fact]
    public void LogWriteFailScenarioMarksResourceErrorButSucceeds()
    {
        var root = Path.Combine(Path.GetTempPath(), "xcli-devmode-logfail-" + Guid.NewGuid().ToString("n"));
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
            "--scenario", "log-write-fail");

        Assert.Equal(0, r.ExitCode);
        Assert.Contains("log", r.StdErr, StringComparison.OrdinalIgnoreCase);

        var line = LastRecordLine(root);
        using var doc = JsonDocument.Parse(line);
        var rec = doc.RootElement;
        Assert.Equal(0, rec.GetProperty("ExitCode").GetInt32());
        Assert.True(rec.GetProperty("ResourceError").GetBoolean());
        Assert.Equal("log-write-fail", rec.GetProperty("ResourceErrorDetail").GetString());
    }

    [Fact]
    public void TempMissingScenarioSetsResourceErrorAndFails()
    {
        var root = Path.Combine(Path.GetTempPath(), "xcli-devmode-tempmissing-" + Guid.NewGuid().ToString("n"));
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
            "--scenario", "temp-missing");

        Assert.Equal(1, r.ExitCode);
        Assert.Contains("temp directory", r.StdErr, StringComparison.OrdinalIgnoreCase);

        var line = LastRecordLine(root);
        using var doc = JsonDocument.Parse(line);
        var rec = doc.RootElement;
        Assert.Equal(1, rec.GetProperty("ExitCode").GetInt32());
        Assert.True(rec.GetProperty("ResourceError").GetBoolean());
        Assert.Equal("temp-missing", rec.GetProperty("ResourceErrorDetail").GetString());
    }
}
