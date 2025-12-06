using System;
using System.Collections.Generic;
using System.IO;
using XCli.Tests.TestInfra;
using Xunit;

public class LabviewDevmodeScenarioConfigTests
{
    private static ProcessRunner.CliResult Run(string sub, IDictionary<string, string>? env = null, params string[] payload)
        => ProcessRunner.RunAsync(sub, payload, env).GetAwaiter().GetResult();

    public LabviewDevmodeScenarioConfigTests() => XCli.Util.Env.ResetCacheForTests();

    [Fact]
    public void PartialTimeoutSoftScenarioCanBeConfigured()
    {
        var configPath = Path.GetTempFileName();
        var json = @"{
  ""scenarios"": {
    ""partial+timeout-soft"": {
      ""exitCode"": 0,
      ""success"": true,
      ""stderrLines"": [
        ""[test] overridden partial+timeout-soft for stage '{stage}' opTag '{opTag}'""
      ]
    }
    }
}";
        File.WriteAllText(configPath, json);

        var env = new Dictionary<string, string>
        {
            {"XCLI_LVDEVMODE_CONFIG_PATH", configPath}
        };

        var r = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--script", "AddTokenToLabVIEW.ps1",
            "--scenario", "partial+timeout-soft"
        );

        Assert.Equal(0, r.ExitCode);
        Assert.Contains("[test] overridden partial+timeout-soft for stage 'dev-mode' opTag ''", r.StdErr);
    }

    [Fact]
    public void MatrixScenarioUsesConfigForVersionBitnessOutcomes()
    {
        var configPath = Path.GetTempFileName();
        var json = @"{
  ""matrix"": {
    ""degraded"": [""2025-64""],
    ""succeeded"": [""2026-32""]
  }
}";
        File.WriteAllText(configPath, json);

        var env = new Dictionary<string, string>
        {
            {"XCLI_LVDEVMODE_CONFIG_PATH", configPath}
        };

        // 2025 x64 now degraded (exit code 2)
        var r1 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2025",
            "--bitness", "64",
            "--script", "Prepare_LabVIEW_source.vi",
            "--scenario", "matrix"
        );
        Assert.Equal(2, r1.ExitCode);

        // 2026 x32 now succeeds (exit code 0)
        var r2 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2026",
            "--bitness", "32",
            "--script", "Prepare_LabVIEW_source.vi",
            "--scenario", "matrix"
        );
        Assert.Equal(0, r2.ExitCode);
    }

    [Fact]
    public void ScenarioOverridesCanBeAppliedPerOperationAndVersion()
    {
        var configPath = Path.GetTempFileName();
        var json = @"{
  ""scenarios"": {
    ""timeout.enable-addtoken-2021-32.v1"": {
      ""exitCode"": 1,
      ""success"": false,
      ""stderrLines"": [
        ""[test] timeout addtoken 2021-32 for stage '{stage}' opTag '{opTag}'""
      ]
    },
    ""timeout-soft.enable-prepare-2021-64.v1"": {
      ""exitCode"": 0,
      ""success"": true,
      ""stderrLines"": [
        ""[test] timeout-soft prepare 2021-64 for stage '{stage}' opTag '{opTag}'""
      ]
    },
    ""partial.enable-addtoken-2021-64.v1"": {
      ""exitCode"": 2,
      ""success"": false,
      ""stderrLines"": [
        ""[test] partial addtoken 2021-64 for stage '{stage}' opTag '{opTag}'""
      ]
    },
    ""rogue.enable-prepare-2021-32.v1"": {
      ""exitCode"": 1,
      ""success"": false,
      ""stderrLines"": [
        ""[test] rogue prepare 2021-32 for stage '{stage}' opTag '{opTag}' (Rogue LabVIEW simulated)""
      ]
    }
  }
}";
        File.WriteAllText(configPath, json);

        var env = new Dictionary<string, string>
        {
            {"XCLI_LVDEVMODE_CONFIG_PATH", configPath}
        };

        // timeout enable-addtoken 2021 x32: fails with exit code 1 and custom stderr
        var r1 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2021",
            "--bitness", "32",
            "--script", "AddTokenToLabVIEW.ps1",
            "--operation", "enable-addtoken-2021-32",
            "--scenario", "timeout.enable-addtoken-2021-32.v1"
        );
        Assert.Equal(1, r1.ExitCode);
        Assert.Contains("[test] timeout addtoken 2021-32 for stage 'enable-addtoken-2021-32' opTag ' [enable-addtoken-2021-32]'", r1.StdErr);

        // timeout-soft enable-prepare 2021 x64: succeeds with exit code 0 and custom stderr
        var r2 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2021",
            "--bitness", "64",
            "--script", "Prepare_LabVIEW_source.vi",
            "--operation", "enable-prepare-2021-64",
            "--scenario", "timeout-soft.enable-prepare-2021-64.v1"
        );
        Assert.Equal(0, r2.ExitCode);
        Assert.Contains("[test] timeout-soft prepare 2021-64 for stage 'enable-prepare-2021-64' opTag ' [enable-prepare-2021-64]'", r2.StdErr);

        // partial enable-addtoken 2021 x64: degraded (exit code 2) with custom stderr
        var r3 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2021",
            "--bitness", "64",
            "--script", "AddTokenToLabVIEW.ps1",
            "--operation", "enable-addtoken-2021-64",
            "--scenario", "partial.enable-addtoken-2021-64.v1"
        );
        Assert.Equal(2, r3.ExitCode);
        Assert.Contains("[test] partial addtoken 2021-64 for stage 'enable-addtoken-2021-64' opTag ' [enable-addtoken-2021-64]'", r3.StdErr);

        // rogue enable-prepare 2021 x32: failure (exit code 1) with Rogue LabVIEW text
        var r4 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2021",
            "--bitness", "32",
            "--script", "Prepare_LabVIEW_source.vi",
            "--operation", "enable-prepare-2021-32",
            "--scenario", "rogue.enable-prepare-2021-32.v1"
        );
        Assert.Equal(1, r4.ExitCode);
        Assert.Contains("[test] rogue prepare 2021-32 for stage 'enable-prepare-2021-32' opTag ' [enable-prepare-2021-32]'", r4.StdErr);
        Assert.Contains("Rogue LabVIEW", r4.StdErr);
    }

    [Fact]
    public void ScenarioConfigMissingFileLogsErrorAndFallsBack()
    {
        var configPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N") + ".json");
        var env = new Dictionary<string, string>
        {
            {"XCLI_LVDEVMODE_CONFIG_PATH", configPath}
        };

        var r = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--script", "AddTokenToLabVIEW.ps1",
            "--scenario", "partial+timeout-soft"
        );

        Assert.Equal(2, r.ExitCode);
        Assert.Contains("lvdevmode-config: file not found", r.StdErr);
    }

    [Fact]
    public void ScenarioConfigInvalidJsonLogsErrorAndFallsBack()
    {
        var configPath = Path.GetTempFileName();
        File.WriteAllText(configPath, "{not-json");

        var env = new Dictionary<string, string>
        {
            {"XCLI_LVDEVMODE_CONFIG_PATH", configPath}
        };

        var r = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--script", "AddTokenToLabVIEW.ps1",
            "--scenario", "partial+timeout-soft"
        );

        Assert.Equal(2, r.ExitCode);
        Assert.Contains("lvdevmode-config: invalid JSON", r.StdErr);
    }

    [Fact]
    public void ScenarioOverridesSupportMultipleVersionsForSameOperation()
    {
        var configPath = Path.GetTempFileName();
        var json = @"{
  ""scenarios"": {
    ""happy.enable-addtoken-2021-32.v2"": {
      ""exitCode"": 0,
      ""success"": true,
      ""stderrLines"": [
        ""[test] happy addtoken 2021-32 for stage '{stage}' opTag '{opTag}'""
      ]
    },
    ""happy.enable-addtoken-2025-64.v1"": {
      ""exitCode"": 0,
      ""success"": true,
      ""stderrLines"": [
        ""[test] happy addtoken 2025-64 for stage '{stage}' opTag '{opTag}'""
      ]
    }
  }
}";
        File.WriteAllText(configPath, json);

        var env = new Dictionary<string, string>
        {
            {"XCLI_LVDEVMODE_CONFIG_PATH", configPath}
        };

        // enable-addtoken 2021 x32, v2 scenario
        var r1 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2021",
            "--bitness", "32",
            "--script", "AddTokenToLabVIEW.ps1",
            "--operation", "enable-addtoken-2021-32",
            "--scenario", "happy.enable-addtoken-2021-32.v2"
        );
        Assert.Equal(0, r1.ExitCode);
        Assert.Contains("[test] happy addtoken 2021-32 for stage 'enable-addtoken-2021-32' opTag ' [enable-addtoken-2021-32]'", r1.StdErr);

        // enable-addtoken 2025 x64, v1 scenario
        var r2 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2025",
            "--bitness", "64",
            "--script", "AddTokenToLabVIEW.ps1",
            "--operation", "enable-addtoken-2025-64",
            "--scenario", "happy.enable-addtoken-2025-64.v1"
        );
        Assert.Equal(0, r2.ExitCode);
        Assert.Contains("[test] happy addtoken 2025-64 for stage 'enable-addtoken-2025-64' opTag ' [enable-addtoken-2025-64]'", r2.StdErr);
    }

    [Fact]
    public void ScenarioOverridesV2ForEnableAddtoken2021X32()
    {
        var configPath = Path.GetTempFileName();
        var json = @"{
  ""scenarios"": {
    ""timeout.enable-addtoken-2021-32.v2"": {
      ""exitCode"": 1,
      ""success"": false,
      ""stderrLines"": [
        ""Error: [enable-addtoken-2021-32] No connection established with application (v2)."",
        ""Caused by: Timed out waiting for app to connect to g-cli (v2)""
      ]
    },
    ""timeout-soft.enable-addtoken-2021-32.v2"": {
      ""exitCode"": 0,
      ""success"": true,
      ""stderrLines"": [
        ""Warning: [enable-addtoken-2021-32] Soft timeout while communicating with application (v2, simulated)."",
        ""Caused by: Timed out waiting for app to connect to g-cli (soft, v2)""
      ]
    },
    ""partial+timeout-soft.enable-addtoken-2021-32.v2"": {
      ""exitCode"": 2,
      ""success"": false,
      ""stderrLines"": [
        ""[test] partial+timeout-soft addtoken 2021-32 v2 for stage '{stage}' opTag '{opTag}'""
      ]
    }
  }
}";
        File.WriteAllText(configPath, json);

        var env = new Dictionary<string, string>
        {
            {"XCLI_LVDEVMODE_CONFIG_PATH", configPath}
        };

        // timeout v2: hard timeout should fail with exit code 1 and v2 timeout text.
        var r1 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2021",
            "--bitness", "32",
            "--script", "AddTokenToLabVIEW.ps1",
            "--operation", "enable-addtoken-2021-32",
            "--scenario", "timeout.enable-addtoken-2021-32.v2"
        );
        Assert.Equal(1, r1.ExitCode);
        Assert.Contains("No connection established with application (v2).", r1.StdErr);
        Assert.Contains("Timed out waiting for app to connect to g-cli (v2)", r1.StdErr);

        // timeout-soft v2: soft timeout should succeed with exit code 0 and v2 soft-timeout text.
        var r2 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2021",
            "--bitness", "32",
            "--script", "AddTokenToLabVIEW.ps1",
            "--operation", "enable-addtoken-2021-32",
            "--scenario", "timeout-soft.enable-addtoken-2021-32.v2"
        );
        Assert.Equal(0, r2.ExitCode);
        Assert.Contains("Soft timeout while communicating with application (v2, simulated).", r2.StdErr);
        Assert.Contains("Timed out waiting for app to connect to g-cli (soft, v2)", r2.StdErr);

        // partial+timeout-soft v2: degraded run with custom partial+timeout-soft text.
        var r3 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--lv-version", "2021",
            "--bitness", "32",
            "--script", "AddTokenToLabVIEW.ps1",
            "--operation", "enable-addtoken-2021-32",
            "--scenario", "partial+timeout-soft.enable-addtoken-2021-32.v2"
        );
        Assert.Equal(2, r3.ExitCode);
        Assert.Contains("[test] partial+timeout-soft addtoken 2021-32 v2 for stage 'enable-addtoken-2021-32' opTag ' [enable-addtoken-2021-32]'", r3.StdErr);
    }

    [Fact]
    public void LunitScenariosCanBeConfiguredForSuccessAndFailure()
    {
        var configPath = Path.GetTempFileName();
        var json = @"{
  ""scenarios"": {
    ""lunit.success"": {
      ""exitCode"": 0,
      ""success"": true,
      ""stderrLines"": [
        ""[LUnit] 42 tests, 0 failures, 0 errors."",
        ""LUnit: all tests passed"",
        ""Report written to: C:\\fake\\lunit\\lunit_results.xml""
      ]
    },
    ""lunit.fail"": {
      ""exitCode"": 1,
      ""success"": false,
      ""stderrLines"": [
        ""[LUnit] 42 tests, 1 failure, 0 errors."",
        ""LUnit: 1 test failed"",
        ""Report written to: C:\\fake\\lunit\\lunit_results.xml""
      ]
    }
  }
}";
        File.WriteAllText(configPath, json);

        var env = new Dictionary<string, string>
        {
            {"XCLI_LVDEVMODE_CONFIG_PATH", configPath}
        };

        // LUnit success scenario
        var r1 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--script", "AddTokenToLabVIEW.ps1",
            "--scenario", "lunit.success"
        );
        Assert.Equal(0, r1.ExitCode);
        Assert.Contains("[LUnit] 42 tests, 0 failures, 0 errors.", r1.StdErr);
        Assert.Contains("LUnit: all tests passed", r1.StdErr);
        Assert.Contains("Report written to: C:\\fake\\lunit\\lunit_results.xml", r1.StdErr);

        // LUnit failure scenario
        var r2 = Run(
            "labview-devmode-enable",
            env,
            "--lvaddon-root", "C:\\fake\\lvaddon-root",
            "--script", "AddTokenToLabVIEW.ps1",
            "--scenario", "lunit.fail"
        );
        Assert.Equal(1, r2.ExitCode);
        Assert.Contains("[LUnit] 42 tests, 1 failure, 0 errors.", r2.StdErr);
        Assert.Contains("LUnit: 1 test failed", r2.StdErr);
        Assert.Contains("Report written to: C:\\fake\\lunit\\lunit_results.xml", r2.StdErr);
    }
}
