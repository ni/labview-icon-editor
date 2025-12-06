# FGC-REQ-CI-002 - Auto-advance on green
Version: 1.0

## Statement(s)
- RQ1. The CI system shall automatically advance pull requests across the defined waterfall stages when all objective criteria for the current stage are satisfied.

## Rationale
Removes manual gates and keeps the pipeline flowing; prerequisite for autonomous agent operation.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. When `docs/srs/index.yaml` exists and the SRS smoke passes, the PR label advances from `stage:requirements` to `stage:design` and `.codex/state.json` is updated in the same run.
- AC2. When `docs/Design.md` contains `Status: Approved`, the PR label advances from `stage:design` to `stage:implementation` and prior stage is marked as locked in state.
- AC3. When both Windows & Linux checks and the combined status are green, the PR advances to `stage:testing`.
- AC4. When the Stage 2 artifact `water-stage2-artifacts` exists and tests are green, the PR advances to `stage:deployment`.

## Attributes
Priority: High
Owner: DevEx
Status: Proposed
Trace: Spec-only. Legacy waterfall docs/workflows have been archived.
