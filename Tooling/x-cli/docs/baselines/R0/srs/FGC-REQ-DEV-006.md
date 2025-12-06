# FGC-REQ-DEV-006 — Workflows declare valid SRS IDs
Version: 1.0

## Description
Each GitHub Actions workflow must include one or more `# SRS: FGC-REQ-...` annotations. Every referenced ID must exist in `docs/traceability.yaml`. The `scripts/verify-workflow-srs.py` script fails if a workflow is missing the annotation or uses an unknown ID.

## Rationale
Annotating workflows with SRS IDs links CI behavior to documented requirements.

## Verification
- Run `scripts/verify-workflow-srs.py` and confirm `tests/test_verify_workflow_srs.py` reports failures for missing or invalid IDs.
