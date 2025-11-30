# FGC-REQ-CI-006 — Design lock
Version: 1.0

## Description
Validate design documents using the codex script.
- `.github/workflows/design-lock.yml` runs on pull requests that touch design artifacts.
- The workflow invokes `python scripts/validate_design.py` to ensure `docs/Design.md` is approved and traceability is valid.

## Rationale
Protecting design artifacts requires basic validation while manual approvals occur separately.

## Verification
- Open a pull request modifying design files and observe `.github/workflows/design-lock.yml` running the codex validation script.
