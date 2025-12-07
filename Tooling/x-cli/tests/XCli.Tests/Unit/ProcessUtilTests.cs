using System;
using System.Diagnostics;
using XCli.Util;
using Xunit;

namespace XCli.Tests.Unit;

public class ProcessUtilTests
{
    private static bool IsWindows => Environment.OSVersion.Platform == PlatformID.Win32NT;

    [Fact(DisplayName = "ProcessUtil starts a simple process")]
    public void Start_LaunchesProcess()
    {
        if (!IsWindows) return; // shell command is Windows-specific
        var comSpec = Environment.GetEnvironmentVariable("ComSpec");
        var exe = string.IsNullOrWhiteSpace(comSpec) ? "cmd.exe" : comSpec!;
        var psi = new ProcessStartInfo(exe, "/c exit 0")
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = ProcessUtil.Start(psi);

        Assert.NotNull(process);
        Assert.True(process!.WaitForExit(3000), "Process did not exit within timeout");
        Assert.Equal(0, process.ExitCode);
    }

    [Fact(DisplayName = "ProcessUtil returns null for invalid exe path")]
    public void Start_InvalidPath_ReturnsNull()
    {
        var psi = new ProcessStartInfo(Guid.NewGuid().ToString("N") + ".exe")
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = ProcessUtil.Start(psi);

        Assert.Null(process);
    }

    [Fact(DisplayName = "ProcessUtil honors stdout redirection and exit code")]
    public void Start_CollectsStdoutAndExitCode()
    {
        if (!IsWindows) return; // shell command is Windows-specific
        var comSpec = Environment.GetEnvironmentVariable("ComSpec");
        var exe = string.IsNullOrWhiteSpace(comSpec) ? "cmd.exe" : comSpec!;
        var psi = new ProcessStartInfo(exe, "/c echo hi & exit 7")
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = ProcessUtil.Start(psi);

        Assert.NotNull(process);
        Assert.True(process!.WaitForExit(3000), "Process did not exit within timeout");
        Assert.Equal(7, process.ExitCode);
        var output = process.StandardOutput.ReadToEnd();
        Assert.Contains("hi", output, StringComparison.OrdinalIgnoreCase);
    }

    [Fact(DisplayName = "ProcessUtil respects short wait timeouts")]
    public void Start_WaitForExit_TimesOutForLongProcess()
    {
        if (!IsWindows) return; // shell command is Windows-specific
        const string args = "-NoProfile -Command \"Start-Sleep -Seconds 3\"";
        var candidates = new[]
        {
            Environment.GetEnvironmentVariable("PWSH_EXE"),
            "pwsh",
            "powershell"
        };

        Process? process = null;
        foreach (var candidate in candidates)
        {
            if (string.IsNullOrWhiteSpace(candidate)) continue;

            var psi = new ProcessStartInfo(candidate, args)
            {
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            process = ProcessUtil.Start(psi);
            if (process != null) break;
        }

        Assert.NotNull(process);
        // Should not exit within 200ms.
        Assert.False(process!.WaitForExit(200));

        // Clean up to avoid dangling process.
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                process.WaitForExit(2000);
            }
        }
        catch
        {
            // best-effort cleanup
        }
    }

    [Fact(DisplayName = "ProcessUtil Kill terminates child tree")]
    public void Start_Kill_EndsProcessTree()
    {
        if (!IsWindows) return; // shell command is Windows-specific
        var comSpec = Environment.GetEnvironmentVariable("ComSpec");
        var exe = string.IsNullOrWhiteSpace(comSpec) ? "cmd.exe" : comSpec!;
        // Spawn a child process (powershell sleep) so Kill(entireProcessTree:true) is exercised.
        var psi = new ProcessStartInfo(exe, "/c start /b pwsh -NoProfile -Command \"Start-Sleep -Seconds 5\"")
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = ProcessUtil.Start(psi);

        Assert.NotNull(process);
        Assert.False(process!.HasExited);

        process.Kill(entireProcessTree: true);
        Assert.True(process.WaitForExit(2000), "Process did not terminate after Kill(entireProcessTree)");
        Assert.NotEqual(0, process.ExitCode);
    }
}
