using System.Diagnostics;
using System.Text.Json;
using RunnerCli;

namespace RunnerCli.Tests;

[Collection("RunnerCliCli")]
public class RunnerCliCliTests
{
    [Fact]
    public void VersionGate_emits_json_payload()
    {
        var repoRoot = FindRepoRoot();
        var (exitCode, stdout, stderr) = RunCli(repoRoot, $"version-gate --repo-root \"{repoRoot}\" --json");

        Assert.Equal(0, exitCode);
        Assert.True(string.IsNullOrWhiteSpace(stderr), $"stderr: {stderr}");

        using var doc = JsonDocument.Parse(stdout);
        var root = doc.RootElement;
        Assert.True(TryGetPropertyIgnoreCase(root, "year", out _), "year missing");
        Assert.True(TryGetPropertyIgnoreCase(root, "numericVersion", out _), "numericVersion missing");
    }

    [Fact]
    public void PylaviSummarize_writes_output_even_with_json()
    {
        var repoRoot = FindRepoRoot();
        var tempDir = Directory.CreateTempSubdirectory("lvie-cli-test");
        var reportPath = Path.Combine(tempDir.FullName, "pylavi-report.json");
        var outputPath = Path.Combine(tempDir.FullName, "pylavi-summary.json");

        var report = new PylaviOffendersReport
        {
            Label = "pylavi",
            GeneratedUtc = "2026-02-06T12:00:00Z",
            TotalFails = 1,
            ConfiguredRoots = "<redacted>",
            ConfiguredRootCount = 1,
            TopOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "foo.vi", Count = 1 }
            },
            TopAbsoluteOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "C:\\Users\\DevUser\\Projects\\bar.vi", Count = 1 }
            }
        };
        File.WriteAllText(reportPath, JsonSerializer.Serialize(report, RunnerCliJsonContext.Default.PylaviOffendersReport));

        var args = $"pylavi summarize --path \"{reportPath}\" --json --output-path \"{outputPath}\"";
        var (exitCode, stdout, stderr) = RunCli(repoRoot, args);

        Assert.Equal(0, exitCode);
        Assert.True(string.IsNullOrWhiteSpace(stderr), $"stderr: {stderr}");
        Assert.True(File.Exists(outputPath), "output path not written");

        using var stdoutDoc = JsonDocument.Parse(stdout);
        Assert.True(stdoutDoc.RootElement.TryGetProperty("label", out _));

        var outputJson = File.ReadAllText(outputPath);
        using var outputDoc = JsonDocument.Parse(outputJson);
        Assert.True(outputDoc.RootElement.TryGetProperty("file", out _));
        Assert.True(outputDoc.RootElement.TryGetProperty("has_findings", out _));
    }

    [Fact]
    public void PylaviSummarize_with_baseline_emits_delta_fields()
    {
        var repoRoot = FindRepoRoot();
        var tempDir = Directory.CreateTempSubdirectory("lvie-cli-delta");
        var reportPath = Path.Combine(tempDir.FullName, "pylavi-report.json");
        var baselinePath = Path.Combine(tempDir.FullName, "pylavi-baseline.json");
        var outputPath = Path.Combine(tempDir.FullName, "pylavi-summary.json");

        var baseline = new PylaviOffendersReport
        {
            Label = "pylavi",
            GeneratedUtc = "2026-02-06T12:00:00Z",
            TotalFails = 1,
            ConfiguredRoots = "<redacted>",
            ConfiguredRootCount = 1,
            TopOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "foo.vi", Count = 1 }
            },
            TopAbsoluteOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "C:\\Users\\DevUser\\Projects\\bar.vi", Count = 1 }
            }
        };

        var report = new PylaviOffendersReport
        {
            Label = "pylavi",
            GeneratedUtc = "2026-02-06T12:00:00Z",
            TotalFails = 2,
            ConfiguredRoots = "<redacted>",
            ConfiguredRootCount = 2,
            TopOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "foo.vi", Count = 1 },
                new() { Item = "delta.vi", Count = 1 }
            },
            TopAbsoluteOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "C:\\Users\\DevUser\\Projects\\bar.vi", Count = 1 },
                new() { Item = "C:\\Users\\DevUser\\Projects\\delta.vi", Count = 1 }
            }
        };

        File.WriteAllText(baselinePath, JsonSerializer.Serialize(baseline, RunnerCliJsonContext.Default.PylaviOffendersReport));
        File.WriteAllText(reportPath, JsonSerializer.Serialize(report, RunnerCliJsonContext.Default.PylaviOffendersReport));

        var args = $"pylavi summarize --path \"{reportPath}\" --baseline \"{baselinePath}\" --json --output-path \"{outputPath}\"";
        var (exitCode, _, stderr) = RunCli(repoRoot, args);

        Assert.Equal(0, exitCode);
        Assert.True(string.IsNullOrWhiteSpace(stderr), $"stderr: {stderr}");
        Assert.True(File.Exists(outputPath), "output path not written");

        using var summaryDoc = JsonDocument.Parse(File.ReadAllText(outputPath));
        var summaryRoot = summaryDoc.RootElement;
        Assert.True(summaryRoot.GetProperty("has_delta").GetBoolean());
        Assert.Equal(1, summaryRoot.GetProperty("delta_total_fails").GetInt32());
        Assert.Equal("delta.vi", summaryRoot.GetProperty("delta_offenders")[0].GetProperty("item").GetString());
        Assert.Equal("C:\\Users\\DevUser\\Projects\\delta.vi", summaryRoot.GetProperty("delta_absolute_offenders")[0].GetProperty("item").GetString());
    }

    [Fact]
    public void PylaviSummarize_fail_on_delta_returns_exit_code_6()
    {
        var repoRoot = FindRepoRoot();
        var tempDir = Directory.CreateTempSubdirectory("lvie-cli-delta-fail");
        var reportPath = Path.Combine(tempDir.FullName, "pylavi-report.json");
        var baselinePath = Path.Combine(tempDir.FullName, "pylavi-baseline.json");

        var baseline = new PylaviOffendersReport
        {
            Label = "pylavi",
            GeneratedUtc = "2026-02-06T12:00:00Z",
            TotalFails = 1,
            ConfiguredRoots = "<redacted>",
            ConfiguredRootCount = 1,
            TopOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "foo.vi", Count = 1 }
            }
        };

        var report = new PylaviOffendersReport
        {
            Label = "pylavi",
            GeneratedUtc = "2026-02-06T12:00:00Z",
            TotalFails = 2,
            ConfiguredRoots = "<redacted>",
            ConfiguredRootCount = 1,
            TopOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "foo.vi", Count = 1 },
                new() { Item = "delta.vi", Count = 1 }
            }
        };

        File.WriteAllText(baselinePath, JsonSerializer.Serialize(baseline, RunnerCliJsonContext.Default.PylaviOffendersReport));
        File.WriteAllText(reportPath, JsonSerializer.Serialize(report, RunnerCliJsonContext.Default.PylaviOffendersReport));

        var args = $"pylavi summarize --path \"{reportPath}\" --baseline \"{baselinePath}\" --fail-on-delta";
        var (exitCode, _, stderr) = RunCli(repoRoot, args);

        Assert.Equal(6, exitCode);
        Assert.Contains("new entries", stderr, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void PylaviSummarize_validate_exists_returns_exit_code_2()
    {
        var repoRoot = FindRepoRoot();
        var tempDir = Directory.CreateTempSubdirectory("lvie-cli-missing");
        var missingPath = Path.Combine(tempDir.FullName, "missing.json");

        var args = $"pylavi summarize --path \"{missingPath}\" --validate-exists";
        var (exitCode, stdout, _) = RunCli(repoRoot, args);

        Assert.Equal(2, exitCode);
        Assert.Contains("PYLAVI_OFFENDERS_EXIT_CODE=2", stdout, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void PylaviSummarize_invalid_json_returns_exit_code_1()
    {
        var repoRoot = FindRepoRoot();
        var tempDir = Directory.CreateTempSubdirectory("lvie-cli-invalid");
        var reportPath = Path.Combine(tempDir.FullName, "invalid.json");
        File.WriteAllText(reportPath, "not-json");

        var args = $"pylavi summarize --path \"{reportPath}\" --json";
        var (exitCode, _, stderr) = RunCli(repoRoot, args);

        Assert.Equal(1, exitCode);
        Assert.Contains("ERROR", stderr, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void PylaviSummarize_orders_ranked_arrays_deterministically()
    {
        var repoRoot = FindRepoRoot();
        var tempDir = Directory.CreateTempSubdirectory("lvie-cli-ordering");
        var reportPath = Path.Combine(tempDir.FullName, "pylavi-report.json");
        var baselinePath = Path.Combine(tempDir.FullName, "pylavi-baseline.json");
        var outputPath = Path.Combine(tempDir.FullName, "pylavi-summary.json");

        var baseline = new PylaviOffendersReport
        {
            Label = "pylavi",
            GeneratedUtc = "2026-02-06T12:00:00Z",
            TotalFails = 3,
            ConfiguredRoots = "<redacted>",
            ConfiguredRootCount = 1,
            TopOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "Alpha2.vi", Count = 3 }
            },
            TopAbsoluteOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "C:\\Alpha2.vi", Count = 3 }
            }
        };

        var report = new PylaviOffendersReport
        {
            Label = "pylavi",
            GeneratedUtc = "2026-02-07T12:00:00Z",
            TotalFails = 9,
            ConfiguredRoots = "<redacted>",
            ConfiguredRootCount = 1,
            TopOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "zeta.vi", Count = 2 },
                new() { Item = "Alpha.vi", Count = 2 },
                new() { Item = "beta.vi", Count = 2 },
                new() { Item = "Alpha2.vi", Count = 3 }
            },
            TopAbsoluteOffenders = new List<PylaviOffenderEntry>
            {
                new() { Item = "C:\\zeta.vi", Count = 2 },
                new() { Item = "C:\\Alpha.vi", Count = 2 },
                new() { Item = "C:\\beta.vi", Count = 2 },
                new() { Item = "C:\\Alpha2.vi", Count = 3 }
            }
        };

        File.WriteAllText(reportPath, JsonSerializer.Serialize(report, RunnerCliJsonContext.Default.PylaviOffendersReport));
        File.WriteAllText(baselinePath, JsonSerializer.Serialize(baseline, RunnerCliJsonContext.Default.PylaviOffendersReport));

        var args = $"pylavi summarize --path \"{reportPath}\" --baseline \"{baselinePath}\" --json --output-path \"{outputPath}\"";
        var (exitCode, _, stderr) = RunCli(repoRoot, args);

        Assert.Equal(0, exitCode);
        Assert.True(string.IsNullOrWhiteSpace(stderr), $"stderr: {stderr}");

        using var summaryDoc = JsonDocument.Parse(File.ReadAllText(outputPath));
        var summaryRoot = summaryDoc.RootElement;

        AssertItemOrder(summaryRoot.GetProperty("top_offenders"), "Alpha2.vi", "Alpha.vi", "beta.vi", "zeta.vi");
        AssertItemOrder(summaryRoot.GetProperty("top_absolute_offenders"), "C:\\Alpha2.vi", "C:\\Alpha.vi", "C:\\beta.vi", "C:\\zeta.vi");
        AssertItemOrder(summaryRoot.GetProperty("delta_offenders"), "Alpha.vi", "beta.vi", "zeta.vi");
        AssertItemOrder(summaryRoot.GetProperty("delta_absolute_offenders"), "C:\\Alpha.vi", "C:\\beta.vi", "C:\\zeta.vi");
    }

    [Fact]
    public void PylaviScan_report_only_emits_command_and_info_to_stderr()
    {
        var repoRoot = FindRepoRoot();
        var tempDir = Directory.CreateTempSubdirectory("lvie-cli-scan-stream");
        var offendersPath = Path.Combine(tempDir.FullName, "offenders.json");
        var logPath = Path.Combine(tempDir.FullName, "vi_validate.log");
        var configPath = Path.Combine(repoRoot, "Tooling", "pylavi", "vi-validate.yml");
        var stubPathRoot = CreateViValidateStub(exitCode: 2, line: "FAIL: synthetic failure");
        var existingPath = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        var env = new Dictionary<string, string?>
        {
            ["PATH"] = $"{stubPathRoot}{Path.PathSeparator}{existingPath}",
            ["GITHUB_ACTIONS"] = "false"
        };

        var args = $"pylavi scan --repo-root \"{repoRoot}\" --config \"{configPath}\" --skip-version-gate --report-only --json --offenders-path \"{offendersPath}\" --log-path \"{logPath}\"";
        var (exitCode, stdout, stderr) = RunCli(repoRoot, args, env);

        Assert.Equal(0, exitCode);
        Assert.Contains("vi_validate command", stderr, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("vi_validate exit code", stderr, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("vi_validate command", stdout, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("vi_validate exit code", stdout, StringComparison.OrdinalIgnoreCase);

        using var json = JsonDocument.Parse(stdout);
        Assert.True(TryGetPropertyIgnoreCase(json.RootElement, "total_fails", out _));
    }

    [Fact]
    public void MissingInProject_emits_command_echo_to_stderr_on_windows()
    {
        if (!OperatingSystem.IsWindows())
        {
            return;
        }

        var repoRoot = FindRepoRoot();
        var projectPath = Path.Combine(repoRoot, "lv_icon_editor.lvproj");
        var args = $"missing-in-project --repo-root \"{repoRoot}\" --arch 64 --project-file \"{projectPath}\" --skip-worktree-root-check";
        var (_, stdout, stderr) = RunCli(repoRoot, args);

        Assert.Contains("missing-in-project command:", stderr, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("missing-in-project command:", stdout, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void MissingInProject_on_non_windows_returns_clear_error()
    {
        if (OperatingSystem.IsWindows())
        {
            return;
        }

        var repoRoot = FindRepoRoot();
        var args = "missing-in-project --repo-root \"" + repoRoot + "\" --arch 64 --project-file \"" + Path.Combine(repoRoot, "lv_icon_editor.lvproj") + "\"";
        var (exitCode, _, stderr) = RunCli(repoRoot, args);

        Assert.Equal(1, exitCode);
        Assert.Contains("only supported on Windows", stderr, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void PublishedBinary_runs_version_gate_and_pylavi()
    {
        var repoRoot = FindRepoRoot();
        var cliPath = EnsurePublishedBinary(repoRoot);
        var fixture = Path.Combine(repoRoot, "Tooling", "pylavi", "fixtures", "pylavi-offenders.sample.json");
        var outputPath = Path.Combine(Path.GetTempPath(), $"pylavi-summary-{Guid.NewGuid():N}.json");

        var (exitCode, stdout, stderr) = RunBinary(cliPath, new[]
        {
            "version-gate",
            "--repo-root",
            repoRoot,
            "--json"
        });

        Assert.Equal(0, exitCode);
        Assert.True(string.IsNullOrWhiteSpace(stderr), $"stderr: {stderr}");
        using (var doc = JsonDocument.Parse(stdout))
        {
            var root = doc.RootElement;
            Assert.True(TryGetPropertyIgnoreCase(root, "year", out _), "year missing");
        }

        var (pylaviExit, pylaviStdout, pylaviStderr) = RunBinary(cliPath, new[]
        {
            "pylavi",
            "summarize",
            "--path",
            fixture,
            "--json",
            "--output-path",
            outputPath
        });

        Assert.Equal(0, pylaviExit);
        Assert.True(string.IsNullOrWhiteSpace(pylaviStderr), $"stderr: {pylaviStderr}");
        Assert.True(File.Exists(outputPath), "output path not written");
        using var pylaviDoc = JsonDocument.Parse(pylaviStdout);
        Assert.True(TryGetPropertyIgnoreCase(pylaviDoc.RootElement, "label", out _), "label missing");
    }

    private static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            var marker = Path.Combine(dir.FullName, ".lvversion");
            if (File.Exists(marker))
            {
                return dir.FullName;
            }
            dir = dir.Parent;
        }

        throw new DirectoryNotFoundException("Repo root not found (missing .lvversion).");
    }

    private static (int ExitCode, string StdOut, string StdErr) RunCli(
        string repoRoot,
        string args,
        IDictionary<string, string?>? environmentOverrides = null)
    {
        var dllPath = ResolveRunnerCliDll(repoRoot);
        var runArgs = dllPath is null
            ? BuildDotnetRunArgs(repoRoot, args)
            : $"\"{dllPath}\" {args}";

        var psi = new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = runArgs,
            WorkingDirectory = repoRoot,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        if (environmentOverrides is not null)
        {
            foreach (var entry in environmentOverrides)
            {
                psi.Environment[entry.Key] = entry.Value ?? string.Empty;
            }
        }

        using var process = Process.Start(psi);
        if (process is null)
        {
            throw new InvalidOperationException("Failed to start dotnet process.");
        }

        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        return (process.ExitCode, stdout.Trim(), stderr.Trim());
    }

    private static string BuildDotnetRunArgs(string repoRoot, string args)
    {
        var projectPath = Path.Combine(repoRoot, "Tooling", "runner-cli", "RunnerCli", "RunnerCli.csproj");
        if (!File.Exists(projectPath))
        {
            throw new FileNotFoundException("RunnerCli.csproj not found.", projectPath);
        }

        return $"run --project \"{projectPath}\" --configuration Release -- {args}";
    }

    private static string? ResolveRunnerCliDll(string repoRoot)
    {
        var outputRoot = Path.Combine(repoRoot, "Tooling", "runner-cli", "RunnerCli", "bin", "Release", "net8.0");
        if (!Directory.Exists(outputRoot))
        {
            return null;
        }

        var dlls = Directory.GetFiles(outputRoot, "runner-cli.dll", SearchOption.AllDirectories);
        if (dlls.Length == 0)
        {
            return null;
        }

        return dlls[0];
    }

    private static string EnsurePublishedBinary(string repoRoot)
    {
        var (rid, exeName) = GetRuntimeInfo();
        var outputDir = Path.Combine(Path.GetTempPath(), $"runner-cli-publish-{rid}");
        Directory.CreateDirectory(outputDir);

        var cliPath = Path.Combine(outputDir, exeName);
        if (File.Exists(cliPath))
        {
            return cliPath;
        }

        var projectPath = Path.Combine(repoRoot, "Tooling", "runner-cli", "RunnerCli", "RunnerCli.csproj");
        if (!File.Exists(projectPath))
        {
            throw new FileNotFoundException("RunnerCli.csproj not found.", projectPath);
        }

        var publishArgs = string.Join(' ', new[]
        {
            "publish",
            $"\"{projectPath}\"",
            "--configuration", "Release",
            "--runtime", rid,
            "--self-contained", "true",
            "-p:PublishSingleFile=true",
            "-p:PublishTrimmed=true",
            "--output", $"\"{outputDir}\""
        });

        var (exitCode, _, stderr) = RunProcess("dotnet", publishArgs, repoRoot);
        if (exitCode != 0)
        {
            throw new InvalidOperationException($"dotnet publish failed: {stderr}");
        }

        if (!File.Exists(cliPath))
        {
            throw new FileNotFoundException("Published runner-cli not found.", cliPath);
        }

        if (!OperatingSystem.IsWindows())
        {
            RunProcess("chmod", $"+x \"{cliPath}\"", repoRoot);
        }

        return cliPath;
    }

    private static (string Rid, string ExeName) GetRuntimeInfo()
    {
        if (OperatingSystem.IsWindows())
        {
            return ("win-x64", "runner-cli.exe");
        }

        if (OperatingSystem.IsMacOS())
        {
            return (System.Runtime.InteropServices.RuntimeInformation.OSArchitecture == System.Runtime.InteropServices.Architecture.Arm64
                ? "osx-arm64"
                : "osx-x64", "runner-cli");
        }

        return (System.Runtime.InteropServices.RuntimeInformation.OSArchitecture == System.Runtime.InteropServices.Architecture.Arm64
            ? "linux-arm64"
            : "linux-x64", "runner-cli");
    }

    private static (int ExitCode, string StdOut, string StdErr) RunBinary(string path, IEnumerable<string> arguments)
    {
        var psi = new ProcessStartInfo
        {
            FileName = path,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        foreach (var arg in arguments)
        {
            psi.ArgumentList.Add(arg);
        }

        using var process = Process.Start(psi);
        if (process is null)
        {
            throw new InvalidOperationException("Failed to start runner-cli binary.");
        }

        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();
        return (process.ExitCode, stdout.Trim(), stderr.Trim());
    }

    private static string CreateViValidateStub(int exitCode, string line)
    {
        var dir = Directory.CreateTempSubdirectory("vi-validate-stub").FullName;
        if (OperatingSystem.IsWindows())
        {
            // Use powershell.exe as a deterministic non-zero shim for unsupported args.
            var psExe = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe");
            File.Copy(psExe, Path.Combine(dir, "vi_validate.exe"));
            return dir;
        }

        var scriptPath = Path.Combine(dir, "vi_validate");
        File.WriteAllText(scriptPath, $"#!/usr/bin/env sh{Environment.NewLine}echo \"{line}\"{Environment.NewLine}exit {exitCode}{Environment.NewLine}");
        var (_, _, stderr) = RunProcess("chmod", $"+x \"{scriptPath}\"", dir);
        if (!string.IsNullOrWhiteSpace(stderr))
        {
            throw new InvalidOperationException($"chmod failed for vi_validate stub: {stderr}");
        }
        return dir;
    }

    private static void AssertItemOrder(JsonElement array, params string[] expectedItems)
    {
        var actualItems = array
            .EnumerateArray()
            .Select(element => element.GetProperty("item").GetString())
            .ToArray();
        Assert.Equal(expectedItems, actualItems);
    }

    private static (int ExitCode, string StdOut, string StdErr) RunProcess(string fileName, string args, string workingDirectory)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = args,
            WorkingDirectory = workingDirectory,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(psi);
        if (process is null)
        {
            throw new InvalidOperationException($"Failed to start {fileName}.");
        }

        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();
        return (process.ExitCode, stdout.Trim(), stderr.Trim());
    }

    private static bool TryGetPropertyIgnoreCase(JsonElement element, string name, out JsonElement value)
    {
        foreach (var prop in element.EnumerateObject())
        {
            if (string.Equals(prop.Name, name, StringComparison.OrdinalIgnoreCase))
            {
                value = prop.Value;
                return true;
            }
        }

        value = default;
        return false;
    }
}
