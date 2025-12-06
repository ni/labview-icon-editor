# FGC-REQ-CI-009 — Setup waterfall labels
Version: 1.0

## Description
Create and maintain issue labels used by the project waterfall process.
- `.github/workflows/setup-waterfall-labels.yml` defines all waterfall stage labels in the repository.
- The workflow is idempotent and rerunnable without side effects.

## Rationale
Standardized labels support consistent tracking across workflow stages.

## Verification
- Run `.github/workflows/setup-waterfall-labels.yml` and verify required labels exist in the repository.
