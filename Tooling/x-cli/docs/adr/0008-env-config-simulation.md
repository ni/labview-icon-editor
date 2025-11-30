# ADR 0008: Environment and Config Precedence for Simulation

- Status: Accepted
- Date: 2025-09-03
- Deciders: x-cli maintainers
- Tags: simulation, configuration

## Context
SimulationPlan loads failure behavior from `XCLI_*` environment variables and an optional JSON file. Clear precedence and failure handling are required so CI scenarios behave predictably.

## Decision
- **Configuration precedence** (highest to lowest):
  1. JSON `commands[<subcommand>]` overrides
  2. JSON `defaults`
  3. Environment variables:
     - `XCLI_FAIL_ON` list supersedes `XCLI_FAIL`
     - `XCLI_EXIT_CODE`, `XCLI_MESSAGE`, `XCLI_DELAY_MS`
  4. Built-in defaults (`fail=false`, `exitCode=1`, `message=""`, `delayMs=0`)
- **Delay clamping:** `delayMs` values <0 become `0`; values >10,000 become `10,000`. When `XCLI_DEBUG=true`, ignored or truncated delays are reported on stderr.
- **Exit-code rules:** all configured codes are clamped to `[0,255]`; successful plans exit `0`; failing plans force a non-zero code (default `1`).
- **Config errors:** when `XCLI_CONFIG_PATH` is set but unreadable:
  - Missing file or directory → `[x-cli] config file not found: <path>`; result marked `ConfigNotFound`.
  - Permission denied → `[x-cli] config file permission denied: <path>`; result marked `ConfigPermissionDenied`.
  - Invalid JSON or other exceptions → `config parse error: <reason>`; result marked `ConfigParseError`.
  In all cases the plan fails, delay is clamped, and exit code defaults to `1` when unspecified.

## Consequences
- Deterministic overrides allow tests and CI to simulate failures precisely.
- Clamped delays and exit codes prevent runaway waits and platform-specific errors.
- Explicit diagnostics help users distinguish missing files from malformed JSON.
