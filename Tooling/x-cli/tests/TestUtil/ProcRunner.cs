using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;

namespace TestUtil;

public static class ProcRunner
{
    public sealed record Result(
        int ExitCode,
        string StdOut,
        string StdErr,
        IReadOnlyDictionary<string, string> Environment);

    public static Result Run(
        string fileName,
        string args,
        IDictionary<string, string>? env = null,
        string? workingDir = null,
        TimeSpan? timeout = null)
    {
        var psi = new ProcessStartInfo(fileName, args)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            WorkingDirectory = workingDir ?? Environment.CurrentDirectory,
        };

        if (env != null)
        {
            foreach (var kv in env)
                psi.Environment[kv.Key] = kv.Value;
        }

        var snapshot = psi.Environment
            .Where(kv => kv.Value is not null)
            .ToDictionary(kv => kv.Key, kv => kv.Value!);

        using var proc = new Process { StartInfo = psi };
        var stdout = new StringBuilder();
        var stderr = new StringBuilder();

        proc.OutputDataReceived += (_, e) => { if (e.Data is not null) stdout.AppendLine(e.Data); };
        proc.ErrorDataReceived  += (_, e) => { if (e.Data is not null) stderr.AppendLine(e.Data);  };

        proc.Start();
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();

        var waitMs = (int)(timeout ?? TimeSpan.FromSeconds(30)).TotalMilliseconds;

        try
        {
            if (!proc.WaitForExit(waitMs))
            {
                proc.Kill(entireProcessTree: true);

                var killedMs = (int)TimeSpan.FromSeconds(5).TotalMilliseconds;
                if (!proc.WaitForExit(killedMs))
                {
                    throw new TimeoutException(
                        $"Process failed to exit within {killedMs}ms after kill");
                }

                proc.WaitForExit();
            }
            else
            {
                proc.WaitForExit();
            }
        }
        finally
        {
            try
            {
                proc.CancelOutputRead();
                proc.CancelErrorRead();
            }
            catch { /* ignore */ }
        }

        return new Result(proc.ExitCode, stdout.ToString(), stderr.ToString(), snapshot);
    }
}
