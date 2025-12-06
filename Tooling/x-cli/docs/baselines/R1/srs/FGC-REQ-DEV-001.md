# FGC-REQ-DEV-001 — Traceability updater records commit evidence
Version: 1.0

## Description
The `scripts/update_traceability.py` tool records commit hashes for referenced requirement IDs in `docs/traceability.yaml` based on the latest commit message and PR body.

## Rationale
Linking commits to requirements preserves an auditable history of changes.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall record commit hashes for referenced requirement IDs in the traceability registry based on the latest commit message and PR body.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-DEV-001.md