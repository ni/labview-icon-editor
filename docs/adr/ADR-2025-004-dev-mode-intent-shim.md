# ADR: Agent-Only Dev-Mode Intent Shim

- **ID**: ADR-2025-004  
- **Status**: Proposed  _(implementation partially in progress; guarded rollout pending approval)_
- **Date**: 2025-11-24

## Context
Automation wants to drive dev-mode bind/unbind from natural-language intents (e.g., “/devmode bind 2021 64-bit force”) while guarding overwrites of other repos’ LabVIEW.ini tokens. Today, the PowerShell binder is the only entry point; it is user-facing, Windows-bound, and emits JSON but has no agent-oriented intent parsing or structured planning. We need a thin automation shim that enforces policy (prefix, per-intent Force, expected_path checks) and produces machine-readable plans without changing the LabVIEW user experience.

## Options
- **A** - Status quo: use the PowerShell binder directly and keep agent logic in ad-hoc scripts (minimal work; weak guardrails and no structured intent plan for automation).
- **B** - Expand the PowerShell binder to parse intents and enforce agent policy (keeps single tool; mixes user UX with agent policy; harder to evolve independently).
- **C** - Add a separate agent-only CLI (e.g., .NET console) that parses intents, applies guardrails, emits a plan, and delegates execution to the existing PowerShell binder (separation of concerns; extra artifact to build/test).

## Decision
Choose **C**. Introduce a dedicated agent-only CLI that consumes constrained dev-mode phrases, enforces guardrails (required prefix, per-intent Force, expected_path/version checks against `reports/dev-mode-bind.json`), emits a structured plan (pending/skip/blocked with reasons), and optionally executes the existing PowerShell binder per intent. The PowerShell binder remains the sole user-facing tool; the CLI is for automation/policy only and stays Windows-bound because it shells out to the binder. Implementation is partially prototyped (intent parser + PowerShell glue); full adoption is gated on CLI delivery and approval.

## Consequences
- **+** Clear separation: LabVIEW users keep the current binder UX; automation gets a policy/intent shim with structured outputs.
- **+** Guardrails: per-intent Force, expected_path/version checks, and skip logic reduce accidental overwrites (aligns with BIND-005).
- **+** Deterministic automation: consistent JSON plan/exit codes for agent workflows and tests.
- **-** Additional artifact to build/test/version; still Windows-only due to the binder dependency.
- **-** Requires wiring into agent workflows and ongoing maintenance to track binder changes.

## Follow-ups
- [ ] Scaffold `Tooling/dotnet/DevModeAgentCli` with intent parser, plan/guard evaluation, JSON output, and optional execution against the PowerShell binder. (Owner: Automation QA)
- [ ] Add unit/integration tests for parsing, guardrails, and binder invocation; wire into CI. (Owner: Automation QA)
- [ ] Document usage/contract in AGENT.md and link from troubleshooting for automation scenarios (not for LabVIEW users). (Owner: Docs)

> Traceability: BIND-005 (guard scope via Force), AGENT dev-mode intent playbook (AGENT.md §7.6), ADR-2025-003 (dev-mode bind/unbind helper baseline).
