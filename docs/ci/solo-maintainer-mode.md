# Solo Maintainer Mode

## Purpose

This document defines the CI/CD operating contract for this repository when a single maintainer manages integration and release.

Date adopted: **2026-02-11**

## Canonical Integration Lane

- Source branch for current reconciliation cycle: `reconcile/issue-91-forward-port-456`
- Immediate integration target branch: `456-2020-migration`
- Integration model: **PR-gated** (no direct merge from automation scripts)
- Merge strategy: **merge commits only** for CI/tooling auditability

## Publish Policy

- Publish model: **manual publish intent**
- `ci-composite.yml` does not auto-publish prereleases from `push` events.
- Prerelease dispatch requires:
  - `workflow_dispatch`
  - `publish_prerelease=true`
  - `expected_sha=<sha>`
  - `strict_sha=true`

## Required Merge Checks

For protected integration branches in solo mode, require only:

- `CI Pipeline (Composite) / Pipeline Contract`
- `CI Pipeline (No Smoke) / Pipeline Contract`

No reviewer count is required in branch protection for solo-maintainer operation.

Optional helper:

- `Tooling/Set-SoloMaintainerBranchProtection.ps1` configures branch protection and repository merge strategy (`allow_merge_commit=true`, `allow_rebase_merge=false`).

## Allowed Manual Workflows

- `.github/workflows/development-mode-toggle.yml`
- `.github/workflows/labview-parity.yml`
- `.github/workflows/runner-audit.yml`
- Collaboration-heavy workflows that are manual-only in solo mode:
  - `.github/workflows/stale-issues.yml`
  - `.github/workflows/labels-sync.yml`
  - `.github/workflows/label-metadata-gate.yml`
  - `.github/workflows/label-metadata-audit.yml`
  - `.github/workflows/label-metadata-normalize.yml`
  - `.github/workflows/repo-agnostic-issue-routing.yml`
  - `.github/workflows/ci-debt-train.yml`
  - `.github/workflows/ci-debt-policy-gate.yml`

## Forbidden CI Behaviors

CI workflow paths must not reintroduce:

- Selector set/unset pipeline plumbing in container parity scripts.
- CI-side development-mode toggles (`Set_Development_Mode.ps1`, `revert_dev_mode` in CI jobs).

Enforced by:

- `Tooling/Test-CiPipelineSelectorDevModeContract.ps1`
- `Tooling/Test-SoloMaintainerWorkflowContract.ps1`

Manual/local development-mode operations remain supported through:

- `.github/workflows/development-mode-toggle.yml`

## LLM Execution Entry Point

Use:

- `Tooling/Run-LlmSoloFlow.ps1`

Supported modes:

- `validate`
- `integrate`
- `release`

Operational runbook:

- `docs/ci/llm-operator-runbook.md`

## Related References

- `docs/ci-workflows.md`
- `Tooling/Test-CiPipelineSelectorDevModeContract.ps1`
- `Tooling/Test-SoloMaintainerWorkflowContract.ps1`
