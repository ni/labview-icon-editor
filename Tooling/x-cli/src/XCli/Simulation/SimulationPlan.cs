// ModuleIndex: loads failure simulation configuration from environment and JSON.
using System.Text.Json;
using System.Text.Json.Serialization;
using XCli.Util;

namespace XCli.Simulation;

public class SimulationPlan
{
    public const int MaxDelayMs = 10_000;

    public bool Fail { get; init; }
    public int ExitCode { get; init; }
    public string Message { get; init; } = string.Empty;
    public int DelayMs { get; init; }
    public static SimulationPlanResult ForCommand(string subcommand)
    {
        var failOn = Env.Get("XCLI_FAIL_ON");
        bool fail;
        if (failOn != null)
        {
            if (string.IsNullOrWhiteSpace(failOn))
            {
                fail = false;
            }
            else
            {
                var parts = failOn.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                fail = parts.Any(p => p.Equals(subcommand, StringComparison.OrdinalIgnoreCase));
            }
        }
        else
        {
            fail = Env.GetBool("XCLI_FAIL");
        }

        int exitCode = Math.Clamp(Env.GetInt("XCLI_EXIT_CODE", 1), 0, 255);
        string message = Env.GetStringOrDefault("XCLI_MESSAGE");
        int delay = Env.GetInt("XCLI_DELAY_MS", 0);

        // json config
        var configPath = Env.Get("XCLI_CONFIG_PATH");
        if (!string.IsNullOrWhiteSpace(configPath))
        {
            try
            {
                var json = File.ReadAllText(configPath);
                var cfg = JsonSerializer.Deserialize<Config>(
                    json,
                    new JsonSerializerOptions
                    {
                        PropertyNameCaseInsensitive = true,
                        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
                    });
                if (cfg != null)
                {
                    if (cfg.commands != null)
                    {
                        cfg.commands = new Dictionary<string, Defaults>(cfg.commands, StringComparer.OrdinalIgnoreCase);
                    }
                    if (cfg.defaults != null)
                    {
                        if (cfg.defaults.fail.HasValue)
                        {
                            fail = cfg.defaults.fail.Value;
                        }
                        if (cfg.defaults.exitCode.HasValue)
                        {
                            exitCode = Math.Clamp(cfg.defaults.exitCode.Value, 0, 255);
                        }
                        if (cfg.defaults.message != null)
                        {
                            message = cfg.defaults.message;
                        }
                        if (cfg.defaults.delayMs.HasValue)
                        {
                            delay = cfg.defaults.delayMs.Value;
                        }
                    }
                    if (cfg.commands != null && cfg.commands.TryGetValue(subcommand, out var cmdCfg))
                    {
                        if (cmdCfg.fail.HasValue)
                        {
                            fail = cmdCfg.fail.Value;
                        }
                        if (cmdCfg.exitCode.HasValue)
                        {
                            exitCode = Math.Clamp(cmdCfg.exitCode.Value, 0, 255);
                        }
                        if (cmdCfg.message != null)
                        {
                            message = cmdCfg.message;
                        }
                        if (cmdCfg.delayMs.HasValue)
                        {
                            delay = cmdCfg.delayMs.Value;
                        }
                    }
                }
            }
            catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException)
            {
                  return ConfigMissing(configPath, delay, exitCode);
              }
              catch (UnauthorizedAccessException)
              {
                  return ConfigPermissionDenied(configPath, delay, exitCode);
              }
              catch (Exception ex)
              {
                  return ConfigParseError(ex, delay, exitCode);
              }
          }

        if (fail && string.IsNullOrWhiteSpace(message))
        {
            message = "unspecified failure";
        }

        delay = ClampDelay(delay);

        if (fail)
        {
            if (exitCode == 0)
            {
                exitCode = 1;
            }
        }
        else
        {
            exitCode = 0;
        }

        var plan = new SimulationPlan { Fail = fail, ExitCode = exitCode, Message = message, DelayMs = delay };
        return new SimulationPlanResult(plan, null);

        static SimulationPlanResult ConfigMissing(string path, int delay, int exitCode)
        {
            var msg = $"config file not found: {path}";
            Console.Error.WriteLine($"[x-cli] {msg}");
            delay = ClampDelay(delay);
            if (exitCode == 0)
            {
                exitCode = 1;
            }
            var plan = new SimulationPlan { Fail = true, ExitCode = exitCode, Message = msg, DelayMs = delay };
            return new SimulationPlanResult(plan, SimulationPlanError.ConfigNotFound);
        }

        static SimulationPlanResult ConfigPermissionDenied(string path, int delay, int exitCode)
        {
            var msg = $"config file permission denied: {path}";
            Console.Error.WriteLine($"[x-cli] {msg}");
            delay = ClampDelay(delay);
            if (exitCode == 0)
            {
                exitCode = 1;
            }
            var plan = new SimulationPlan { Fail = true, ExitCode = exitCode, Message = msg, DelayMs = delay };
            return new SimulationPlanResult(plan, SimulationPlanError.ConfigPermissionDenied);
        }

        static SimulationPlanResult ConfigParseError(Exception ex, int delay, int exitCode)
        {
            var msg = $"config parse error: {ex.Message}";
            Console.Error.WriteLine(msg);
            delay = ClampDelay(delay);
            if (exitCode == 0)
            {
                exitCode = 1;
            }
            var plan = new SimulationPlan { Fail = true, ExitCode = exitCode, Message = msg, DelayMs = delay };
            return new SimulationPlanResult(plan, SimulationPlanError.ConfigParseError);
        }

        static int ClampDelay(int value)
        {
            if (value < 0)
            {
                if (Env.GetBool("XCLI_DEBUG"))
                {
                    Console.Error.WriteLine("[x-cli] negative delay ignored");
                }
                return 0;
            }
            if (value > MaxDelayMs)
            {
                if (Env.GetBool("XCLI_DEBUG"))
                {
                    Console.Error.WriteLine($"[x-cli] delay truncated to {MaxDelayMs}ms");
                }
                return MaxDelayMs;
            }
            return value;
        }
    }

    private class Config
    {
        public Defaults? defaults { get; set; }
        public Dictionary<string, Defaults>? commands { get; set; }
    }
    private class Defaults
    {
        public bool? fail { get; set; }
        public int? exitCode { get; set; }
        public string? message { get; set; }
        public int? delayMs { get; set; }
    }

}

public record SimulationPlanResult(SimulationPlan Plan, SimulationPlanError? Error);

public enum SimulationPlanError
{
    ConfigNotFound,
    ConfigPermissionDenied,
    ConfigParseError,
}
