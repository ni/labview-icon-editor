# ADR: Integration Engine CLI Execution Modes

- **ID**: ADR-2025-005  
- **Status**: Accepted  
- **Date**: 2025-11-26

## Context
The Integration Engine build must run both in automation (devcontainer/CI) and on a Windows host with LabVIEW/VIPM. Historically only the PowerShell wrapper `scripts/ie.ps1` existed, leaving no structured entry point for managed orchestration, inconsistent argument validation, and weak visibility into failures. Managed execution also has hard constraints (Windows, LabVIEW installed) while the wrapper needs to keep working cross-platform for dry runs and log collection.

## Options
- **A** - Keep only the PowerShell wrapper and document its arguments (minimal change; no managed path; harder to validate inputs).
- **B** - Replace the wrapper with a fully managed .NET orchestrator (breaks existing scripts; requires Windows/LabVIEW everywhere).
- **C** - Provide a .NET CLI that defaults to the PowerShell wrapper but offers an explicit `--managed` path for Windows hosts (chosen; maintains backward compatibility while enabling guarded managed orchestration).

## Decision
- Adopt a .NET CLI (`Tooling/dotnet/IntegrationEngineCli`) that defaults to shelling into `scripts/ie.ps1 -Command build-worktree`, streams stdout/stderr, and returns the child exit code (satisfies TOOL-003/TOOL-004). Argument validation rejects unknown flags, invalid bitness (`--bitness`, `--lvlibp-bitness`), invalid LabVIEW minor (`--labview-minor`), or missing repo path early with exit code 1.
- Keep managed mode (`--managed`) as a Windows-only orchestration that calls the underlying PowerShell scripts in order (bind dev mode with Force, close LabVIEW per bitness, build/rename/stash/stage PPLs for 32/64, build VIP via `build_vip.ps1`, revert dev mode). It logs section banners and recaps statuses; failure in any step returns that exit code and prints captured stdout/stderr.
- **Interfaces**: Flags `--repo`, `--ref`, `--bitness`, `--lvlibp-bitness`, `--major/--minor/--patch/--build`, `--company`, `--author`, `--labview-minor`, `--run-both-bitness-separately`, `--pwsh`, `--verbose`, `--managed`, `-h|--help`; defaults match README example  
  `dotnet run --project Tooling/dotnet/IntegrationEngineCli -- --repo . --ref HEAD --bitness 64 --lvlibp-bitness both --major 0 --minor 1 --patch 0 --build 1 --company "LabVIEW-Community-CI-CD" --author "Local Developer"`.
- **Scope/out-of-scope**: In scope: argument parsing, mode selection, process streaming, and error propagation. Out of scope: changing the underlying PowerShell scripts' behavior, LabVIEW installation, or packaging metadata beyond the values passed in.
- **Verification**: TOOL-003 (help shows `--managed`; default path hits `scripts/ie.ps1`), TOOL-004 (invalid repo path produces non-zero exit and streamed error). TOOL-001/TOOL-002 are covered by running the same commands inside the .NET-enabled devcontainer.

## Consequences
- **+** Backward-compatible wrapper invocation plus opt-in managed orchestration for Windows hosts.
- **+** Deterministic exits and streamed logs simplify CI checks and local troubleshooting.
- **-** Managed mode remains Windows/LabVIEW-bound; wrapper relies on external scripts staying in sync.
- **Risks/mitigations**: Drift between managed steps and wrapper (mitigate via shared script calls and CLI defaults); platform dependency for managed (mitigate by gating with `OperatingSystem.IsWindows()` and retaining wrapper as default); accidental parameter misuse (mitigate with strict validation and help text).

## Follow-ups
- [ ] Add automated smoke tests for both wrapper and managed paths (including negative-path missing repo) and wire into CI.
- [ ] Document managed-mode prerequisites (LabVIEW, VIPM, g-cli) in `Tooling/dotnet/IntegrationEngineCli/README.md` and CI playbooks.
- [ ] Monitor script API changes (bind/close/build/stage) to keep CLI argument wiring in sync; add alerts or lints if signatures drift.
