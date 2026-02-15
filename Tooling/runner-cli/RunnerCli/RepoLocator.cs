using System.Diagnostics;

namespace RunnerCli;

public static class RepoLocator
{
    public static string Resolve(string? repoRootOverride, string? basePath = null)
    {
        if (!string.IsNullOrWhiteSpace(repoRootOverride))
        {
            return Path.GetFullPath(repoRootOverride);
        }

        var origin = string.IsNullOrWhiteSpace(basePath) ? Environment.CurrentDirectory : basePath!;
        var gitRoot = TryGitRoot(origin);
        if (!string.IsNullOrWhiteSpace(gitRoot))
        {
            return Path.GetFullPath(gitRoot!);
        }

        return Path.GetFullPath(origin);
    }

    private static string? TryGitRoot(string basePath)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "git",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };
            psi.ArgumentList.Add("-C");
            psi.ArgumentList.Add(basePath);
            psi.ArgumentList.Add("rev-parse");
            psi.ArgumentList.Add("--show-toplevel");

            using var process = Process.Start(psi);
            if (process is null)
                return null;

            var output = process.StandardOutput.ReadToEnd();
            process.WaitForExit(3000);
            if (process.ExitCode != 0)
                return null;

            var trimmed = output.Trim();
            return string.IsNullOrWhiteSpace(trimmed) ? null : trimmed;
        }
        catch
        {
            return null;
        }
    }
}
