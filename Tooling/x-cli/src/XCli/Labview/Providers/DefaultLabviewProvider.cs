using System;
using System.Diagnostics;
using System.Text;

namespace XCli.Labview.Providers;

public sealed class DefaultLabviewProvider : ILabviewProvider
{
    private static LabviewRunResult RunProcess(string fileName, Action<ProcessStartInfo> configure, int timeoutSeconds)
    {
        var psi = new ProcessStartInfo(fileName)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        configure(psi);

        var sw = Stopwatch.StartNew();
        using var proc = Process.Start(psi);
        if (proc == null)
            return new LabviewRunResult(false, 1, string.Empty, "failed to start process", 0);

        var timedOut = false;
        if (timeoutSeconds > 0)
        {
            timedOut = !proc.WaitForExit(Math.Max(1, timeoutSeconds) * 1000);
            if (timedOut)
            {
                try { proc.Kill(true); } catch { }
            }
        }
        else
        {
            proc.WaitForExit();
        }

        var stdout = proc.StandardOutput.ReadToEnd();
        var stderr = proc.StandardError.ReadToEnd();
        sw.Stop();
        var exit = timedOut ? 124 : proc.ExitCode;
        return new LabviewRunResult(exit == 0 && !timedOut, exit, stdout, stderr, sw.ElapsedMilliseconds);
    }

    public LabviewRunResult RunPwshScript(PwshScriptRequest request)
    {
        var pwshPath = Environment.GetEnvironmentVariable("XCLI_PWSH") ?? "pwsh";
        return RunProcess(pwshPath, psi =>
        {
            psi.WorkingDirectory = request.WorkingDirectory;
            psi.ArgumentList.Add("-NoLogo");
            psi.ArgumentList.Add("-NoProfile");
            if (request.UseCommand)
            {
                psi.ArgumentList.Add("-Command");
                psi.ArgumentList.Add(BuildCommand(request.ScriptPath, request.Arguments));
            }
            else
            {
                psi.ArgumentList.Add("-File");
                psi.ArgumentList.Add(request.ScriptPath);
                foreach (var arg in request.Arguments)
                {
                    psi.ArgumentList.Add(arg);
                }
            }
        }, request.TimeoutSeconds);
    }

    private static string BuildCommand(string command, string[] arguments)
    {
        if (arguments.Length == 0) return command;
        var sb = new StringBuilder(command);
        foreach (var arg in arguments)
        {
            sb.Append(' ').Append(EscapePwsh(arg));
        }
        return sb.ToString();
    }

    private static string EscapePwsh(string value)
    {
        if (string.IsNullOrEmpty(value)) return "''";
        var escaped = value.Replace("'", "''");
        return $"'{escaped}'";
    }

    public LabviewRunResult RunGcli(GcliRequest request)
    {
        var gcliPath = Environment.GetEnvironmentVariable("GCLI_PATH") ?? "g-cli";
        return RunProcess(gcliPath, psi =>
        {
            psi.WorkingDirectory = request.WorkingDirectory;
            foreach (var arg in request.Arguments)
            {
                psi.ArgumentList.Add(arg);
            }
        }, request.TimeoutSeconds);
    }
}
