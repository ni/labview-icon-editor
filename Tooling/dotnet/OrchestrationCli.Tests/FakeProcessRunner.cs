using System;
using System.Collections.Generic;
using System.Text;

namespace OrchestrationCli.Tests;

internal sealed record FakeProcessResult(int ExitCode, string StdOut, string StdErr, long DurationMs);

/// <summary>
/// Provides a deterministic runner for tests by allowing a single-command map to be injected.
/// </summary>
internal sealed class FakeProcessRunner
{
    private readonly Dictionary<string, FakeProcessResult> _map;

    public FakeProcessRunner(Dictionary<string, FakeProcessResult> map)
    {
        _map = map;
    }

    public FakeProcessResult Run(string fileName, string workingDirectory, IEnumerable<string> args, int timeoutSec)
    {
        var key = BuildKey(fileName, workingDirectory, args, timeoutSec);
        if (_map.TryGetValue(key, out var result))
        {
            return result;
        }

        return new FakeProcessResult(
            1,
            string.Empty,
            $"No fake result registered for {key}",
            0);
    }

    private static string BuildKey(string fileName, string workingDirectory, IEnumerable<string> args, int timeoutSec)
    {
        var sb = new StringBuilder();
        sb.Append(fileName);
        sb.Append("::");
        sb.Append(workingDirectory);
        sb.Append("::");
        sb.Append(string.Join(" ", args));
        sb.Append("::");
        sb.Append(timeoutSec);
        return sb.ToString();
    }
}
