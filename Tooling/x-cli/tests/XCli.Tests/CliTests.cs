using XCli.Cli;
using XCli.Util;
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using TestUtil;
using Xunit;

// FGC-REQ-QA-001
public class CliTests
{
    private static string N(string s) => s.Replace("\r", string.Empty);
    private static string ProjectDir => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../src/XCli"));
    private static string BuildConfig => new DirectoryInfo(AppContext.BaseDirectory).Parent!.Name;
    private static string Rid =>
        OperatingSystem.IsWindows() ? "win-x64" :
        OperatingSystem.IsMacOS() ?
            (RuntimeInformation.ProcessArchitecture == Architecture.Arm64 ? "osx-arm64" : "osx-x64") :
        "linux-x64";
    private static ProcRunner.Result Run(string args) =>
        ProcRunner.Run("dotnet", $"run --no-build -c Release -- {args}", null, ProjectDir);

    [Fact]
    public void EnvGetProcessNameMatchesEnvironment()
    {
        string expected;
        try
        {
            var raw = File.ReadAllBytes("/proc/self/cmdline");
            var idx = Array.IndexOf(raw, (byte)0);
            expected = idx > 0 ? Path.GetFileName(System.Text.Encoding.UTF8.GetString(raw, 0, idx)) : string.Empty;
        }
        catch
        {
            expected = Path.GetFileName(Environment.GetCommandLineArgs()[0]);
        }
        Assert.Equal(expected, Env.GetProcessName());
    }

    // FGC-REQ-CLI-002
    [Fact]
    public void HelpListsSubcommandsRuleAndGlobals()
    {
        var r = Run("--help");
        Assert.Equal(0, r.ExitCode);
        var usageLine = N(r.StdOut).Split('\n').First();
        Assert.Matches(@"^Usage: \S+ <subcommand> \[payload-args...\]$", usageLine);
        foreach (var sub in Cli.Subcommands)
            Assert.Contains(sub, r.StdOut);
        Assert.Contains("--help                print usage and exit", r.StdOut);
        Assert.Contains("--version             print the semantic version and exit", r.StdOut);
        Assert.Contains("Rule: tokens after the subcommand are passed through unchanged.", r.StdOut);
        Assert.DoesNotContain("Use -- to pass args without a subcommand", r.StdOut);
        Assert.Contains("Global options:", r.StdOut);
        Assert.Equal(1, r.StdOut.Split("Global options:").Length - 1);
    }

    // FGC-REQ-CLI-002
    [Fact]
    public void HelpIncludesEnvironmentVariablesAndLogFields()
    {
        var r = Run("--help");
        Assert.Contains("Environment variables (case-insensitive; logged with original casing):", r.StdOut);
        foreach (var name in new[]
            {
                "XCLI_FAIL",
                "XCLI_FAIL_ON",
                "XCLI_EXIT_CODE",
                "XCLI_MESSAGE",
                "XCLI_DELAY_MS",
                "XCLI_MAX_DURATION_MS",
                "XCLI_CONFIG_PATH",
                "XCLI_LOG_PATH",
                "XCLI_LOG_TIMEOUT_MS",
                "XCLI_LOG_MAX_ATTEMPTS",
                "XCLI_DEBUG"
            })
                Assert.Contains(name, r.StdOut);
        Assert.Contains("XCLI_EXIT_CODE   exit code when failing (values outside 0-255 are clamped to 0 or 255)", r.StdOut);
        Assert.Contains("JSON log fields:", r.StdOut);
        Assert.Contains("timestampUtc, pid, os, subcommand, args, env, result, exitCode, message, durationMs", r.StdOut);
    }

    // FGC-REQ-CLI-002
    [Fact]
    public void HelpTextMatchesSubcommandsAndGlobals()
    {
        var usageLine = N(Cli.HelpText).Split('\n').First();
        Assert.Matches(@"^Usage: \S+ <subcommand> \[payload-args...\]$", usageLine);
        foreach (var sub in Cli.Subcommands)
            Assert.Contains(sub, Cli.HelpText);
        Assert.Contains("--help", Cli.HelpText);
        Assert.Contains("--version", Cli.HelpText);
    }

    [Fact]
    public void VersionMatchesBaseVersion()
    {
        var r = Run("--version");
        Assert.Equal(VersionInfo.Version, r.StdOut.Trim());
    }

    [Fact]
    public void PassThroughPreserved()
    {
        var r = Run("vitester -- one two");
        Assert.Equal(0, r.ExitCode);
    }

    // FGC-REQ-CLI-002
    [Fact]
    public void MixedCaseSubcommandFails()
    {
        var r = Run("ViTeStEr");
        Assert.NotEqual(0, r.ExitCode);
        var line = N(r.StdErr).Trim().Split('\n').First();
        Assert.Equal("[x-cli] error: unknown subcommand 'ViTeStEr'. See --help.", line);
    }

    // FGC-REQ-CLI-003
    [Fact]
    public void MissingSubcommandFails()
    {
        var r = Run("");
        Assert.Equal(1, r.ExitCode);
        var line = N(r.StdErr).Trim().Split('\n').First();
        Assert.Equal("x-cli: missing subcommand", line);
    }

    // FGC-REQ-CLI-002
    [Fact]
    public void UnknownSubcommandFails()
    {
        var r = Run("unknown");
        Assert.NotEqual(0, r.ExitCode);
        var line = N(r.StdErr).Trim().Split('\n').First();
        Assert.Equal("[x-cli] error: unknown subcommand 'unknown'. See --help.", line);
    }

    // FGC-REQ-CLI-002
    [Fact]
    public void ShortHelpIsUnknownSubcommand()
    {
        var r = Run("-h");
        Assert.NotEqual(0, r.ExitCode);
        var line = N(r.StdErr).Trim().Split('\n').First();
        Assert.Equal("[x-cli] error: unknown subcommand '-h'. See --help.", line);
    }

    [Fact]
    public void NoArgsFailsWithMissingSubcommand()
    {
        var r = Run("");
        Assert.Equal(1, r.ExitCode);
        var line = N(r.StdErr).Trim().Split('\n').First();
        Assert.Equal("x-cli: missing subcommand", line);
    }

    [Fact]
    public void SeparatorWithoutSubcommandFails()
    {
        var r = Run("-- foo");
        Assert.Equal(1, r.ExitCode);
        var line = N(r.StdErr).Trim().Split('\n').First();
        Assert.Equal("x-cli: missing subcommand", line);
    }

    [Fact]
    public void SeparatorAfterSubcommandIsPayloadWithHelp()
    {
        var r = Cli.Parse(new[] { "vitester", "--", "--help" });
        Assert.False(r.ShowHelp);
        Assert.False(r.ShowVersion);
        Assert.Equal("vitester", r.Subcommand);
        Assert.Equal(new[] { "--help" }, r.PayloadArgs);
    }

    [Fact]
    public void SeparatorAfterSubcommandIsPayloadWithVersion()
    {
        var r = Cli.Parse(new[] { "vitester", "--", "--version" });
        Assert.False(r.ShowHelp);
        Assert.False(r.ShowVersion);
        Assert.Equal("vitester", r.Subcommand);
        Assert.Equal(new[] { "--version" }, r.PayloadArgs);
    }

    [Fact]
    public void HelpAfterSubcommandIsPayload()
    {
        var r = Cli.Parse(new[] { "vitester", "--help" });
        Assert.False(r.ShowHelp);
        Assert.False(r.ShowVersion);
        Assert.Equal("vitester", r.Subcommand);
        Assert.Equal(new[] { "--help" }, r.PayloadArgs);
    }

    [Fact]
    public void HelpBeforeSubcommandTriggersHelp()
    {
        var r = Cli.Parse(new[] { "--help", "vitester" });
        Assert.True(r.ShowHelp);
        Assert.False(r.ShowVersion);
        Assert.Null(r.Subcommand);
        Assert.Empty(r.PayloadArgs);
    }

    [Fact]
    public void VersionAfterSubcommandIsPayload()
    {
        var r = Cli.Parse(new[] { "vitester", "--version" });
        Assert.False(r.ShowHelp);
        Assert.False(r.ShowVersion);
        Assert.Equal("vitester", r.Subcommand);
        Assert.Equal(new[] { "--version" }, r.PayloadArgs);
    }

    [Fact]
    public void VersionBeforeSubcommandTriggersVersion()
    {
        var r = Cli.Parse(new[] { "--version", "vitester" });
        Assert.False(r.ShowHelp);
        Assert.True(r.ShowVersion);
        Assert.Null(r.Subcommand);
        Assert.Empty(r.PayloadArgs);
    }
}
