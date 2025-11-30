# FGC-REQ-CI-013 — Validate codex metadata
Version: 1.0

## Description
Ensure codex metadata files conform to the expected schema.
- `.github/workflows/validate-codex-metadata.yml` runs a validation script against codex metadata.
- The workflow fails if the metadata is missing or malformed.

## Rationale
Valid metadata enables reliable automation and traceability.

## Verification
- Execute `.github/workflows/validate-codex-metadata.yml` and confirm it passes with valid metadata and fails when the file is invalid.
