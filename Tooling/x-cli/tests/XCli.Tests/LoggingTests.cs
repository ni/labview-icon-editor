using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Threading;
using System.Collections.Generic;
using System.Linq;
using System.IO;
using System.Diagnostics;
using System.Reflection;
using XCli.Logging;
using XCli.Simulation;
using XCli.Cli;
using XCli.Util;
using XCli.Tests.TestInfra;
using TestUtil;
using Xunit;

// FGC-REQ-QA-001
public class LoggingTests
{
    public LoggingTests() => Env.ResetCacheForTests();

    private static string ProjectDir => Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../src/XCli"));

    private static ProcessRunner.CliResult Run(string sub, IDictionary<string, string>? env = null, params string[] payload)
        => ProcessRunner.RunAsync(sub, payload, env).GetAwaiter().GetResult();

    private static void SetEnv(string name, string? value)
    {
        Environment.SetEnvironmentVariable(name, value);
        Env.ResetCacheForTests();
    }

    private static string LastJsonLine(string stderr) => stderr
        .Split('\n')
        .Reverse()
        .First(l => l.TrimStart().StartsWith("{"));

    [Fact]
    public void StderrIsJsonAndStdoutClean()
    {
        var r = Run("vitester");
        Assert.DoesNotContain("timestampUtc", r.StdOut);
        var json = LastJsonLine(r.StdErr);
        var doc = JsonDocument.Parse(json);
        foreach (var key in new[] {"timestampUtc","pid","os","subcommand","args","env","result","exitCode","message","durationMs"})
            Assert.True(doc.RootElement.TryGetProperty(key, out _), $"missing {key}");
        var os = doc.RootElement.GetProperty("os").GetString();
        if (OperatingSystem.IsWindows())
            Assert.Equal("Windows", os);
        else if (OperatingSystem.IsLinux())
            Assert.Equal("Linux", os);
        else if (OperatingSystem.IsMacOS())
            Assert.Equal("macOS", os);
        else
            Assert.Equal("Unknown", os);

        var sub = doc.RootElement.GetProperty("subcommand").GetString();
        Assert.NotNull(sub);
        var extras = new[] { "help", "version", "missing", "unknown" };
        Assert.True(Cli.Subcommands.Contains(sub!) || extras.Contains(sub));
    }

    [Fact]
    public void EnvKeysPreserveCasingInLog()
    {
        var mixed = "XCLI_mIxEd_" + Guid.NewGuid().ToString("N");
        var env = new Dictionary<string,string>{{mixed, "1"}};
        var r = Run("vitester", env);
        var json = LastJsonLine(r.StdErr);
        using var doc = JsonDocument.Parse(json);
        var envObj = doc.RootElement.GetProperty("env");
        Assert.True(envObj.TryGetProperty(mixed, out var val));
        Assert.Equal("1", val.GetString());
        Assert.False(envObj.TryGetProperty(mixed.ToUpperInvariant(), out _));
    }

    [Theory]
    [InlineData("-1")]
    [InlineData("0")]
    public void NegativeOrZeroAttemptsRevertToDefault(string value)
    {
        var prev = Environment.GetEnvironmentVariable("XCLI_LOG_MAX_ATTEMPTS");
        try
        {
            SetEnv("XCLI_LOG_MAX_ATTEMPTS", value);
            var logger = new InvocationLogger();
            var field = typeof(InvocationLogger).GetField("_maxFileWriteAttempts", BindingFlags.NonPublic | BindingFlags.Instance)!;
            var attempts = (int)field.GetValue(logger)!;
            Assert.Equal(200, attempts);
        }
        finally
        {
            SetEnv("XCLI_LOG_MAX_ATTEMPTS", prev);
        }
    }

    [Fact]
    public async Task FileLoggingIsConcurrentSafe()
    {
        var path = Path.GetTempFileName();
        const int count = 4;
        var tasks = Enumerable.Range(0, count)
            .Select(i => Task.Run(() =>
            {
                var env = new Dictionary<string,string>{{"XCLI_LOG_PATH", path},{"XCLI_TAG", i.ToString()}};
                return Run("vitester", env);
            }))
            .ToArray();
        await Task.WhenAll(tasks);
        var lines = File.ReadAllLines(path);
        Assert.True(lines.Length >= 2, $"expected at least 2 lines, got {lines.Length}");
        var tags = new HashSet<int>();
        foreach (var line in lines)
        {
            using var doc = JsonDocument.Parse(line);
            var envObj = doc.RootElement.GetProperty("env");
            Assert.True(envObj.TryGetProperty("XCLI_TAG", out var tagProp));
            var tag = int.Parse(tagProp.GetString()!);
            Assert.InRange(tag, 0, count - 1);
            Assert.True(tags.Add(tag), $"duplicate tag {tag}");
        }
    }

    [Fact]
    public void FileLoggingDoesNotIncludeBom()
    {
        var path = Path.GetTempFileName();
        var env = new Dictionary<string,string>{{"XCLI_LOG_PATH", path}};
        Run("vitester", env);
        var bytes = File.ReadAllBytes(path);
        Assert.False(bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF, "BOM detected");
    }

    [Fact]
    public void CreatesDirectoryWhenMissing()
    {
        var dir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        var path = Path.Combine(dir, "log.jsonl");
        var env = new Dictionary<string,string>{{"XCLI_LOG_PATH", path}};
        try
        {
            Run("vitester", env);
            Assert.True(File.Exists(path), $"missing log file at {path}");
            var lines = File.ReadAllLines(path);
            Assert.True(lines.Length >= 1, "log file empty");
        }
        finally
        {
            if (Directory.Exists(dir))
                Directory.Delete(dir, true);
        }
    }

    [Fact]
    public void MessageFieldReflectsOutcome()
    {
        var success = Run("vitester");
        var successDoc = JsonDocument.Parse(LastJsonLine(success.StdErr));
        Assert.Equal(string.Empty, successDoc.RootElement.GetProperty("message").GetString());

        var envDefault = new Dictionary<string,string>{{"XCLI_FAIL","true"}};
        var defaultFail = Run("vitester", envDefault);
        var defaultDoc = JsonDocument.Parse(LastJsonLine(defaultFail.StdErr));
        Assert.Equal("unspecified failure", defaultDoc.RootElement.GetProperty("message").GetString());

        var env = new Dictionary<string,string>{{"XCLI_FAIL","true"},{"XCLI_MESSAGE","boom"}};
        var failure = Run("vitester", env);
        var failureDoc = JsonDocument.Parse(LastJsonLine(failure.StdErr));
        Assert.Equal("boom", failureDoc.RootElement.GetProperty("message").GetString());
    }

    [Fact]
    // FGC-REQ-SIM-004
    public void DurationReflectsConfiguredDelay()
    {
        const int delay = 50;
        var env = new Dictionary<string,string>{{"XCLI_DELAY_MS", delay.ToString()}};
        var r = Run("vitester", env);
        var json = LastJsonLine(r.StdErr);
        var doc = JsonDocument.Parse(json);
        var duration = doc.RootElement.GetProperty("durationMs").GetInt64();
        Assert.True(duration >= delay, $"duration {duration} < configured {delay}");
    }

    [Fact]
    // FGC-REQ-SIM-004
    public void WarnsWhenDurationExceedsThreshold()
    {
        const int delay = 20;
        var env = new Dictionary<string,string>
        {
            {"XCLI_DELAY_MS", delay.ToString()},
            {"XCLI_MAX_DURATION_MS", "1"},
        };
        var r = Run("vitester", env);
        var lines = r.StdErr.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(2, lines.Length);
        Assert.StartsWith("{", lines[0].TrimStart());
        Assert.StartsWith("[x-cli] warning: duration", lines[1].TrimStart());
    }

    [Theory]
    [InlineData("--help", "help", 0, "")]
    [InlineData("--version", "version", 0, "")]
    [InlineData("", "missing", 1, "missing subcommand")]
    [InlineData("unknown", "unknown", 1, "error: unknown subcommand 'unknown'. See --help.")]
    public void SpecialPathsEmitJsonLog(string args, string expectedSub, int exit, string expectedMessage)
    {
        var r = ProcRunner.Run("dotnet", $"run --no-build -c Release -- {args}", null, ProjectDir);
        Assert.Equal(exit, r.ExitCode);
        var json = LastJsonLine(r.StdErr);
        var doc = JsonDocument.Parse(json);
        Assert.Equal(expectedSub, doc.RootElement.GetProperty("subcommand").GetString());
        Assert.Equal(expectedMessage, doc.RootElement.GetProperty("message").GetString());
    }

    private sealed class ThrowingOnceWriter : TextWriter
    {
        private bool _thrown;
        private readonly StringBuilder _sb = new();
        public override Encoding Encoding => Encoding.UTF8;
        public override void WriteLine(string? value)
        {
            if (!_thrown)
            {
                _thrown = true;
                throw new IOException("boom");
            }
            _sb.AppendLine(value);
        }
        public override string ToString() => _sb.ToString();
    }

    [Fact]
    public void DebugModeSurfacesConsoleWriteErrors()
    {
        var original = Console.Error;
        var writer = new ThrowingOnceWriter();
        var prev = Environment.GetEnvironmentVariable("XCLI_DEBUG");
        try
        {
            Console.SetError(writer);
            SetEnv("XCLI_DEBUG", "true");
            var logger = new InvocationLogger(maxFileWriteAttempts: 3);
            logger.Log("sub", Array.Empty<string>(), string.Empty, new SimulationResult(true, 0), 1L);
        }
        finally
        {
            Console.SetError(original);
            SetEnv("XCLI_DEBUG", prev);
        }
        Assert.Contains("boom", writer.ToString());
    }

    [Fact]
    // FGC-REQ-ROB-002
    public void DebugModeSurfacesFileWriteErrors()
    {
        var dir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(dir);
        var original = Console.Error;
        var sw = new StringWriter();
        var prevPath = Environment.GetEnvironmentVariable("XCLI_LOG_PATH");
        var prevDebug = Environment.GetEnvironmentVariable("XCLI_DEBUG");
        try
        {
            Console.SetError(sw);
            SetEnv("XCLI_LOG_PATH", dir);
            SetEnv("XCLI_DEBUG", "true");
            var logger = new InvocationLogger(maxFileWriteAttempts: 3);
            logger.Log("sub", Array.Empty<string>(), string.Empty, new SimulationResult(true, 0), 1L);
        }
        finally
        {
            Console.SetError(original);
            SetEnv("XCLI_LOG_PATH", prevPath);
            SetEnv("XCLI_DEBUG", prevDebug);
            Directory.Delete(dir);
        }
        var lines = sw.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.True(lines.Length >= 1);
        Assert.Contains("Exception", string.Join('\n', lines));
    }

    [Fact]
    public async Task ConcurrentLoggingSkipsWhenLockUnavailable()
    {
        var dir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(dir);
        var prevPath = Environment.GetEnvironmentVariable("XCLI_LOG_PATH");
        var prevDebug = Environment.GetEnvironmentVariable("XCLI_DEBUG");
        var original = Console.Error;
        var sw = new StringWriter();
        try
        {
            SetEnv("XCLI_LOG_PATH", dir);
            SetEnv("XCLI_DEBUG", "true");
            Console.SetError(TextWriter.Synchronized(sw));
            var logger = new InvocationLogger(maxFileWriteAttempts: 3);
            const int count = 3;
            var tasks = Enumerable.Range(0, count)
                .Select(_ => Task.Run(() => logger.Log("sub", Array.Empty<string>(), string.Empty, new SimulationResult(true, 0), 1L)))
                .ToArray();
            await Task.WhenAll(tasks);
        }
        finally
        {
            Console.SetError(original);
            SetEnv("XCLI_LOG_PATH", prevPath);
            SetEnv("XCLI_DEBUG", prevDebug);
            Directory.Delete(dir);
        }
        var diagCount = sw.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries)
            .Count(l => l.Contains("Exception"));
        Assert.True(diagCount >= 3);
    }

    // FGC-REQ-LOG-001: debug mode shall emit diagnostics when the log file is locked
    // This test locks the log file before invoking the logger to verify that debug mode surfaces the failure
    // and still records the log line once the lock clears.
    [Fact(Timeout = 5000)]
    public async Task DebugModeSurfacesLockFailures()
    {
        if (!OperatingSystem.IsWindows() && !OperatingSystem.IsLinux() && !OperatingSystem.IsMacOS())
            return;
        var path = Path.GetTempFileName();
        var original = Console.Error;
        var sw = new StringWriter();
        var prevPath = Environment.GetEnvironmentVariable("XCLI_LOG_PATH");
        var prevDebug = Environment.GetEnvironmentVariable("XCLI_DEBUG");
        string[]? fileLines = null;
        FileStream? lockStream = null;
        try
        {
            lockStream = new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            var release = Task.Run(async () =>
            {
                await Task.Delay(100);
                lockStream.Dispose();
            });

            Console.SetError(sw);
            SetEnv("XCLI_LOG_PATH", path);
            SetEnv("XCLI_DEBUG", "true");
            SetEnv("XCLI_LOG_MAX_ATTEMPTS", "20");

            var logger = new InvocationLogger();
            logger.Log("sub", Array.Empty<string>(), string.Empty, new SimulationResult(true, 0), 1L);

            await release;
            fileLines = File.ReadAllLines(path);
        }
        finally
        {
            Console.SetError(original);
            SetEnv("XCLI_LOG_PATH", prevPath);
            SetEnv("XCLI_DEBUG", prevDebug);
            SetEnv("XCLI_LOG_MAX_ATTEMPTS", null);
            lockStream?.Dispose();
            File.Delete(path);
        }
        var lines = sw.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Contains(lines, l => l.Contains("Exception"));
        Assert.NotNull(fileLines);
        Assert.Single(fileLines);
    }

    // FGC-REQ-LOG-001: non-debug mode shall suppress diagnostics when the log file is locked
    // This test holds a lock without debug mode to confirm that no diagnostic output is written
    // while the log entry is still persisted after the lock releases.
    [Fact(Timeout = 5000)]
    public async Task LockFailureSilentWhenDebugDisabled()
    {
        if (!OperatingSystem.IsWindows() && !OperatingSystem.IsLinux() && !OperatingSystem.IsMacOS())
            return;
        var path = Path.GetTempFileName();
        var original = Console.Error;
        var sw = new StringWriter();
        var prevPath = Environment.GetEnvironmentVariable("XCLI_LOG_PATH");
        var prevDebug = Environment.GetEnvironmentVariable("XCLI_DEBUG");
        string[]? fileLines = null;
        FileStream? lockStream = null;
        try
        {
            lockStream = new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            var release = Task.Run(async () =>
            {
                await Task.Delay(100);
                lockStream.Dispose();
            });

            Console.SetError(sw);
            SetEnv("XCLI_LOG_PATH", path);
            SetEnv("XCLI_DEBUG", null);
            SetEnv("XCLI_LOG_MAX_ATTEMPTS", "20");

            var logger = new InvocationLogger();
            logger.Log("sub", Array.Empty<string>(), string.Empty, new SimulationResult(true, 0), 1L);

            await release;
            fileLines = File.ReadAllLines(path);
        }
        finally
        {
            Console.SetError(original);
            SetEnv("XCLI_LOG_PATH", prevPath);
            SetEnv("XCLI_DEBUG", prevDebug);
            SetEnv("XCLI_LOG_MAX_ATTEMPTS", null);
            lockStream?.Dispose();
            File.Delete(path);
        }
        Assert.NotNull(fileLines);
        Assert.Single(fileLines);
        var lines = sw.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Single(lines);
        Assert.StartsWith("{", lines[0].TrimStart());
    }

    [Fact]
    public void UnwritablePathAbortsAfterMaxRetries()
    {
        var dir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(dir);
        var prev = Environment.GetEnvironmentVariable("XCLI_LOG_PATH");
        var prevAttempts = Environment.GetEnvironmentVariable("XCLI_LOG_MAX_ATTEMPTS");
        var original = Console.Error;
        try
        {
            SetEnv("XCLI_LOG_PATH", dir);
            const int attempts = 5;
            SetEnv("XCLI_LOG_MAX_ATTEMPTS", attempts.ToString());
            var sw = new StringWriter();
            Console.SetError(TextWriter.Synchronized(sw));
            var logger = new InvocationLogger();
            var watch = Stopwatch.StartNew();
            logger.Log("sub", Array.Empty<string>(), string.Empty, new SimulationResult(true, 0), 1L);
            watch.Stop();
            var lines = sw.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries);
            Assert.Equal(2, lines.Length);
            Assert.Contains("failed to write log", lines[0]);
            Assert.StartsWith("{", lines[1]);
            Assert.True(watch.ElapsedMilliseconds < attempts * 100);
        }
        finally
        {
            Console.SetError(original);
            SetEnv("XCLI_LOG_PATH", prev);
            SetEnv("XCLI_LOG_MAX_ATTEMPTS", prevAttempts);
            Directory.Delete(dir);
        }
    }

    [Fact]
    public void LockedFileTimesOut()
    {
        var path = Path.GetTempFileName();
        using var holder = new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.None);
        var prevPath = Environment.GetEnvironmentVariable("XCLI_LOG_PATH");
        var prevDebug = Environment.GetEnvironmentVariable("XCLI_DEBUG");
        var prevTimeout = Environment.GetEnvironmentVariable("XCLI_LOG_TIMEOUT_MS");
        var original = Console.Error;
        try
        {
            SetEnv("XCLI_LOG_PATH", path);
            SetEnv("XCLI_DEBUG", "true");
            SetEnv("XCLI_LOG_TIMEOUT_MS", "100");
            var sw = new StringWriter();
            Console.SetError(TextWriter.Synchronized(sw));
            var logger = new InvocationLogger();
            var watch = Stopwatch.StartNew();
            logger.Log("sub", Array.Empty<string>(), string.Empty, new SimulationResult(true, 0), 1L);
            watch.Stop();
            var cap = OperatingSystem.IsWindows() ? 2500 : 1000;
            Assert.True(watch.ElapsedMilliseconds < cap, $"took {watch.ElapsedMilliseconds}ms");
            var lines = sw.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries);
            Assert.Contains(lines, l => l.Contains("log write timeout"));
        }
        finally
        {
            Console.SetError(original);
            SetEnv("XCLI_LOG_PATH", prevPath);
            SetEnv("XCLI_DEBUG", prevDebug);
            SetEnv("XCLI_LOG_TIMEOUT_MS", prevTimeout);
            holder.Dispose();
            File.Delete(path);
        }
    }

    [Fact]
    public void NegativeTimeoutClampedToZero()
    {
        var path = Path.GetTempFileName();
        var prevPath = Environment.GetEnvironmentVariable("XCLI_LOG_PATH");
        var prevDebug = Environment.GetEnvironmentVariable("XCLI_DEBUG");
        var prevTimeout = Environment.GetEnvironmentVariable("XCLI_LOG_TIMEOUT_MS");
        var original = Console.Error;
        try
        {
            SetEnv("XCLI_LOG_PATH", path);
            SetEnv("XCLI_DEBUG", "true");
            SetEnv("XCLI_LOG_TIMEOUT_MS", "-5");
            var sw = new StringWriter();
            Console.SetError(TextWriter.Synchronized(sw));
            var logger = new InvocationLogger();
            logger.Log("sub", Array.Empty<string>(), string.Empty, new SimulationResult(true, 0), 1L);
            var lines = sw.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries);
            Assert.Contains(lines, l => l.Contains("negative XCLI_LOG_TIMEOUT_MS"));
            Assert.Contains(lines, l => l.Contains("log write timeout"));
        }
        finally
        {
            Console.SetError(original);
            SetEnv("XCLI_LOG_PATH", prevPath);
            SetEnv("XCLI_DEBUG", prevDebug);
            SetEnv("XCLI_LOG_TIMEOUT_MS", prevTimeout);
            File.Delete(path);
        }
    }

    [Fact]
    public void DebugStackTracesPrecedeJson()
    {
        var dir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(dir);
        var prevPath = Environment.GetEnvironmentVariable("XCLI_LOG_PATH");
        var prevDebug = Environment.GetEnvironmentVariable("XCLI_DEBUG");
        var original = Console.Error;
        try
        {
            SetEnv("XCLI_LOG_PATH", dir);
            SetEnv("XCLI_DEBUG", "true");
            var sw = new StringWriter();
            Console.SetError(sw);
            var logger = new InvocationLogger();
            logger.Log("sub", Array.Empty<string>(), string.Empty, new SimulationResult(true, 0), 1L);
            var lines = sw.ToString().Split('\n', StringSplitOptions.RemoveEmptyEntries);
            Assert.True(lines.Length >= 2);
            var jsonIdx = Array.FindLastIndex(lines, l => l.TrimStart().StartsWith("{"));
            Assert.Equal(lines.Length - 1, jsonIdx);
            var stackIdx = Array.FindIndex(lines, l => l.Contains("Exception"));
            Assert.True(stackIdx >= 0 && stackIdx < jsonIdx, "stack trace should precede JSON log");
        }
        finally
        {
            Console.SetError(original);
            SetEnv("XCLI_LOG_PATH", prevPath);
            SetEnv("XCLI_DEBUG", prevDebug);
            Directory.Delete(dir);
        }
    }

    [Fact]
    public async Task AllInvocationsLoggedUnderHighContention()
    {
        var path = Path.GetTempFileName();
        const int count = 6;
        try
        {
            var tasks = Enumerable.Range(0, count)
                .Select(_ => Task.Run(() =>
                {
                    var env = new Dictionary<string,string>{{"XCLI_LOG_PATH", path}};
                    return Run("vitester", env);
                }))
                .ToArray();
            var results = await Task.WhenAll(tasks);
            Assert.All(results, r =>
            {
                Assert.DoesNotContain("[x-cli] failed to write log", r.StdErr);
                Assert.DoesNotContain("[x-cli] log write timeout", r.StdErr);
            });
            var lines = Array.Empty<string>();
            var attempts = 0;
            var max = 0;
            var watch = Stopwatch.StartNew();
            for (; attempts < 500 && lines.Length < count; attempts++)
            {
                lines = File.ReadAllLines(path);
                if (lines.Length > max) max = lines.Length;
                if (lines.Length < count)
                    await Task.Delay(20);
            }
            watch.Stop();
            Assert.True(lines.Length == count,
                $"expected {count} lines, got {lines.Length} after {attempts} attempts/{watch.ElapsedMilliseconds}ms (max {max})");
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void HelperRetriesUntilFailure()
    {
        var dir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(dir);
        var logger = new InvocationLogger(maxFileWriteAttempts: 3);
        var method = typeof(InvocationLogger).GetMethod("TryWriteFile", BindingFlags.NonPublic | BindingFlags.Instance)!;
        var bytes = Encoding.UTF8.GetBytes("{}\n");
        var debug = new List<string>();
        var result = ((bool wrote, bool timedOut))method.Invoke(logger, new object[] { dir, bytes, 1000, debug })!;
        Directory.Delete(dir);
        Assert.False(result.wrote);
        Assert.False(result.timedOut);
        Assert.True(debug.Count >= 3);
    }

    [Fact]
    public void HelperTimesOutWhenFileLocked()
    {
        var path = Path.GetTempFileName();
        using var holder = new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.None);
        var logger = new InvocationLogger();
        var method = typeof(InvocationLogger).GetMethod("TryWriteFile", BindingFlags.NonPublic | BindingFlags.Instance)!;
        var bytes = Encoding.UTF8.GetBytes("{}\n");
        var debug = new List<string>();
        var result = ((bool wrote, bool timedOut))method.Invoke(logger, new object[] { path, bytes, 100, debug })!;
        Assert.False(result.wrote);
        Assert.True(result.timedOut);
        Assert.Contains(debug, l => l.Contains("log write loop timed out"));
        holder.Dispose();
        File.Delete(path);
    }

    [Fact]
    public void LogWriteFailureDoesNotAlterExitCode()
    {
        var dir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(dir);
        try
        {
            var env = new Dictionary<string,string>
            {
                {"XCLI_LOG_PATH", dir},
                {"XCLI_LOG_MAX_ATTEMPTS", "1"}
            };
            var r = Run("vitester", env);
            Assert.Equal(0, r.ExitCode);
            Assert.Contains("[x-cli] failed to write log", r.StdErr);
        }
        finally
        {
            Directory.Delete(dir);
        }
    }
}
