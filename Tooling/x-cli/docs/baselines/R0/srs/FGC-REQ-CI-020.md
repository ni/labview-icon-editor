# FGC-REQ-CI-020 — Stage 3 validation
Version: 1.0

## Description
Validate Stage 2 artifacts on a self-hosted Windows runner (labels: `self-hosted`, `Windows`) and publish telemetry results.
- `.github/workflows/stage3.yml` runs on a runner tagged `self-hosted` and `Windows`, downloads Stage 2 artifacts and manifest, verifies SHA-256 checksums, and rebuilds `win-x64` when smoke tests fail.
- The workflow is triggered via `workflow_run` after Stage 2 completes successfully and skips execution when Stage 2 fails.
- The workflow computes a telemetry diff or establishes a baseline and posts a summary to Discord.

## Rationale
Windows validation guards against platform-specific regressions and maintains a telemetry history for comparisons.

## Verification
- Trigger `.github/workflows/stage3.yml` after a successful Stage 2 run and confirm artifact validation and telemetry publication complete. Confirm the job does not start when Stage 2 fails.
