# FGC-REQ-CI-013 — Validate codex metadata
Version: 1.0

## Description
Ensure codex metadata files conform to the expected schema.
- `.github/workflows/validate-codex-metadata.yml` runs a validation script against codex metadata.
- The workflow fails if the metadata is missing or malformed.

## Rationale
Valid metadata enables reliable automation and traceability.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.
## Statement(s)
- RQ1. The system shall ensure codex metadata files conform to the expected schema.
## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/srs/FGC-REQ-CI-013.md