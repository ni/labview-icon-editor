// FGC-REQ-QA-001
using XCli.Cli;
using XCli.Simulation;
using XCli.Util;
using XCli.Tests.TestInfra;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using System;
using System.Threading;
using System.Threading.Tasks;
using Xunit;

public class SimulationTests
{
    private static ProcessRunner.CliResult Run(string sub, IDictionary<string, string>? env = null, params string[] payload)
        => ProcessRunner.RunAsync(sub, payload, env).GetAwaiter().GetResult();

    public SimulationTests() => Env.ResetCacheForTests();

    private static void SetEnv(string name, string? value)
    {
        Environment.SetEnvironmentVariable(name, value);
        Env.ResetCacheForTests();
    }

    private static string LastJsonLine(string stderr) => stderr
        .Split('\n')
        .Reverse()
        .First(l => l.TrimStart().StartsWith("{"));

    private static readonly string[] SimulationExclusions = new[] { "echo", "reverse", "upper", "log-replay", "log-diff", "telemetry", "foo" };

    public static IEnumerable<object[]> Subcommands() =>
        Cli.Subcommands
            .Where(s => !SimulationExclusions.Contains(s, StringComparer.OrdinalIgnoreCase))
            .OrderBy(s => s)
            .Select(s => new object[] { s });

    [Theory]
    [MemberData(nameof(Subcommands))]
    // FGC-REQ-SIM-001
    public void DefaultSuccess(string sub)
    {
        var r = Run(sub, null, "payload");
        Assert.Equal(0, r.ExitCode);
        Assert.Contains($"[x-cli] {sub}: success (simulated)", r.StdOut);
    }

    [Fact]
    public void MixedCaseSubcommandRejected()
    {
        var r = Run("VITESTER");
        Assert.NotEqual(0, r.ExitCode);
        var line = r.StdErr.Trim().Split('\n').First().TrimEnd('\r');
        Assert.Equal("[x-cli] error: unknown subcommand 'VITESTER'. See --help.", line);
    }

    [Fact]
    public void GlobalFail()
    {
        var env = new Dictionary<string,string> {{"XCLI_FAIL","true"}};
        var r = Run("vitester", env);
        Assert.Equal(1, r.ExitCode);
        var lines = r.StdErr.Split('\n');
        var firstLine = lines[0].TrimEnd('\r');
        Assert.Equal("[x-cli] vitester: failure (simulated) - unspecified failure", firstLine);
        var json = LastJsonLine(r.StdErr);
        using var doc = JsonDocument.Parse(json);
        Assert.Equal("unspecified failure", doc.RootElement.GetProperty("message").GetString());
    }

    [Fact]
    public void FailOnOverridesGlobal()
    {
        var env = new Dictionary<string,string>
        {
            {"XCLI_FAIL","true"},
            {"XCLI_FAIL_ON","vitester"},
        };
        var r = Run("clearlvcache", env);
        Assert.Equal(0, r.ExitCode);
        Assert.Contains("[x-cli] clearlvcache: success (simulated)", r.StdOut);
        Assert.DoesNotContain("failure", r.StdErr);
    }

    [Fact]
    public void PerCommandFailWithCustomMessage()
    {
        var env = new Dictionary<string,string>
        {
            {"XCLI_FAIL_ON","vitester"},
            {"XCLI_MESSAGE","nope"},
            {"XCLI_EXIT_CODE","5"}
        };
        var r = Run("vitester", env);
        Assert.Equal(5, r.ExitCode);
        var firstLine = r.StdErr.Split('\n')[0].TrimEnd('\r');
        Assert.Equal("[x-cli] vitester: failure (simulated) - nope", firstLine);
    }

    [Theory]
    [InlineData("999", 255)]
    [InlineData("-1", 1)]
    public void ExitCodeOutOfRangeClamped(string configured, int expected)
    {
        var env = new Dictionary<string,string>
        {
            {"XCLI_FAIL","true"},
            {"XCLI_EXIT_CODE", configured},
        };
        var r = Run("vitester", env);
        Assert.Equal(expected, r.ExitCode);
    }

    [Theory]
    [InlineData(999, 255)]
    [InlineData(-1, 1)]
    public void JsonConfigDefaultExitCodeOutOfRangeClamped(int configured, int expected)
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, $"{{\"defaults\":{{\"fail\":true,\"exitCode\":{configured}}}}}");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.Equal(expected, r.ExitCode);
    }

    [Theory]
    [InlineData(999, 255)]
    [InlineData(-1, 1)]
    public void JsonConfigPerCommandExitCodeOutOfRangeClamped(int configured, int expected)
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, $"{{\"commands\":{{\"vitester\":{{\"fail\":true,\"exitCode\":{configured}}}}}}}");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.Equal(expected, r.ExitCode);
    }

    [Fact]
    public void JsonConfigOverridesEnv()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"commands\":{\"vitester\":{\"fail\":false}}}");
        var env = new Dictionary<string,string>
        {
            {"XCLI_FAIL_ON","vitester"},
            {"XCLI_MESSAGE","env"},
            {"XCLI_EXIT_CODE","9"},
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.Equal(0, r.ExitCode);
        Assert.DoesNotContain("failure", r.StdErr);
    }

    [Fact]
    public void JsonConfigFailUsesEnvExitCodeAndMessage()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"commands\":{\"vitester\":{\"fail\":true}}}");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path},
            {"XCLI_EXIT_CODE", "5"},
            {"XCLI_MESSAGE", "envmsg"},
        };
        var r = Run("vitester", env);
        Assert.Equal(5, r.ExitCode);
        var firstLine = r.StdErr.Split('\n')[0].TrimEnd('\r');
        Assert.Equal("[x-cli] vitester: failure (simulated) - envmsg", firstLine);
    }

    [Fact]
    // FGC-REQ-ROB-001
    public void MalformedJsonConfigReportsError()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{not-json");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.NotEqual(0, r.ExitCode);
        var lines = r.StdErr.Trim().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(2, lines.Length);
        var line0 = lines[0].TrimEnd('\r');
        Assert.StartsWith("config parse error:", line0);
        Assert.DoesNotContain("[x-cli]", line0);
        Assert.DoesNotContain("failure (simulated)", r.StdErr);
    }

    [Fact]
    // FGC-REQ-ROB-001
    public void UnknownJsonPropertyReportsError()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"bogus\":1}");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.NotEqual(0, r.ExitCode);
        var lines = r.StdErr.Trim().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(2, lines.Length);
        var line0 = lines[0].TrimEnd('\r');
        Assert.StartsWith("config parse error:", line0);
        Assert.DoesNotContain("[x-cli]", line0);
        Assert.DoesNotContain("failure (simulated)", r.StdErr);
    }

    [Fact]
    public void MissingJsonConfigFails()
    {
        var path = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.NotEqual(0, r.ExitCode);
        var lines = r.StdErr.Trim().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(2, lines.Length);
        var line0 = lines[0].TrimEnd('\r');
        Assert.Equal($"[x-cli] config file not found: {path}", line0);
        Assert.DoesNotContain("failure (simulated)", r.StdErr);
    }

    [Fact]
    public void MissingJsonConfigDirectoryFails()
    {
        var path = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString(), "cfg.json");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.NotEqual(0, r.ExitCode);
        var lines = r.StdErr.Trim().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(2, lines.Length);
        var line0 = lines[0].TrimEnd('\r');
        Assert.Equal($"[x-cli] config file not found: {path}", line0);
        Assert.DoesNotContain("failure (simulated)", r.StdErr);
    }

    [Fact]
    public void UnreadableJsonConfigShowsPermissionDenied()
    {
        var path = "/proc/kmsg";
        if (!File.Exists(path))
            return;
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.NotEqual(0, r.ExitCode);
        var lines = r.StdErr.Trim().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(2, lines.Length);
        var line0 = lines[0].TrimEnd('\r');
        Assert.Equal($"[x-cli] config file permission denied: {path}", line0);
        Assert.DoesNotContain("failure (simulated)", r.StdErr);
    }

    [Fact]
    // FGC-REQ-SIM-004
    public void JsonConfigDelayOverridesEnv()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"defaults\":{\"delayMs\":20},\"commands\":{\"vitester\":{\"delayMs\":5}}}");
        var delayKey = "XCLI_DELAY_MS";
        var configKey = "XCLI_CONFIG_PATH";
        var originalDelay = Environment.GetEnvironmentVariable(delayKey);
        var originalConfig = Environment.GetEnvironmentVariable(configKey);
        try
        {
            SetEnv(delayKey, "1");
            SetEnv(configKey, path);
            var plan = SimulationPlan.ForCommand("vitester");
            Assert.Equal(5, plan.Plan.DelayMs);
            var other = SimulationPlan.ForCommand("vipc");
            Assert.Equal(20, other.Plan.DelayMs);
        }
        finally
        {
            SetEnv(delayKey, originalDelay);
            SetEnv(configKey, originalConfig);
        }
    }

    [Fact]
    // FGC-REQ-SIM-004
    public void NegativeDelayIgnoredAndWarns()
    {
        var delayKey = "XCLI_DELAY_MS";
        var debugKey = "XCLI_DEBUG";
        var configKey = "XCLI_CONFIG_PATH";
        var originalDelay = Environment.GetEnvironmentVariable(delayKey);
        var originalDebug = Environment.GetEnvironmentVariable(debugKey);
        var originalConfig = Environment.GetEnvironmentVariable(configKey);
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"defaults\":{\"delayMs\":-10}}");
        try
        {
            SetEnv(delayKey, "-5");
            SetEnv(debugKey, "true");
            SetEnv(configKey, path);
            var originalErr = Console.Error;
            using var err = new StringWriter();
            Console.SetError(err);
              var plan = SimulationPlan.ForCommand("vitester");
              Console.SetError(originalErr);
              Assert.Equal(0, plan.Plan.DelayMs);
            var warnings = err.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries)
                .Count(l => l.Contains("negative delay"));
            Assert.Equal(1, warnings);
        }
        finally
        {
            SetEnv(delayKey, originalDelay);
            SetEnv(debugKey, originalDebug);
            SetEnv(configKey, originalConfig);
        }
    }

    [Fact]
    // FGC-REQ-SIM-004
    public void NegativeDelayOverriddenDoesNotWarn()
    {
        var delayKey = "XCLI_DELAY_MS";
        var debugKey = "XCLI_DEBUG";
        var configKey = "XCLI_CONFIG_PATH";
        var originalDelay = Environment.GetEnvironmentVariable(delayKey);
        var originalDebug = Environment.GetEnvironmentVariable(debugKey);
        var originalConfig = Environment.GetEnvironmentVariable(configKey);
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"commands\":{\"vitester\":{\"delayMs\":5}}}");
        try
        {
            SetEnv(delayKey, "-5");
            SetEnv(debugKey, "true");
            SetEnv(configKey, path);
            var originalErr = Console.Error;
            using var err = new StringWriter();
            Console.SetError(err);
              var plan = SimulationPlan.ForCommand("vitester");
              Console.SetError(originalErr);
              Assert.Equal(5, plan.Plan.DelayMs);
            Assert.DoesNotContain("negative delay", err.ToString());
        }
        finally
        {
            SetEnv(delayKey, originalDelay);
            SetEnv(debugKey, originalDebug);
            SetEnv(configKey, originalConfig);
        }
    }

    [Fact]
    // FGC-REQ-SIM-004
    public void ExcessiveDelayClampedAndWarns()
    {
        var delayKey = "XCLI_DELAY_MS";
        var debugKey = "XCLI_DEBUG";
        var originalDelay = Environment.GetEnvironmentVariable(delayKey);
        var originalDebug = Environment.GetEnvironmentVariable(debugKey);
        try
        {
            SetEnv(delayKey, (SimulationPlan.MaxDelayMs + 5000).ToString());
            SetEnv(debugKey, "true");
            var originalErr = Console.Error;
            using var err = new StringWriter();
            Console.SetError(err);
              var plan = SimulationPlan.ForCommand("vitester");
              Console.SetError(originalErr);
              Assert.Equal(SimulationPlan.MaxDelayMs, plan.Plan.DelayMs);
            var warnings = err.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries)
                .Count(l => l.Contains("delay truncated"));
            Assert.Equal(1, warnings);
        }
        finally
        {
            SetEnv(delayKey, originalDelay);
            SetEnv(debugKey, originalDebug);
        }
    }

    [Fact]
    // FGC-REQ-SIM-004
    public async Task ExecuteHonorsConfiguredDelay()
    {
        var plan = new SimulationPlan { DelayMs = 50 };
        var simulator = new Simulator();
        var sw = Stopwatch.StartNew();
        var result = await simulator.Execute("vitester", new SimulationPlanResult(plan, null));
        sw.Stop();
        Assert.True(sw.ElapsedMilliseconds >= plan.DelayMs);
        Assert.True(result.Success);
    }

    [Fact]
    // FGC-REQ-SIM-004
    public async Task ExecuteDelayCanBeCancelled()
    {
        var plan = new SimulationPlan { DelayMs = 1000 };
        var simulator = new Simulator();
        using var cts = new CancellationTokenSource(50);
        var sw = Stopwatch.StartNew();
        await Assert.ThrowsAsync<TaskCanceledException>(() => (Task)simulator.Execute("vitester", new SimulationPlanResult(plan, null), cts.Token));
        sw.Stop();
        Assert.True(sw.ElapsedMilliseconds < plan.DelayMs);
    }

    [Fact]
    public void JsonConfigIsCaseInsensitive()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"CoMmAnDs\":{\"vitester\":{\"FaIl\":true,\"ExItCoDe\":7}}}");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.Equal(7, r.ExitCode);
        Assert.Contains("failure", r.StdErr);
    }

    [Fact]
    public void JsonConfigCommandKeyIsCaseInsensitive()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"commands\":{\"ViTeStEr\":{\"fail\":true,\"exitCode\":3}}}");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.Equal(3, r.ExitCode);
        Assert.Contains("[x-cli] vitester: failure (simulated)", r.StdErr);
    }

    [Fact]
    public void DefaultFailWithPerCommandOverride()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"defaults\":{\"fail\":true,\"exitCode\":1},\"commands\":{\"vitester\":{\"fail\":false}}}");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var ok = Run("vitester", env);
        Assert.Equal(0, ok.ExitCode);
        var fail = Run("clearlvcache", env);
        Assert.Equal(1, fail.ExitCode);
        Assert.Contains("[x-cli] clearlvcache: failure (simulated)", fail.StdErr);
    }

    [Fact]
    public void CommandConfigPartialOverrideUsesDefaults()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{\"defaults\":{\"fail\":true,\"exitCode\":2,\"message\":\"def\"},\"commands\":{\"vitester\":{\"message\":\"cmd\"}}}");
        var env = new Dictionary<string,string>
        {
            {"XCLI_CONFIG_PATH", path}
        };
        var r = Run("vitester", env);
        Assert.Equal(2, r.ExitCode);
        Assert.Contains("[x-cli] vitester: failure (simulated) - cmd", r.StdErr);
        var r2 = Run("clearlvcache", env);
        Assert.Equal(2, r2.ExitCode);
        Assert.Contains("[x-cli] clearlvcache: failure (simulated) - def", r2.StdErr);
    }

    [Fact]
    public void ConfigPathMissingHandlesFileAndDirectory()
    {
        var configKey = "XCLI_CONFIG_PATH";

        (SimulationPlanResult plan, string err) RunPath(string path)
        {
            SetEnv(configKey, path);
            var originalErr = Console.Error;
            using var err = new StringWriter();
            Console.SetError(err);
            var plan = SimulationPlan.ForCommand("vitester");
            Console.SetError(originalErr);
            return (plan, err.ToString());
        }

        var originalConfig = Environment.GetEnvironmentVariable(configKey);
        try
        {
            var missingFile = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
            var missingDir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName(), "cfg.json");

            var (plan1, err1) = RunPath(missingFile);
            var (plan2, err2) = RunPath(missingDir);

            Assert.Equal(SimulationPlanError.ConfigNotFound, plan1.Error);
            Assert.Equal(SimulationPlanError.ConfigNotFound, plan2.Error);
            Assert.True(plan1.Plan.Fail);
            Assert.True(plan2.Plan.Fail);
            Assert.Equal(plan1.Plan.ExitCode, plan2.Plan.ExitCode);
            Assert.Equal(plan1.Plan.DelayMs, plan2.Plan.DelayMs);
            Assert.StartsWith("config file not found:", plan1.Plan.Message);
            Assert.StartsWith("config file not found:", plan2.Plan.Message);
            Assert.StartsWith("[x-cli] config file not found:", err1.Trim());
            Assert.StartsWith("[x-cli] config file not found:", err2.Trim());
        }
        finally
        {
            SetEnv(configKey, originalConfig);
        }
    }

    [Fact]
    public void ConfigPathPermissionDeniedReportsError()
    {
        var path = "/proc/kmsg";
        if (!File.Exists(path))
            return;
        var configKey = "XCLI_CONFIG_PATH";
        var originalConfig = Environment.GetEnvironmentVariable(configKey);
        try
        {
            SetEnv(configKey, path);
            var originalErr = Console.Error;
            using var err = new StringWriter();
            Console.SetError(err);
            var plan = SimulationPlan.ForCommand("vitester");
            Console.SetError(originalErr);
            Assert.Equal(SimulationPlanError.ConfigPermissionDenied, plan.Error);
            Assert.True(plan.Plan.Fail);
            Assert.Equal($"config file permission denied: {path}", plan.Plan.Message);
            Assert.StartsWith($"[x-cli] config file permission denied: {path}", err.ToString().Trim());
        }
        finally
        {
            SetEnv(configKey, originalConfig);
        }
    }

    [Fact]
    // FGC-REQ-ROB-001
    public void ConfigPathMalformedJsonReportsError()
    {
        var path = Path.GetTempFileName();
        File.WriteAllText(path, "{" + "oops");
        var configKey = "XCLI_CONFIG_PATH";
        var originalConfig = Environment.GetEnvironmentVariable(configKey);
        try
        {
            SetEnv(configKey, path);
            var originalErr = Console.Error;
            using var err = new StringWriter();
            Console.SetError(err);
            var plan = SimulationPlan.ForCommand("vitester");
            Console.SetError(originalErr);
            Assert.Equal(SimulationPlanError.ConfigParseError, plan.Error);
            Assert.True(plan.Plan.Fail);
            Assert.StartsWith("config parse error:", plan.Plan.Message);
            Assert.StartsWith("config parse error:", err.ToString().Trim());
        }
        finally
        {
            SetEnv(configKey, originalConfig);
            File.Delete(path);
        }
    }
}
