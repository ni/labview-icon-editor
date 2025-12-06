// ModuleIndex: emits JSONL logs for each invocation.
using System.Diagnostics;
using System.Collections.Generic;
using System.Text.Json;
using System.Text;
using System.Threading;
using System.IO;
using XCli.Simulation;
using XCli.Util;

namespace XCli.Logging;

public class InvocationLogger
{
    private readonly int _maxFileWriteAttempts;

    public InvocationLogger(int? maxFileWriteAttempts = null)
    {
        var attempts = maxFileWriteAttempts ?? Env.GetInt("XCLI_LOG_MAX_ATTEMPTS", 200);
        if (attempts < 1)
            attempts = 200;
        _maxFileWriteAttempts = attempts;
    }

    public void Log(string subcommand, string[] args, string message, SimulationResult result, long durationMs)
    {
        var env = Env.GetWithPrefix();
        var debug = Env.GetBool("XCLI_DEBUG");
        var entry = new
        {
            timestampUtc = DateTime.UtcNow.ToString("o"),
            pid = Process.GetCurrentProcess().Id,
            os = OperatingSystem.IsWindows()
                ? "Windows"
                : OperatingSystem.IsLinux()
                    ? "Linux"
                    : OperatingSystem.IsMacOS()
                        ? "macOS"
                        : "Unknown",
            subcommand,
            args,
            env,
            result = result.Success ? "success" : "failure",
            exitCode = result.ExitCode,
            message = result.Success ? string.Empty : (string.IsNullOrWhiteSpace(message) ? "unspecified failure" : message),
            durationMs
        };
        var json = JsonSerializer.Serialize(entry);
        var debugLines = debug ? new List<string>() : null;
        string? failureLine = null;
        var path = Env.Get("XCLI_LOG_PATH");
        if (!string.IsNullOrWhiteSpace(path))
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                var bytes = Encoding.UTF8.GetBytes(json + "\n");
                var timeoutMs = Env.GetInt("XCLI_LOG_TIMEOUT_MS", 10000);
                if (timeoutMs < 0)
                    debugLines?.Add($"[x-cli] negative XCLI_LOG_TIMEOUT_MS: {timeoutMs}, clamping to 0");
                timeoutMs = Math.Max(0, timeoutMs);
                var (wroteFile, timedOut) = TryWriteFile(path, bytes, timeoutMs, debugLines);
                if (!wroteFile)
                    failureLine = timedOut
                        ? $"[x-cli] log write timeout after {timeoutMs}ms: {path}"
                        : $"[x-cli] failed to write log to {path}";
            }
            catch (Exception ex)
            {
                debugLines?.Add(ex.ToString());
            }
        }
        if (debugLines != null)
        {
            foreach (var line in debugLines)
            {
                try { Console.Error.WriteLine(line); } catch { }
            }
        }
        if (failureLine != null)
        {
            try { Console.Error.WriteLine(failureLine); } catch { }
        }
        try
        {
            Console.Error.WriteLine(json);
        }
        catch (Exception ex)
        {
            if (debug)
            {
                try { Console.Error.WriteLine(ex.ToString()); } catch { }
            }
        }
    }

    private (bool wroteFile, bool timedOut) TryWriteFile(string path, byte[] bytes, int timeoutMs, List<string>? debugLines)
    {
        var attempts = 0;
        var writeSpin = new SpinWait();
        var watch = Stopwatch.StartNew();
        var timedOut = false;
        while (attempts < _maxFileWriteAttempts)
        {
            if (watch.ElapsedMilliseconds >= timeoutMs)
            {
                timedOut = true;
                debugLines?.Add($"[x-cli] log write loop timed out after {watch.ElapsedMilliseconds}ms");
                break;
            }
            try
            {
                using var fs = new FileStream(path, FileMode.OpenOrCreate, FileAccess.Write, FileShare.ReadWrite);
                var locked = false;
                if (OperatingSystem.IsWindows() || OperatingSystem.IsLinux())
                {
                    var lockAttempts = 0;
                    var lockSpin = new SpinWait();
                    while (!locked)
                    {
                        // Honor the overall timeout while attempting to acquire the file lock
                        if (watch.ElapsedMilliseconds >= timeoutMs)
                        {
                            timedOut = true;
                            debugLines?.Add($"[x-cli] lock loop timed out after {watch.ElapsedMilliseconds}ms");
                            break;
                        }
                        try
                        {
                            fs.Lock(0, long.MaxValue);
                            locked = true;
                        }
                        catch (Exception ex)
                        {
                            debugLines?.Add(ex.ToString());
                            lockAttempts++;
                            if (lockAttempts >= _maxFileWriteAttempts)
                            {
                                debugLines?.Add($"[x-cli] lock retry limit hit for log file: {path}");
                                break;
                            }
                            if (lockAttempts % 100 == 0)
                                debugLines?.Add($"[x-cli] retrying lock for log file: {path}");
                            AdaptiveDelay(ref lockSpin, lockAttempts);
                        }
                    }

                    if (!locked)
                    {
                        if (timedOut)
                        {
                            // Respect timeout immediately
                            return (false, true);
                        }
                        // Lock retry limit hit; fall through to outer attempt handling
                        throw new IOException($"failed to acquire lock for log file: {path}");
                    }
                }

                fs.Seek(0, SeekOrigin.End);
                fs.Write(bytes);
                fs.Flush(true);
                if (locked && (OperatingSystem.IsWindows() || OperatingSystem.IsLinux()))
                {
                    try { fs.Unlock(0, long.MaxValue); } catch { }
                }
                return (true, false);
            }
            catch (Exception ex)
            {
                debugLines?.Add(ex.ToString());
                attempts++;
                AdaptiveDelay(ref writeSpin, attempts);
            }
        }
        return (false, timedOut);
    }

    private static void AdaptiveDelay(ref SpinWait spinner, int attempt)
    {
        spinner.SpinOnce();
        var sleep = Math.Min(attempt, 50);
        if (sleep > 0)
            Thread.Sleep(sleep);
    }
}
