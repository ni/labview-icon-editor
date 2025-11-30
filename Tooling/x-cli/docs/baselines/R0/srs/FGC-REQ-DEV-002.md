# FGC-REQ-DEV-002 — Traceability verification ensures sources and IDs
Version: 1.0

## Description
The `scripts/verify-traceability.py` script ensures each entry in `docs/traceability.yaml` references an existing source file that contains the stated requirement ID.

## Rationale
Validating traceability entries prevents stale or incorrect requirement mappings.

## Verification
- Run `scripts/verify-traceability.py` and confirm `tests/test_verify_traceability.py` passes when entries and files match.

