namespace XCli.Labview.Providers;

public interface ILabviewProvider
{
    LabviewRunResult RunPwshScript(PwshScriptRequest request);
    LabviewRunResult RunGcli(GcliRequest request);
}

public sealed record PwshScriptRequest(
    string ScriptPath,
    string[] Arguments,
    string WorkingDirectory,
    int TimeoutSeconds,
    bool UseCommand = false
);

public sealed record GcliRequest(
    string[] Arguments,
    string WorkingDirectory,
    int TimeoutSeconds
);

public sealed record LabviewRunResult(
    bool Success,
    int ExitCode,
    string StdOut,
    string StdErr,
    long DurationMs
);

public static class LabviewProviderSelector
{
    public static ILabviewProvider Create()
    {
        var kind = Environment.GetEnvironmentVariable("XCLI_PROVIDER");
        if (!string.IsNullOrWhiteSpace(kind) && kind.Equals("sim", StringComparison.OrdinalIgnoreCase))
        {
            return new SimulatedLabviewProvider();
        }
        return new DefaultLabviewProvider();
    }
}
