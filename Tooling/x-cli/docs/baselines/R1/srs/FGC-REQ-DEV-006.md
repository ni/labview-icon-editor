# FGC-REQ-DEV-006 — Workflows declare valid SRS IDs
Version: 1.0

## Description
Each GitHub Actions workflow must include one or more `# SRS: FGC-REQ-...` annotations. Every referenced ID must exist in `docs/traceability.yaml`. The `scripts/verify-workflow-srs.py` script fails if a workflow is missing the annotation or uses an unknown ID.

## Rationale
Annotating workflows with SRS IDs links CI behavior to documented requirements.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall each GitHub Actions workflow must include one or more `# SRS: FGC-REQ-...` annotations.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-DEV-006.md