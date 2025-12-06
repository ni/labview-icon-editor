# FGC-REQ-CI-014 — Validate waterfall state
Version: 1.0

## Description
Check that project issues align with the defined waterfall process.
- `.github/workflows/validate-waterfall-state.yml` examines open issues and their labels.
- The workflow fails if issues violate the expected state transitions.

## Rationale
Validating issue state ensures the waterfall reflects actual project progress.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall check that project issues align with the defined waterfall process.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-014.md