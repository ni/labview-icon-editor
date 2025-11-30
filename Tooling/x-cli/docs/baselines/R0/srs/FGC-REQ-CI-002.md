# FGC-REQ-CI-002 — Auto-advance on green
Version: 1.0

## Description
Automatically promote issues in the waterfall when the build is green.
- `.github/workflows/auto-advance-on-green.yml` triggers when CI passes on the default branch.
- The workflow moves the current waterfall issue to the next stage.

## Rationale
Automating waterfall transitions keeps progress flowing without manual intervention.

## Verification
- Run `.github/workflows/auto-advance-on-green.yml` after a successful build and confirm the waterfall issue advances.
