using System.Threading;
using System.Threading.Tasks;

namespace XCli.Simulation;

public class Simulator
{
    public async Task<SimulationResult> Execute(string subcommand, SimulationPlanResult planResult, CancellationToken token = default)
    {
        var plan = planResult.Plan;
        if (plan.DelayMs > 0)
            await Task.Delay(plan.DelayMs, token);
        if (planResult.Error != null)
        {
            // configuration loading already produced a user-facing diagnostic
            // (e.g. missing or malformed config file). Skip emitting the
            // simulated failure message to avoid duplicate output.
            return new SimulationResult(false, plan.ExitCode);
        }
        if (plan.Fail)
        {
            var failureMessage = string.IsNullOrWhiteSpace(plan.Message)
                ? "unspecified failure"
                : plan.Message;
            var msg = $"[x-cli] {subcommand}: failure (simulated) - {failureMessage}";
            Console.Error.WriteLine(msg);
            return new SimulationResult(false, plan.ExitCode);
        }
        else
        {
            Console.WriteLine($"[x-cli] {subcommand}: success (simulated)");
            return new SimulationResult(true, 0);
        }
    }
}

public record SimulationResult(bool Success, int ExitCode);
