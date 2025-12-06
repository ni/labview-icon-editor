# FGC-REQ-CI-006 — Design lock
Version: 1.0

## Description
Validate design documents using the codex script.
- `.github/workflows/design-lock.yml` runs on pull requests that touch design artifacts.
- The workflow invokes `python scripts/validate_design.py` to ensure `docs/Design.md` is approved and traceability is valid.

## Rationale
Protecting design artifacts requires basic validation while manual approvals occur separately.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall validate design documents using the codex script.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-006.md