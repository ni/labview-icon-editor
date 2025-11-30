using System;
using System.IO;
using System.Text.Json;
using XCli.Simulation;
using XCli.Tests.TestInfra;
using Xunit;

namespace XCli.Tests.SpecCompliance;

public class FailureSimulationTests
{
    [Fact(DisplayName = "FGC-REQ-SIM-002: Global failure via env produces stderr msg and non-zero exit code")]
    public async Task GlobalFailureEnv_YieldsConfiguredExitAndMessage()
    {
        var env = new Dictionary<string, string>
        {
            ["XCLI_FAIL"] = "true",
            ["XCLI_MESSAGE"] = "Unit tests failed",
            ["XCLI_EXIT_CODE"] = "13"
        };

        var res = await ProcessRunner.RunAsync(
            subcommand: "vitester",
            payloadArgs: new[] { "-r", "report.xml", "MyProject.lvproj" },
            env: env);

        Assert.Equal(13, res.ExitCode);
        Assert.Contains("failure (simulated)", res.StdErr);
        Assert.Contains("Unit tests failed", res.StdErr);
        Assert.DoesNotContain("{", res.StdOut); // no JSON logs on stdout

        var log = res.LogJson;
        Assert.NotNull(log);
        Assert.Equal("failure", log!.RootElement.GetProperty("result").GetString());
        Assert.Equal(13, log.RootElement.GetProperty("exitCode").GetInt32());
        Assert.Equal("vitester", log.RootElement.GetProperty("subcommand").GetString());
    }

    [Fact(DisplayName = "FGC-REQ-SIM-003: Configuring exitCode=0 defaults to exit code 1")]
    public async Task ExitCodeZero_DefaultsToOne()
    {
        var env = new Dictionary<string, string>
        {
            ["XCLI_FAIL"] = "true",
            ["XCLI_EXIT_CODE"] = "0"
        };

        var res = await ProcessRunner.RunAsync(
            subcommand: "vitester",
            payloadArgs: new[] { "-r", "report.xml", "MyProject.lvproj" },
            env: env);

        Assert.Equal(1, res.ExitCode);
        var log = res.LogJson;
        Assert.NotNull(log);
        Assert.Equal(1, log!.RootElement.GetProperty("exitCode").GetInt32());
    }

    [Fact(DisplayName = "FGC-REQ-SIM-003: exitCode above 255 is clamped to 255")]
    public async Task ExitCodeAboveRange_ClampedTo255()
    {
        var env = new Dictionary<string, string>
        {
            ["XCLI_FAIL"] = "true",
            ["XCLI_EXIT_CODE"] = "999"
        };

        var res = await ProcessRunner.RunAsync(
            subcommand: "vitester",
            payloadArgs: new[] { "-r", "report.xml", "MyProject.lvproj" },
            env: env);

        Assert.Equal(255, res.ExitCode);
        var log = res.LogJson;
        Assert.NotNull(log);
        Assert.Equal(255, log!.RootElement.GetProperty("exitCode").GetInt32());
    }

    [Fact(DisplayName = "FGC-REQ-SIM-002: Per-command failure via env only affects targeted subcommand")]
    public async Task PerCommandFailureEnv_OnlyFailsTargeted()
    {
        var env = new Dictionary<string, string>
        {
            ["XCLI_FAIL_ON"] = "vitester"
        };

        // vitester should fail
        var resFail = await ProcessRunner.RunAsync("vitester", new[] { "-r", "report.xml" }, env);
        Assert.NotEqual(0, resFail.ExitCode);
        Assert.Contains("failure (simulated)", resFail.StdErr);

        // lvbuildspec should succeed
        var resOk = await ProcessRunner.RunAsync("lvbuildspec", new[] { "-p", "Proj.lvproj", "-b", "App" }, env);
        Assert.Equal(0, resOk.ExitCode);
        Assert.Contains("success (simulated)", resOk.StdOut);
    }

    [Fact(DisplayName = "FGC-REQ-SIM-002: Empty per-command env disables global failure")]
    public async Task EmptyFailOnEnv_DisablesGlobalFailure()
    {
        var env = new Dictionary<string, string>
        {
            ["XCLI_FAIL"] = "true",
            ["XCLI_FAIL_ON"] = string.Empty
        };

        var res = await ProcessRunner.RunAsync("vitester", new[] { "-r", "report.xml", "MyProject.lvproj" }, env);
        Assert.Equal(0, res.ExitCode);
        Assert.Contains("success (simulated)", res.StdOut);
    }

    [Fact(DisplayName = "FGC-REQ-SIM-002: JSON config overrides env (precedence: JSON > per-command env > global env > defaults)")]
    public async Task JsonOverridesEnv_PrecedenceRespected()
    {
        using var tmp = new TempJsonConfig(new
        {
            defaults = new { fail = false, exitCode = 1, message = "" },
            commands = new Dictionary<string, object?>
            {
                ["vitester"] = new { fail = true, exitCode = 7, message = "JSON wins" }
            }
        });

        var env = new Dictionary<string, string>
        {
            ["XCLI_FAIL"] = "false",
            ["XCLI_FAIL_ON"] = "vitester",
            ["XCLI_EXIT_CODE"] = "2",
            ["XCLI_MESSAGE"] = "Env message",
            ["XCLI_CONFIG_PATH"] = tmp.Path
        };

        var res = await ProcessRunner.RunAsync("vitester", new[] { "-r", "out.trx" }, env);
        Assert.Equal(7, res.ExitCode); // JSON exit code should win
        Assert.Contains("JSON wins", res.StdErr);

        var log = res.LogJson;
        Assert.NotNull(log);
        Assert.Equal(7, log!.RootElement.GetProperty("exitCode").GetInt32());
        Assert.Equal("failure", log.RootElement.GetProperty("result").GetString());
    }

    [Fact(DisplayName = "FGC-REQ-ROB-003: Missing config path yields stderr error and non-zero exit")]
    public async Task MissingConfigPath_YieldsFailure()
    {
        var env = new Dictionary<string, string>
        {
            ["XCLI_CONFIG_PATH"] = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"))
        };

        var res = await ProcessRunner.RunAsync(
            subcommand: "vitester",
            payloadArgs: new[] { "-r", "report.xml", "MyProject.lvproj" },
            env: env);

        Assert.NotEqual(0, res.ExitCode);
        var lines = res.StdErr.Trim().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(2, lines.Length); // one diagnostic + one log line
        Assert.Contains("config file not found", lines[0]);

        var log = res.LogJson;
        Assert.NotNull(log);
        Assert.Equal("failure", log!.RootElement.GetProperty("result").GetString());
    }

    [Fact(DisplayName = "FGC-REQ-ROB-003: Malformed config yields stderr error and non-zero exit")]
    public async Task MalformedConfig_YieldsSingleDiagnostic()
    {
        var path = Path.GetTempFileName();
        await File.WriteAllTextAsync(path, "{not-json");
        try
        {
            var env = new Dictionary<string, string>
            {
                ["XCLI_CONFIG_PATH"] = path
            };

            var res = await ProcessRunner.RunAsync(
                subcommand: "vitester",
                payloadArgs: new[] { "-r", "report.xml", "MyProject.lvproj" },
                env: env);

            Assert.NotEqual(0, res.ExitCode);
            var lines = res.StdErr.Trim().Split('\n', StringSplitOptions.RemoveEmptyEntries);
            Assert.Equal(2, lines.Length); // one diagnostic + one log line
            Assert.StartsWith("config parse error", lines[0]);

            var log = res.LogJson;
            Assert.NotNull(log);
            Assert.Equal("failure", log!.RootElement.GetProperty("result").GetString());
        }
        finally
        {
            try { File.Delete(path); } catch { }
        }
    }

    private sealed class TempJsonConfig : IDisposable
    {
        public string Path { get; }
        public TempJsonConfig(object obj)
        {
            Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"xcli-{Guid.NewGuid():N}.json");
            var json = JsonSerializer.Serialize(obj);
            File.WriteAllText(Path, json);
        }
        public void Dispose()
        {
            try { if (File.Exists(Path)) File.Delete(Path); } catch { /* ignore */ }
        }
    }
}

