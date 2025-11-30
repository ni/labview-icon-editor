# FGC-REQ-CI-002 — Auto-advance on green
Version: 1.0

## Description
Automatically promote issues in the waterfall when the build is green.
- `.github/workflows/auto-advance-on-green.yml` triggers when CI passes on the default branch.
- The workflow moves the current waterfall issue to the next stage.

## Rationale
Automating waterfall transitions keeps progress flowing without manual intervention.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall automatically promote issues in the waterfall when the build is green.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-002.md