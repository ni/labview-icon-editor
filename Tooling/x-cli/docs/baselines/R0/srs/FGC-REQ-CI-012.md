# FGC-REQ-CI-012 — Trigger codex orchestration
Version: 1.0

## Description
Provide a lightweight entry point for initiating codex orchestration.
- `.github/workflows/trigger-codex-orchestration.yml` emits a `repository_dispatch` event to start `codex-orchestrator.yml`.
- The workflow runs on manual dispatch and on a schedule.

## Rationale
A simple trigger isolates orchestration logic and enables periodic runs.

## Verification
- Run `.github/workflows/trigger-codex-orchestration.yml` and confirm a dispatch event starts the orchestrator workflow.
