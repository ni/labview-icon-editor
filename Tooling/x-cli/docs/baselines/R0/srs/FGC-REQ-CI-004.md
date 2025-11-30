# FGC-REQ-CI-004 — Codex orchestrator
Version: 1.0

## Description
Coordinate codex execution across repositories.
- `.github/workflows/codex-orchestrator.yml` triggers codex runs for configured repositories.
- The workflow waits for dispatched runs to complete and reports their status.

## Rationale
Central orchestration ensures dependent repositories complete codex tasks before promotion.

## Verification
- Run `.github/workflows/codex-orchestrator.yml` and observe dispatched `codex-execute` jobs completing successfully.
