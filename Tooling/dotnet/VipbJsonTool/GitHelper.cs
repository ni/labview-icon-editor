using System;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace VipbJsonTool
{
    public static class GitHelper
    {
        private static int Run(string cmd, string args, bool throwOnError = true)
        {
            var psi = new ProcessStartInfo(cmd, args)
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false
            };
            var p = Process.Start(psi);
            p.WaitForExit();
            if (p.ExitCode != 0 && throwOnError)
            {
                string stderr = p.StandardError.ReadToEnd();
                throw new Exception($"{cmd} {args}\n{stderr}");
            }
            return p.ExitCode;
        }

        public static void CommitAndPush(string branch, string[] files, bool autoPr)
        {
            var token = Environment.GetEnvironmentVariable("GITHUB_TOKEN");
            var repo = Environment.GetEnvironmentVariable("GITHUB_REPOSITORY");
            if (token == null || repo == null)
            {
                Console.Error.WriteLine("GITHUB_TOKEN or GITHUB_REPOSITORY env not set - skipping push.");
                return;
            }

            Run("git", "config user.name \"GitHub Actions\"");
            Run("git", "config user.email \"github-actions[bot]@users.noreply.github.com\"");
            Run("git", $"checkout -B {branch}");
            foreach (var f in files.Where(File.Exists))
            {
                Run("git", $"add {f}");
            }
            Run("git", "commit -m \"Automated update via JSON-VIPB Action v1.3.0\" --allow-empty");
            Run("git", $"remote set-url origin https://x-access-token:{token}@github.com/{repo}.git");
            Run("git", $"push origin {branch} --force");

            if (autoPr)
            {
                var prJson = $"{{\"title\":\"Automated VIPB update\",\"head\":\"{branch}\",\"base\":\"main\"}}";
                Run("curl", $"-X POST -H \"Authorization: token {token}\" -H \"Content-Type: application/json\" -d \"{prJson}\" https://api.github.com/repos/{repo}/pulls");
            }
        }
    }
}
