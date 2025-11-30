using System;
using System.IO;
using System.Security.Cryptography;
using System.Text.Json;
using TestUtil;
using Xunit;

public class ValidateManifestTests
{
    private static bool IsWindows() => OperatingSystem.IsWindows();
    private static void RobustDelete(DirectoryInfo dir)
    {
        for (int i = 0; i < 6; i++)
        {
            try
            {
                dir.Refresh();
                dir.Delete(recursive: true);
                return;
            }
            catch (IOException)
            {
                GC.Collect();
                GC.WaitForPendingFinalizers();
                System.Threading.Thread.Sleep(120);
            }
            catch (UnauthorizedAccessException)
            {
                GC.Collect();
                GC.WaitForPendingFinalizers();
                System.Threading.Thread.Sleep(120);
            }
        }
        // Final attempt (surface if it still fails)
        dir.Delete(recursive: true);
    }
    private static string FindRepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (int i = 0; i < 10 && dir != null; i++, dir = dir.Parent!)
        {
            if (File.Exists(Path.Combine(dir.FullName, "XCli.sln")))
                return dir.FullName;
        }
        throw new DirectoryNotFoundException("Could not locate repository root.");
    }

    private static string Sha256(string path)
    {
        using var sha = SHA256.Create();
        return Convert.ToHexString(sha.ComputeHash(File.ReadAllBytes(path))).ToLowerInvariant();
    }

    [Fact]
    public void Valid_manifest_passes()
    {
        if (IsWindows()) return; // bash not guaranteed on Windows; validated in Linux CI
        var root = FindRepoRoot();
        var tmp = Directory.CreateTempSubdirectory();
        try
        {
            Directory.CreateDirectory(Path.Combine(tmp.FullName, "dist"));
            Directory.CreateDirectory(Path.Combine(tmp.FullName, "telemetry"));

            var win = Path.Combine(tmp.FullName, "dist", "x-cli-win-x64");
            var lin = Path.Combine(tmp.FullName, "dist", "x-cli-linux-x64");
            var sum = Path.Combine(tmp.FullName, "telemetry", "summary.json");
            File.WriteAllText(win, "win");
            File.WriteAllText(lin, "lin");
            File.WriteAllText(sum, "{}");

            var manifestPath = Path.Combine(tmp.FullName, "telemetry", "manifest.json");
            var manifest = new
            {
                schema = "pipeline.manifest/v1",
                artifacts = new
                {
                    win_x64 = new { path = "dist/x-cli-win-x64", sha256 = Sha256(win) },
                    linux_x64 = new { path = "dist/x-cli-linux-x64", sha256 = Sha256(lin) }
                },
                telemetry = new
                {
                    summary = new { path = "telemetry/summary.json", sha256 = Sha256(sum) }
                }
            };
            File.WriteAllText(manifestPath, JsonSerializer.Serialize(manifest));

            var script = Path.Combine(root, "ci", "stage2", "validate-manifest.sh");
            var result = ProcRunner.Run("bash", $"{script} telemetry/manifest.json", workingDir: tmp.FullName);
            Assert.Equal(0, result.ExitCode);
        }
        finally
        {
            RobustDelete(tmp);
        }
    }

    [Fact]
    public void Checksum_mismatch_fails()
    {
        if (IsWindows()) return;
        var root = FindRepoRoot();
        var tmp = Directory.CreateTempSubdirectory();
        try
        {
            Directory.CreateDirectory(Path.Combine(tmp.FullName, "dist"));
            Directory.CreateDirectory(Path.Combine(tmp.FullName, "telemetry"));

            var win = Path.Combine(tmp.FullName, "dist", "x-cli-win-x64");
            var lin = Path.Combine(tmp.FullName, "dist", "x-cli-linux-x64");
            var sum = Path.Combine(tmp.FullName, "telemetry", "summary.json");
            File.WriteAllText(win, "win");
            File.WriteAllText(lin, "lin");
            File.WriteAllText(sum, "{}");

            var manifestPath = Path.Combine(tmp.FullName, "telemetry", "manifest.json");
            var manifest = new
            {
                schema = "pipeline.manifest/v1",
                artifacts = new
                {
                    win_x64 = new { path = "dist/x-cli-win-x64", sha256 = "deadbeef" },
                    linux_x64 = new { path = "dist/x-cli-linux-x64", sha256 = Sha256(lin) }
                },
                telemetry = new
                {
                    summary = new { path = "telemetry/summary.json", sha256 = Sha256(sum) }
                }
            };
            File.WriteAllText(manifestPath, JsonSerializer.Serialize(manifest));

            var script = Path.Combine(root, "ci", "stage2", "validate-manifest.sh");
            var result = ProcRunner.Run("bash", $"{script} telemetry/manifest.json", workingDir: tmp.FullName);
            Assert.NotEqual(0, result.ExitCode);
        }
        finally
        {
            RobustDelete(tmp);
        }
    }

    [Fact]
    public void Missing_required_entry_fails()
    {
        if (IsWindows()) return;
        var root = FindRepoRoot();
        var tmp = Directory.CreateTempSubdirectory();
        try
        {
            Directory.CreateDirectory(Path.Combine(tmp.FullName, "dist"));
            Directory.CreateDirectory(Path.Combine(tmp.FullName, "telemetry"));

            var win = Path.Combine(tmp.FullName, "dist", "x-cli-win-x64");
            File.WriteAllText(win, "win");

            var manifestPath = Path.Combine(tmp.FullName, "telemetry", "manifest.json");
            var manifest = new
            {
                schema = "pipeline.manifest/v1",
                artifacts = new
                {
                    win_x64 = new { path = "dist/x-cli-win-x64", sha256 = Sha256(win) }
                },
                telemetry = new { }
            };
            File.WriteAllText(manifestPath, JsonSerializer.Serialize(manifest));

            var script = Path.Combine(root, "ci", "stage2", "validate-manifest.sh");
            var result = ProcRunner.Run("bash", $"{script} telemetry/manifest.json", workingDir: tmp.FullName);
            Assert.NotEqual(0, result.ExitCode);
        }
        finally
        {
            RobustDelete(tmp);
        }
    }

    [Fact]
    public void Missing_summary_file_fails()
    {
        if (IsWindows()) return;
        var root = FindRepoRoot();
        var tmp = Directory.CreateTempSubdirectory();
        try
        {
            Directory.CreateDirectory(Path.Combine(tmp.FullName, "dist"));
            Directory.CreateDirectory(Path.Combine(tmp.FullName, "telemetry"));

            var win = Path.Combine(tmp.FullName, "dist", "x-cli-win-x64");
            var lin = Path.Combine(tmp.FullName, "dist", "x-cli-linux-x64");
            File.WriteAllText(win, "win");
            File.WriteAllText(lin, "lin");

            var manifestPath = Path.Combine(tmp.FullName, "telemetry", "manifest.json");
            var manifest = new
            {
                schema = "pipeline.manifest/v1",
                artifacts = new
                {
                    win_x64 = new { path = "dist/x-cli-win-x64", sha256 = Sha256(win) },
                    linux_x64 = new { path = "dist/x-cli-linux-x64", sha256 = Sha256(lin) }
                },
                telemetry = new
                {
                    summary = new { path = "telemetry/summary.json", sha256 = "deadbeef" }
                }
            };
            File.WriteAllText(manifestPath, JsonSerializer.Serialize(manifest));

            var script = Path.Combine(root, "ci", "stage2", "validate-manifest.sh");
            var result = ProcRunner.Run("bash", $"{script} telemetry/manifest.json", workingDir: tmp.FullName);
            Assert.NotEqual(0, result.ExitCode);
        }
        finally
        {
            RobustDelete(tmp);
        }
}
}
