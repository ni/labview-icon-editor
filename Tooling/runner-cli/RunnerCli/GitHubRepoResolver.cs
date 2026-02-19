using System.Diagnostics;

namespace RunnerCli;

public static class GitHubRepoResolver
{
    public static string Resolve(string? repoInput, string? repoRoot)
    {
        if (!string.IsNullOrWhiteSpace(repoInput))
        {
            return repoInput.Trim();
        }

        var envRepo = Environment.GetEnvironmentVariable("GITHUB_REPOSITORY");
        if (!string.IsNullOrWhiteSpace(envRepo))
        {
            return envRepo.Trim();
        }

        var fromGit = TryGetRepoFromGit(repoRoot ?? Environment.CurrentDirectory);
        if (!string.IsNullOrWhiteSpace(fromGit))
        {
            return fromGit!;
        }

        throw new InvalidOperationException("GitHub repository not provided. Set --repo or GITHUB_REPOSITORY.");
    }

    private static string? TryGetRepoFromGit(string basePath)
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
            psi.ArgumentList.Add("config");
            psi.ArgumentList.Add("--get");
            psi.ArgumentList.Add("remote.origin.url");

            using var process = Process.Start(psi);
            if (process is null)
                return null;

            var output = process.StandardOutput.ReadToEnd();
            process.WaitForExit(3000);
            if (process.ExitCode != 0)
                return null;

            var url = output.Trim();
            if (string.IsNullOrWhiteSpace(url))
                return null;

            var match = System.Text.RegularExpressions.Regex.Match(url, @"github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?$");
            if (match.Success)
            {
                return $"{match.Groups["owner"].Value}/{match.Groups["repo"].Value}";
            }
        }
        catch
        {
            return null;
        }

        return null;
    }
}
