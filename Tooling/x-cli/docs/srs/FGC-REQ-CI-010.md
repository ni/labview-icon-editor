# FGC-REQ-CI-010 - Telemetry aggregate
Version: 1.0

## Description
Collect and publish aggregated telemetry from recent CI runs.
- `.github/workflows/telemetry-aggregate.yml` gathers telemetry artifacts from other workflows.
- The workflow publishes a combined summary for downstream analysis.

## Rationale
Aggregated telemetry provides insight into CI health trends and regressions.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall collect and publish aggregated telemetry from recent CI runs.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-010.md
