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
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall validate Stage 2 artifacts on a self-hosted Windows runner (labels: `self-hosted`, `Windows`) and publish telemetry results.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-020.md