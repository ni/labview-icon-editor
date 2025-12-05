# ADR: DevModeAgentCli Intent Parser

- **ID**: ADR-2025-009  
- **Status**: Accepted  
- **Date**: 2025-11-26

## Context
Automation needs a guarded way to turn natural-language dev-mode intents (e.g., "/devmode bind 2021 64-bit force") into actionable plans without changing the user-facing PowerShell binder. The binder (`.github/actions/bind-development-mode/BindDevelopmentMode.ps1`) is Windows-focused and expects structured flags; running it blindly risks overwriting other repos' LabVIEW.ini tokens or acting on stale state (`reports/dev-mode-bind.json`). ADR-2025-004 established the policy shim concept; this ADR documents the concrete .NET CLI.

## Options
- **A** - Keep calling the PowerShell binder directly from automation with hand-written parsing (error-prone; weak guardrails).
- **B** - Move intent parsing into the PowerShell binder (mixes user UX with agent policy; harder to evolve).
- **C** - Provide a separate .NET CLI that parses intents, enforces guardrails, emits plans, and optionally executes the binder (chosen).

## Decision
- Keep `Tooling/dotnet/DevModeAgentCli` as an automation-only console that parses constrained phrases, builds a plan per intent, and optionally executes the binder. Default summary input is `reports/dev-mode-bind.json` (from the binder); repo defaults to the current directory. Execution is opt-in via `--execute`.
- **Guardrails**: Blocks intents when `expected_path` in the summary differs from the repo, when LabVIEW.ini is missing (summary `status=skip` with a not-found message), or when the requested year differs from `--expected-version` without `--ack-version-mismatch`. Force is applied only when the phrase includes "force" or "overwrite"; otherwise intents pointing elsewhere are blocked. Max intents default to 3 to avoid runaway parsing.
- **Interfaces/CLI example**:  
  `pwsh scripts/common/invoke-repo-cli.ps1 -Cli DevModeAgentCli -- --phrase "/devmode bind 2021 64-bit force and unbind 2023 both-bit" --repo . --summary reports/dev-mode-bind.json --execute --expected-version 2021 --ack-version-mismatch --allow-stale-summary --max-intents 3 --pwsh pwsh`  
  Flags: `--phrase` (required), `--repo`, `--summary`, `--execute`, `--allow-stale-summary`, `--max-intents`, `--expected-version`, `--ack-version-mismatch`, `--pwsh`, `-h|--help`.
- **Outputs/behavior**: Always prints JSON plan (`pending|skip|blocked|failed|completed`) to stdout; exit code 1 when any plan is blocked/failed, else 0. When `--execute` is set, pending plans invoke the binder with `-RepositoryPath`, `-Mode`, `-Bitness`, and optional `-Force`, propagating the binder exit code and error text into the plan.
- **Scope/out-of-scope**: In scope: intent parsing, plan/guard evaluation, binder invocation for automation, and JSON emission. Out of scope: user-facing UX (remains the PowerShell binder), changing binder semantics, or editing LabVIEW.ini directly.
- **Verification**: Aligned with ADR-2025-004 and binder requirements (BIND-011/BIND-012/BIND-013 for prechecks/output paths/scope guards). Smoke: missing summary without `--allow-stale-summary` exits 1 with a diagnostic; phrase already bound/unbound yields `skip`; phrase targeting another path without Force yields `blocked`; `--execute` returns binder exit codes.

## Consequences
- **+** Automation gets deterministic planning plus optional execution with clear exit semantics; users keep the existing binder UX.
- **+** Guardrails reduce accidental overwrites and highlight missing LabVIEW installs before execution.
- **-** Still Windows-bound because it shells to the PowerShell binder; dependent on binder JSON schema staying stable.
- **Risks/mitigations**: Stale summary leading to incorrect decisions (mitigate with `--allow-stale-summary` defaulting to false and hints about missing tokens); binder path drift (mitigate by referencing the repo-relative action path); Force misuse (mitigate by requiring explicit keyword in the phrase and recording ForceApplied in the plan).

## Follow-ups
- [ ] Add unit tests for intent parsing (multiple intents, force detection) and guardrail outcomes (expected_path mismatch, ini missing).
- [ ] Wire the CLI into automation playbooks as the only entry point (explicitly marked automation-only) and document in `docs/ci/dev-mode-bind.md`.
- [ ] Add schema/contract checks against `reports/dev-mode-bind.json` to catch binder output changes early.
