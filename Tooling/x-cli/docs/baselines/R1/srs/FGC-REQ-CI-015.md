# FGC-REQ-CI-015 — Waterfall advance
Version: 1.0

## Description
Move issues to the next waterfall stage on a timed cadence.
- `.github/workflows/waterfall-advance.yml` runs on a schedule and updates issue labels to the next stage.
- The workflow skips issues that are already at the final stage.

## Rationale
Scheduled advancement keeps backlog items progressing without manual updates.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall move issues to the next waterfall stage on a timed cadence.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-015.md