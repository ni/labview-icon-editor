# FGC-REQ-CI-003 — Codex execute
Version: 1.0

## Description
Run a codex job inside a GitHub Actions runner on demand.
- `.github/workflows/codex-execute.yml` accepts manual dispatch events.
- The workflow spins up a container and invokes the requested codex task.

## Rationale
On-demand codex execution enables targeted validation without full pipeline runs.

## Verification
- Dispatch `.github/workflows/codex-execute.yml` and confirm the codex task completes in the runner.
