using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Collections.Generic;
using System.Linq;

namespace XCli.Tests.TestInfra;

public static class ProcessRunner
{
    public sealed record CliResult(
        int ExitCode,
        string StdOut,
        string StdErr,
        JsonDocument? LogJson,
        IReadOnlyDictionary<string, string> Environment);

    public static async Task<CliResult> RunAsync(
        string subcommand,
        IEnumerable<string> payloadArgs,
        IDictionary<string, string>? env = null,
        TimeSpan? timeout = null,
        CancellationToken ct = default)
    {
        var projectPath = FindProjectPath();
        var psi = new ProcessStartInfo
        {
            FileName = "dotnet",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            WorkingDirectory = Path.GetDirectoryName(projectPath)!,
            StandardOutputEncoding = new UTF8Encoding(false),
            StandardErrorEncoding = new UTF8Encoding(false)
        };

        // dotnet run -c Release --project <csproj> -- <subcommand> -- <payload...>
        psi.ArgumentList.Add("run");
        psi.ArgumentList.Add("--no-build");
        psi.ArgumentList.Add("-c"); psi.ArgumentList.Add("Release");
        psi.ArgumentList.Add("--project");
        psi.ArgumentList.Add(projectPath);
        psi.ArgumentList.Add("--");
        psi.ArgumentList.Add(subcommand);
        psi.ArgumentList.Add("--");
        foreach (var a in payloadArgs)
            psi.ArgumentList.Add(a);

        if (env is { })
        {
            foreach (var kv in env)
                psi.Environment[kv.Key] = kv.Value;
        }

        var envSnapshot = psi.Environment
            .Where(kv => kv.Value is not null)
            .ToDictionary(kv => kv.Key, kv => kv.Value!);

        var proc = new Process { StartInfo = psi };
        var stdout = new StringBuilder();
        var stderr = new StringBuilder();

        proc.OutputDataReceived += (_, e) => { if (e.Data is not null) stdout.AppendLine(e.Data); };
        proc.ErrorDataReceived  += (_, e) => { if (e.Data is not null) stderr.AppendLine(e.Data);  };

        proc.Start();
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();

        var effectiveTimeout = timeout ?? TimeSpan.FromSeconds(30);
        CancellationTokenSource? cts = null;
        var waitToken = ct;
        if (!ct.CanBeCanceled)
        {
            cts = new CancellationTokenSource(effectiveTimeout);
            waitToken = cts.Token;
        }

        int exitCode = -1;
        try
        {
            await proc.WaitForExitAsync(waitToken);
            exitCode = proc.ExitCode;
        }
        catch (OperationCanceledException) when (cts is not null)
        {
            try
            {
                if (!proc.HasExited)
                {
                    proc.Kill(entireProcessTree: true);
                    try
                    {
                        await proc
                            .WaitForExitAsync()
                            .WaitAsync(TimeSpan.FromSeconds(5));
                        exitCode = proc.ExitCode;
                    }
                    catch (TimeoutException)
                    {
                        Console.Error.WriteLine("Process failed to exit after kill within 5 seconds.");
                    }
                }
            }
            catch { /* ignore */ }
            throw new TimeoutException($"Process timed out after {effectiveTimeout}.");
        }
        finally
        {
            try
            {
                proc.CancelOutputRead();
                proc.CancelErrorRead();
            }
            catch { /* ignore */ }

            cts?.Dispose();
            proc.Dispose();
        }

        JsonDocument? log = null;
        // Find the first JSON-looking line on stderr and try to parse it
        foreach (var line in stderr.ToString().Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries))
        {
            var trimmed = line.TrimStart();
            if (!trimmed.StartsWith("{")) continue;
            try
            {
                log = JsonDocument.Parse(trimmed);
                break;
            }
            catch { /* ignore parse failures */ }
        }

        return new CliResult(
            exitCode,
            stdout.ToString().TrimEnd(),
            stderr.ToString().TrimEnd(),
            log,
            envSnapshot);
    }

    private static string FindProjectPath()
    {
        // ascend from test bin folder until we find src/XCli/XCli.csproj
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (int i = 0; i < 10 && dir is not null; i++, dir = dir.Parent!)
        {
            var candidate = Path.Combine(dir.FullName, "src", "XCli", "XCli.csproj");
            if (File.Exists(candidate))
                return candidate;
        }
        throw new FileNotFoundException("Could not locate src/XCli/XCli.csproj from test context.");
    }
}

