using System.Diagnostics;
using System.Text;

internal static class Program
{
    private record Options(string RepoPath, string SupportedBitness, string PwshPath, bool ForcePlain, bool Verbose);

    private static int Main(string[] args)
    {
        var parsed = SafeParseArgs(args);
        if (parsed.HelpRequested)
        {
            PrintUsage();
            return 0;
        }
        if (parsed.Error != null)
        {
            Console.Error.WriteLine(parsed.Error);
            PrintUsage();
            return 1;
        }

        var opts = parsed.Value!;
        var repo = opts.RepoPath;
        var script = Path.Combine(repo, "scripts", "test", "Test.ps1");
        if (!File.Exists(script))
        {
            Console.Error.WriteLine($"Test script not found at {script}");
            return 1;
        }

        var timer = Stopwatch.StartNew();
        Console.WriteLine($"[tests-cli] Running Test.ps1 for repo: {repo} (bitness: {opts.SupportedBitness})");

        var argList = new List<string>
        {
            "-NoProfile",
            "-File", script,
            "-RepositoryPath", repo,
            "-SupportedBitness", opts.SupportedBitness
        };
        if (opts.ForcePlain)
        {
            argList.Add("-ForcePlainOutput");
        }
        if (opts.Verbose)
        {
            argList.Add("-Verbose");
        }

        var result = RunCommand(opts.PwshPath, repo, argList, label: "tests-cli", echoOutput: true, timer: timer);
        Console.WriteLine($"[tests-cli] Exit code: {result.ExitCode}");
        return result.ExitCode;
    }

    private static (Options? Value, string? Error, bool HelpRequested) SafeParseArgs(string[] args)
    {
        var repo = Directory.GetCurrentDirectory();
        var bitness = "both";
        var pwsh = "pwsh";
        var forcePlain = false;
        var verbose = false;

        try
        {
            for (int i = 0; i < args.Length; i++)
            {
                var arg = args[i];
                switch (arg)
                {
                    case "--repo":
                        repo = RequireNext(args, ref i, "--repo");
                        break;
                    case "--bitness":
                        bitness = RequireNext(args, ref i, "--bitness");
                        break;
                    case "--pwsh":
                        pwsh = RequireNext(args, ref i, "--pwsh");
                        break;
                    case "--force-plain":
                        forcePlain = true;
                        break;
                    case "--verbose":
                        verbose = true;
                        break;
                    case "--help":
                    case "-h":
                        return (null, null, true);
                    default:
                        return (null, $"Unknown argument: {arg}", false);
                }
            }
        }
        catch (ArgumentException ex)
        {
            return (null, ex.Message, false);
        }

        bitness = ValidateBitness(bitness);
        var repoFull = Path.GetFullPath(repo);
        if (!Directory.Exists(repoFull))
        {
            return (null, $"Repository path not found: {repoFull}", false);
        }

        return (new Options(
            RepoPath: repoFull,
            SupportedBitness: bitness,
            PwshPath: pwsh,
            ForcePlain: forcePlain,
            Verbose: verbose
        ), null, false);
    }

    private static (int ExitCode, string StdOut, string StdErr) RunCommand(
        string fileName,
        string workingDir,
        IEnumerable<string> args,
        string? label = null,
        bool echoOutput = false,
        Stopwatch? timer = null)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            WorkingDirectory = workingDir,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        foreach (var a in args) psi.ArgumentList.Add(a);

        var proc = Process.Start(psi);
        if (proc == null)
        {
            return (1, string.Empty, "Failed to start process");
        }

        var stdout = new StringBuilder();
        var stderr = new StringBuilder();
        var lastElapsed = timer?.Elapsed ?? TimeSpan.Zero;

        void HandleOut(string? data)
        {
            if (data == null) return;
            stdout.AppendLine(data);
            if (echoOutput)
            {
                var prefix = string.Empty;
                if (label != null)
                {
                    if (timer != null)
                    {
                        var elapsed = timer.Elapsed;
                        var delta = elapsed - lastElapsed;
                        prefix = $"[{label}][(T+{elapsed.TotalSeconds:F3}s Δ+{delta.TotalMilliseconds:N0}ms)] ";
                        lastElapsed = elapsed;
                    }
                    else
                    {
                        prefix = $"[{label}] ";
                    }
                }
                Console.Out.WriteLine(prefix + data);
            }
        }

        void HandleErr(string? data)
        {
            if (data == null) return;
            stderr.AppendLine(data);
            if (echoOutput)
            {
                var prefix = string.Empty;
                if (label != null)
                {
                    if (timer != null)
                    {
                        var elapsed = timer.Elapsed;
                        var delta = elapsed - lastElapsed;
                        prefix = $"[{label}][(T+{elapsed.TotalSeconds:F3}s Δ+{delta.TotalMilliseconds:N0}ms)] ";
                        lastElapsed = elapsed;
                    }
                    else
                    {
                        prefix = $"[{label}] ";
                    }
                }
                Console.Error.WriteLine(prefix + data);
            }
        }

        proc.OutputDataReceived += (_, e) => HandleOut(e.Data);
        proc.ErrorDataReceived += (_, e) => HandleErr(e.Data);
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();
        proc.WaitForExit();

        return (proc.ExitCode, stdout.ToString(), stderr.ToString());
    }

    private static string RequireNext(string[] args, ref int index, string name)
    {
        if (index + 1 >= args.Length)
        {
            throw new ArgumentException($"Missing value for {name}");
        }
        return args[++index];
    }

    private static string ValidateBitness(string value)
    {
        var candidate = value.ToLowerInvariant();
        if (candidate is "both" or "64" or "32")
        {
            return candidate;
        }
        throw new ArgumentException("Invalid --bitness. Expected both|64|32.");
    }

    private static void PrintUsage()
    {
        Console.WriteLine("TestsCli - runs scripts/test/Test.ps1");
        Console.WriteLine("Usage:");
        Console.WriteLine("  pwsh scripts/common/invoke-repo-cli.ps1 -Cli TestsCli -- [options]");
        Console.WriteLine("Options:");
        Console.WriteLine("  --repo <path>         Repository path (default: current directory)");
        Console.WriteLine("  --bitness <both|64|32>  Supported bitness for tests (default: both)");
        Console.WriteLine("  --pwsh <path>         PowerShell executable (default: pwsh)");
        Console.WriteLine("  --force-plain         Force plain output (passes -ForcePlainOutput)");
        Console.WriteLine("  --verbose             Pass -Verbose to Test.ps1");
        Console.WriteLine("  -h, --help            Show this help");
    }
}
