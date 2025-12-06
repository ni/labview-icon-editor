# FGC-REQ-CI-014 — Validate waterfall state
Version: 1.0

## Description
Check that project issues align with the defined waterfall process.
- `.github/workflows/validate-waterfall-state.yml` examines open issues and their labels.
- The workflow fails if issues violate the expected state transitions.

## Rationale
Validating issue state ensures the waterfall reflects actual project progress.

## Verification
- Run `.github/workflows/validate-waterfall-state.yml` and ensure it reports success only when all issues follow the waterfall rules.
