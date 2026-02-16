using System.Diagnostics;

namespace RunnerCli.Tests;

public class WorktreeProvisioningTests
{
    [Fact]
    public void NewCiWorktree_builds_runner_cli_publish()
    {
        if (!OperatingSystem.IsWindows())
        {
            return;
        }

        if (!HasCommand("pwsh") || !HasCommand("git"))
        {
            return;
        }

        var repoRoot = FindRepoRoot();
        var tempRoot = Path.Combine(Path.GetTempPath(), $"lvie-worktrees-{Guid.NewGuid():N}");
        Directory.CreateDirectory(tempRoot);

        string? worktreePath = null;
        try
        {
            var scriptPath = Path.Combine(repoRoot, "Tooling", "New-CIWorktree.ps1");
            var args = $"-NoProfile -File \"{scriptPath}\" -Ref HEAD -WorktreeRoot \"{tempRoot}\"";
            var (exitCode, stdout, _) = RunProcess("pwsh", args, repoRoot);
            Assert.Equal(0, exitCode);

            worktreePath = stdout
                .Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries)
                .Select(line => line.Trim())
                .LastOrDefault(line => Directory.Exists(line));

            Assert.False(string.IsNullOrWhiteSpace(worktreePath), "Worktree path not found in output.");
            Assert.True(Directory.Exists(worktreePath), "Worktree path does not exist.");

            var (rid, exeName) = GetRuntimeInfo();
            var cliPath = Path.Combine(worktreePath, "Tooling", "runner-cli", "publish", rid, exeName);
            Assert.True(File.Exists(cliPath), $"runner-cli publish output not found at {cliPath}");
        }
        finally
        {
            if (!string.IsNullOrWhiteSpace(worktreePath))
            {
                RunProcess("git", $"-C \"{repoRoot}\" worktree remove --force \"{worktreePath}\"", repoRoot);
            }
            if (Directory.Exists(tempRoot))
            {
                try
                {
                    Directory.Delete(tempRoot, true);
                }
                catch
                {
                    // ignore cleanup failures
                }
            }
        }
    }

    private static bool HasCommand(string name)
    {
        try
        {
            var (exitCode, _, _) = RunProcess(name, "--version", Environment.CurrentDirectory);
            return exitCode == 0;
        }
        catch
        {
            return false;
        }
    }

    private static (string Rid, string ExeName) GetRuntimeInfo()
    {
        return ("win-x64", "runner-cli.exe");
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
}
