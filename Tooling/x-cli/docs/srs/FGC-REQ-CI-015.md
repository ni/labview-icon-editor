# FGC-REQ-CI-015 - Orchestrate agents & artifact hand-off (Deprecated)
Version: 1.0

## Statement(s)
- RQ1. [Deprecated] The CI system coordinated stage transitions so that downstream stages consumed upstream artifacts (Stage 2→Stage 3) and failed fast when artifacts were missing.
- RQ2. [Deprecated] The CI system alerted maintainers if a PR remained green but did not advance for a defined interval.

## Rationale
Ensures reliable cross-stage execution and visibility into stuck pipelines.

## Verification
Deprecated — waterfall automation removed from the pipeline.

## Attributes
Priority: Medium
Owner: DevEx
Status: Deprecated
Trace: (historical) `.github/workflows/waterfall-advance.yml`, `.github/workflows/waterfall-stuck-alert.yml`, `scripts/waterfall_artifacts.py`
