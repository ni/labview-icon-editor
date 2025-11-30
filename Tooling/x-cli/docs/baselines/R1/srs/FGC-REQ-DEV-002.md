# FGC-REQ-DEV-002 — Traceability verification ensures sources and IDs
Version: 1.0

## Description
The `scripts/verify-traceability.py` script ensures each entry in `docs/traceability.yaml` references an existing source file that contains the stated requirement ID.

## Rationale
Validating traceability entries prevents stale or incorrect requirement mappings.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall verify that each traceability entry references an existing source file containing the stated requirement ID.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-DEV-002.md