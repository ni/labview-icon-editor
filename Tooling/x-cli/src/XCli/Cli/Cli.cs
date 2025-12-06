// ModuleIndex: CLI parsing and help text.
using System.Collections.Generic;
using XCli.Util;
namespace XCli.Cli;

public record CliParseResult(bool ShowHelp, bool ShowVersion, string? Subcommand, string[] PayloadArgs);

             public static class Cli
             {
                 public static readonly HashSet<string> Subcommands = new()
                 {
                     "clearlvcache",
                     "localci-handshake",
                     "vipc",
                     "lvbuildspec",
        "vitester",
        "lunit",
        "vipb",
        "vip",
        "switcheroo",
        "echo",
        "reverse",
        "upper",
        "log-replay",
        "log-diff",
                 "telemetry",
                 "foo",
                 "labview-devmode-enable",
                 "labview-devmode-disable",
                 "vi-compare-verify",
                 "vi-analyzer-verify",
                 "vi-analyzer-run",
                 "vi-compare-run",
                 "source-dist-build",
                 "source-dist-verify",
                 "vipm-apply-vipc",
                 "vipm-build-vip",
                 "vipmcli-build",
                 "ppl-build"
             };

    public static string HelpText =>
        $"Usage: {Env.GetProcessName()} <subcommand> [payload-args...]\n" +
        "Global options:\n" +
        "  --help                print usage and exit\n" +
        "  --version             print the semantic version and exit\n" +
        "Subcommands (case-sensitive):\n" +
        "  " + string.Join(" | ", Subcommands) + "\n" +
        "\n" +
        "Telemetry:\n" +
        "  telemetry summarize --in PATH --out PATH [--history PATH]\n" +
        "      Build a summary JSON from a QA JSONL log and optionally append a history record.\n" +
        "      Notes: reads --in (e.g., artifacts/qa-telemetry.jsonl), writes --out (e.g., telemetry/summary.json).\n" +
        "             If --history is provided, appends a snapshot (uses GITHUB_RUN_ID when available).\n" +
        "  telemetry write --out PATH --step NAME --status pass|fail [--duration-ms N] [--start N] [--end N] [--meta k=v ...]\n" +
        "      Append a single QA event line (JSONL). Creates the output file and directories if needed.\n" +
        "  telemetry check --summary PATH --max-failures N [--max-failures-step step=N ...]\n" +
        "      Gate on failures: total and/or per-step. Repeat --max-failures-step for multiple steps.\n" +
        "  telemetry validate --summary PATH | --events PATH\n" +
        "      Validate summary JSON shape and/or events JSONL lines.\n" +
        "\n" +
        "Rule: tokens after the subcommand are passed through unchanged.\n" +
        "Environment variables (case-insensitive; logged with original casing):\n" +
        "  XCLI_FAIL        simulate failure globally (true|false; ignored when XCLI_FAIL_ON is set)\n" +
        "  XCLI_FAIL_ON     comma-separated subcommands to fail (others succeed)\n" +
        "  XCLI_EXIT_CODE   exit code when failing (values outside 0-255 are clamped to 0 or 255)\n" +
        "  XCLI_MESSAGE     failure message\n" +
        "  XCLI_DELAY_MS    artificial delay in ms\n" +
        "  XCLI_MAX_DURATION_MS max runtime in ms before warning (default 2000)\n" +
        "  XCLI_CONFIG_PATH path to JSON config\n" +
        "  XCLI_LOG_PATH    append JSON log to file (optional)\n" +
        "  XCLI_LOG_TIMEOUT_MS log write timeout in ms (default 10000)\n" +
        "  XCLI_LOG_MAX_ATTEMPTS log write retry limit (default 200)\n" +
        "  XCLI_DEBUG       emit diagnostics on parse/log failure\n" +
        "JSON log fields:\n" +
        "  timestampUtc, pid, os, subcommand, args, env, result, exitCode, message, durationMs";

    public static CliParseResult Parse(string[] args)
    {
        var payload = new List<string>();
        string? sub = null;
        bool showHelp = false;
        bool showVersion = false;
        bool afterDashDash = false;
        foreach (var arg in args)
        {
            if (afterDashDash)
            {
                payload.Add(arg);
                continue;
            }
            if (arg == "--")
            {
                if (sub == null)
                {
                    afterDashDash = true;
                }
                // when a subcommand is already set, skip the separator
                continue;
            }
            if (sub == null)
            {
                if (arg == "--help")
                    showHelp = true;
                else if (arg == "--version")
                    showVersion = true;
                else
                    sub = arg;
            }
            else
            {
                payload.Add(arg);
            }
        }
        if (showHelp || showVersion)
            return new CliParseResult(showHelp, showVersion, null, Array.Empty<string>());
        if (sub == null)
            return new CliParseResult(false, false, null, payload.ToArray());
        return new CliParseResult(false, false, sub, payload.ToArray());
    }
}
