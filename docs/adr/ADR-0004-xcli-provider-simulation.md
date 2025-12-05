# ADR 0004: x-cli provider abstraction and simulation hook

## Status
Accepted

## Context
- x-cli executes LabVIEW-related workflows (VI Analyzer/Compare, VIPM apply/build) by spawning PowerShell and g-cli.
- We need a pluggable abstraction to swap execution backends (real vs. simulated) for CI/dry-runs and future toolchains.
- A simulation mode is now available via `XCLI_PROVIDER=sim` with env knobs for failure, exit code, and delay.

## Decision
- Introduce an `ILabviewProvider` abstraction for process execution (`RunPwshScript`, `RunGcli`).
- Default path: `LabviewProviderSelector.Create()` -> `DefaultLabviewProvider` (real execution).
- Simulation: `XCLI_PROVIDER=sim` selects `SimulatedLabviewProvider`, which returns stubbed results and honors:
  - `XCLI_SIM_FAIL=true` to force failure
  - `XCLI_SIM_EXIT=<code>` to set exit code
  - `XCLI_SIM_DELAY_MS=<ms>` to add artificial delay
- Commands wired to the provider: `vi-analyzer-run/verify`, `vi-compare-run`, `vipm-apply-vipc`, `vipm-build-vip`.
- CLI surfaces remain unchanged; only execution backend is swappable.

## Consequences
- Tests/CI can run x-cli without invoking LabVIEW/g-cli by setting `XCLI_PROVIDER=sim`.
- Future backends (e.g., remote executor) can implement `ILabviewProvider` without touching command logic.
- Provider behavior shall remain functionally equivalent to the prior direct process spawning when not in sim mode.

## Provider requirements (initial)
- Shall execute PowerShell/g-cli commands or simulate them with:
  - Captured `StdOut`/`StdErr`, `ExitCode`, `Success`, and `DurationMs`.
  - Timeout handling (124 exit) in default provider; sim provider may honor delay envs.
- Shall be selectable via env (`XCLI_PROVIDER`) with a safe default (real provider).
- Sim provider shall be side-effect free (no file/process creation) and deterministic based on env knobs.
- Default provider shall preserve existing behavior and logging; no CLI flag changes allowed.
- Extensibility: adding a new provider should not require changes to command parsing or response schemas.

## Additional requirements
- Verification consistency: provider shall surface errors/warnings through existing stdout/stderr so downstream parsers don’t break; no schema changes to command outputs (JSON responses).
- Testability: simulated provider shall be usable for all subcommands wired to providers (analyzer run/verify, compare run, VIPM apply/build) and should be harmless if invoked by future commands (returning success by default).
- Timeout semantics: default provider should respect per-command timeouts where they existed; sim provider should allow injection of delays for timeout testing.
- Error injection: via env (sim) to force non-zero exit codes without touching command code.
- Logging/telemetry: provider changes shall not suppress current logs; stdout/stderr are still written for host logging.
- Backward compatibility: commands shall remain operational without setting any new env vars; the factory shall default to the real provider.

## Coverage and next targets
- Currently using providers: `vi-analyzer-run`, `vi-analyzer-verify`, `vi-compare-run`, `vipm-apply-vipc`, `vipm-build-vip`.
- Not yet using providers (future work if needed): `vi-compare-verify`, `vipmcli-build`, `vipc`, `ppl-build`, `lvbuildspec`, and other non-LabVIEW-specific shims.

## Alternatives considered
- Hard-coded simulation flags per command (rejected: scattering logic).
- Partial shims per command (rejected: duplicated process logic).
