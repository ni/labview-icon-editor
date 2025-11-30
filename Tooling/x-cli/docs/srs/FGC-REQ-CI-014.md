# FGC-REQ-CI-014 - Stage locks & traceability on advance (Deprecated)
Version: 1.0

## Statement(s)
- RQ1. [Deprecated] When a stage advanced, the previous stage was marked **locked** and recorded in `.codex/state.json`, and the PR carried only the current `stage:*` label.

## Rationale
Prevents regressions and enforces single-direction progression.

## Verification
Deprecated — waterfall validation removed from the pipeline.

## Attributes
Priority: High
Owner: QA
Status: Deprecated
Trace: (historical) `.github/workflows/validate-waterfall-state.yml`, `scripts/waterfall_state.py`
