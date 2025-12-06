# FGC-REQ-CI-015 — Waterfall advance
Version: 1.0

## Description
Move issues to the next waterfall stage on a timed cadence.
- `.github/workflows/waterfall-advance.yml` runs on a schedule and updates issue labels to the next stage.
- The workflow skips issues that are already at the final stage.

## Rationale
Scheduled advancement keeps backlog items progressing without manual updates.

## Verification
- Trigger `.github/workflows/waterfall-advance.yml` and verify that eligible issues receive the next-stage label.
