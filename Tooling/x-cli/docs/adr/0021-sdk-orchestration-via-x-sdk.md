# ADR 0021: SDK Orchestration via x-sdk (jarvis-sdk archived)

- Date: 2025-09-26
- Status: Accepted


## Context
We want an external Software Development Kit (SDK) to orchestrate x-cli's pipeline without duplicating CI logic. Earlier experiments used a `jarvis-sdk` repository. To reduce legacy coupling and clarify ownership, we will archive `jarvis-sdk` and adopt a clean `x-sdk` repository to drive orchestration using GitHub reusable workflows exposed by x-cli.

## Decision
- Expose Stage 1, Stage 2, and Stage 3 as reusable workflows (`workflow_call`) in this repo.
- Stage 2 SHALL emit outputs: `run_id`, `manifest_path`, `summary_path`, and `diagnostics_path`.
- Stage 1 SHALL emit outputs: `run_id` and `summary_path`.
- Stage 3 SHALL accept inputs: `stage2_repo`, `stage2_run_id`, and optional flags `force_dry_run` and `validate_schema`; it SHALL emit `summary_path`, `diagnostics_path`, and `published`.
- The `x-sdk` repo will own orchestration (callers), examples, and higher-order tooling; x-cli remains unaware of SDK internals.
- Documentation under `docs/integration/x-sdk/` replaces prior `jarvis-sdk` references.

## Consequences
- Orchestration scenarios benefit from a stable contract and decoupled permissions.
- Archiving `jarvis-sdk` reduces confusion and technical debt; new consumers should target `x-sdk`.
- Stage 3 supports deterministic dry-run and optional schema validation for diagnostics, enabling SDK-driven tests without secrets.

## Links
- SRS: FGC-REQ-CI-021 (Reusable Workflow Contracts) and FGC-REQ-SDK-001 (External SDK Orchestration)
- Workflows: `.github/workflows/stage1-telemetry.yml`, `stage2.yml`, `stage3.yml`
- Integration examples: `docs/integration/x-sdk/`

