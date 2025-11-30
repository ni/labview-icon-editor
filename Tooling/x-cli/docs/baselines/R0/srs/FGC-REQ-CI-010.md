# FGC-REQ-CI-010 — Telemetry aggregate
Version: 1.0

## Description
Collect and publish aggregated telemetry from recent CI runs.
- `.github/workflows/telemetry-aggregate.yml` gathers telemetry artifacts from other workflows.
- The workflow publishes a combined summary for downstream analysis.

## Rationale
Aggregated telemetry provides insight into CI health trends and regressions.

## Verification
- Execute `.github/workflows/telemetry-aggregate.yml` and confirm a telemetry summary artifact is produced.
