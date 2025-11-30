using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using Xunit;

namespace OrchestrationCli.Tests;

public class CommandResultTests
{
    private static readonly string RepoRoot = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", ".."));

    [Fact]
    public void BindIncludesScriptPathAndLvVersion()
    {
        var args = new[]
        {
            "devmode-bind",
            "--repo", ".",
            "--bitness", "64",
            "--lv-version", "2021",
            "--pwsh", "pwsh"
        };

        // We don't actually run the script; just assert parse succeeds and JSON contains fields after serialization.
        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);
        Assert.NotNull(opts);

        var cmd = ProgramAccessor.RunBindUnbindForTest(opts!, "C:\\repo", "64", "bind");
        var json = JsonSerializer.Serialize(cmd);
        Assert.Contains("scripts\\\\bind-development-mode\\\\BindDevelopmentMode.ps1", json);
        Assert.Contains("\"lvVersion\":\"2021\"", json);
    }

    [Fact]
    public void ApplyDepsIncludesScriptPath()
    {
        var args = new[]
        {
            "apply-deps",
            "--repo", ".",
            "--bitness", "64",
            "--vipc-path", "runner_dependencies.vipc",
            "--pwsh", "pwsh"
        };

        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);
        Assert.NotNull(opts);

        var cmd = ProgramAccessor.RunApplyDepsForTest(opts!, Directory.GetCurrentDirectory(), "64");
        var json = JsonSerializer.Serialize(cmd);
        Assert.Contains("scripts\\\\task-verify-apply-dependencies.ps1", json);
    }

    [Fact]
    public void RestoreIncludesTokenFlagAndScript()
    {
        var args = new[]
        {
            "restore-sources",
            "--repo", ".",
            "--bitness", "64",
            "--lv-version", "2021",
            "--pwsh", "pwsh"
        };

        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);
        Assert.NotNull(opts);

        var cmd = ProgramAccessor.RunRestoreForTest(opts!, Directory.GetCurrentDirectory(), "64", tokenPresent: false);
        var json = JsonSerializer.Serialize(cmd);
        Assert.Contains("RestoreSetupLVSourceCore.vi", json);
        Assert.Contains("\"tokenPresent\":false", json);
    }

    [Fact]
    public void CloseIncludesClosedFlag()
    {
        var args = new[]
        {
            "labview-close",
            "--repo", ".",
            "--bitness", "64",
            "--lv-version", "2021",
            "--pwsh", "pwsh"
        };

        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);
        Assert.NotNull(opts);

        var cmd = ProgramAccessor.RunCloseLabVIEWForTest(opts!, Directory.GetCurrentDirectory(), "64");
        var json = JsonSerializer.Serialize(cmd);
        Assert.Contains("scripts\\\\close-labview\\\\Close_LabVIEW.ps1", json);
        Assert.Contains("\"closed\":true", json);
    }

    [Fact]
    public void ViAnalyzerIncludesRequestAndScript()
    {
        var args = new[]
        {
            "vi-analyzer",
            "--repo", ".",
            "--bitness", "64",
            "--request", "configs/vi-analyzer-request.sample.json",
            "--pwsh", "pwsh"
        };

        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);

        var cmd = ProgramAccessor.RunViAnalyzerForTest(opts!, Directory.GetCurrentDirectory(), "64");
        var json = JsonSerializer.Serialize(cmd);
        Assert.Contains("scripts\\\\vi-analyzer\\\\RunWithDevMode.ps1", json);
        Assert.Contains("vi-analyzer-request.sample.json", json);
    }

    [Fact]
    public void MissingCheckIncludesProjectAndScript()
    {
        var args = new[]
        {
            "missing-check",
            "--repo", ".",
            "--bitness", "64",
            "--project", "lv_icon_editor.lvproj",
            "--lv-version", "2021",
            "--pwsh", "pwsh"
        };

        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);

        var cmd = ProgramAccessor.RunMissingCheckForTest(opts!, Directory.GetCurrentDirectory(), "64");
        var json = JsonSerializer.Serialize(cmd);
        Assert.Contains("scripts\\\\missing-in-project\\\\RunMissingCheckWithGCLI.ps1", json);
        Assert.Contains("lv_icon_editor.lvproj", json);
    }

    [Fact]
    public void UnitTestsIncludesProjectAndScript()
    {
        var args = new[]
        {
            "unit-tests",
            "--repo", ".",
            "--bitness", "64",
            "--project", "lv_icon_editor.lvproj",
            "--lv-version", "2021",
            "--pwsh", "pwsh"
        };

        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);

        var cmd = ProgramAccessor.RunUnitTestsForTest(opts!, Directory.GetCurrentDirectory(), "64");
        var json = JsonSerializer.Serialize(cmd);
        Assert.Contains("scripts\\\\run-unit-tests\\\\RunUnitTests.ps1", json);
        Assert.Contains("lv_icon_editor.lvproj", json);
    }

    [Fact]
    public void ViCompareIncludesRequestAndScript()
    {
        var args = new[]
        {
            "vi-compare",
            "--repo", RepoRoot,
            "--bitness", "64",
            "--scenario", "scenarios/sample/vi-diff-requests.json",
            "--vipm-manifest", "configs/vipm-required.sample.json",
            "--skip-preflight",
            "--skip-worktree",
            "--pwsh", "pwsh"
        };

        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);

        var cmd = ProgramAccessor.RunViCompareForTest(opts!, RepoRoot, "64");
        var json = JsonSerializer.Serialize(cmd);
        Assert.Contains("tools\\\\icon-editor\\\\Replay-ViCompareScenario.ps1", json);
        Assert.Equal("success", cmd.Status);
    }

    [Fact]
    public void VipmInstallIncludesVipcPath()
    {
        var args = new[]
        {
            "vipm-install",
            "--repo", ".",
            "--bitness", "64",
            "--lv-version", "2021",
            "--vipc-path", "runner_dependencies.vipc"
        };

        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);

        var cmd = ProgramAccessor.RunVipmInstallForTest(opts!, Directory.GetCurrentDirectory(), "64");
        var json = JsonSerializer.Serialize(cmd);
        Assert.Contains("runner_dependencies.vipc", json);
    }

    [Fact]
    public void ViCompareFailsWhenVipbTooOld()
    {
        // VIPB in repo declares 25.x (2025); requesting 2026 should fail fast
        var args = new[]
        {
            "vi-compare",
            "--repo", RepoRoot,
            "--bitness", "64",
            "--lv-version", "2026",
            "--skip-preflight",
            "--skip-worktree",
            "--pwsh", "pwsh"
        };

        var (opts, error, help) = InvokeParse(args);
        Assert.False(help);
        Assert.Null(error);

        var cmd = ProgramAccessor.RunViCompareForTest(opts!, RepoRoot, "64", useFakeExit: false);
        var json = JsonSerializer.Serialize(cmd);
        Assert.Equal("fail", cmd.Status);
        Assert.Contains("VIPB Package_LabVIEW_Version", json);
    }

    private static (Program.Options? opts, string? error, bool help) InvokeParse(string[] args)
        => ProgramAccessor.InvokeParseArgs(args);
}
