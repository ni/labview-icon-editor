# FGC-REQ-DEV-001 — Traceability updater records commit evidence
Version: 1.0

## Description
The `scripts/update_traceability.py` tool records commit hashes for referenced requirement IDs in `docs/traceability.yaml` based on the latest commit message and PR body.

## Rationale
Linking commits to requirements preserves an auditable history of changes.

## Verification
- Run `scripts/update_traceability.py` after a commit and confirm `tests/test_update_traceability.py` records the hash in `docs/traceability.yaml`.

