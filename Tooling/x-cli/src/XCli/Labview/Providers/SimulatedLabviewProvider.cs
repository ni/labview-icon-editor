using System;
using System.Text;
using XCli.Util;

namespace XCli.Labview.Providers;

/// <summary>
/// Simulated provider for CI/dry-runs when XCLI_PROVIDER=sim.
/// Returns success for most commands with stubbed stdout, unless XCLI_SIM_FAIL is set.
/// </summary>
public sealed class SimulatedLabviewProvider : ILabviewProvider
{
    private readonly bool _fail;
    private readonly int _exitCode;
    private readonly int _delayMs;

    public SimulatedLabviewProvider()
    {
        _fail = Env.GetStringOrDefault("XCLI_SIM_FAIL")
            .Equals("true", StringComparison.OrdinalIgnoreCase);
        _exitCode = Env.GetInt("XCLI_SIM_EXIT", 0);
        _delayMs = Env.GetInt("XCLI_SIM_DELAY_MS", 0);
    }

    public LabviewRunResult RunPwshScript(PwshScriptRequest request)
    {
        if (_delayMs > 0) System.Threading.Thread.Sleep(_delayMs);
        var sb = new StringBuilder();
        sb.AppendLine($"[sim] pwsh {request.ScriptPath} {string.Join(' ', request.Arguments)}");
        var success = !_fail && _exitCode == 0;
        return new LabviewRunResult(success, _fail ? (_exitCode == 0 ? 1 : _exitCode) : _exitCode, sb.ToString(), string.Empty, _delayMs);
    }

    public LabviewRunResult RunGcli(GcliRequest request)
    {
        if (_delayMs > 0) System.Threading.Thread.Sleep(_delayMs);
        var sb = new StringBuilder();
        sb.AppendLine($"[sim] g-cli {string.Join(' ', request.Arguments)}");
        var success = !_fail && _exitCode == 0;
        return new LabviewRunResult(success, _fail ? (_exitCode == 0 ? 1 : _exitCode) : _exitCode, sb.ToString(), string.Empty, _delayMs);
    }
}
