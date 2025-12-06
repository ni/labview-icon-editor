# FGC-REQ-QA-COV-001 - Coverage Gate
Version: 1.0

## Statement(s)
- RQ1. The repository shall enforce a merged coverage gate for PRs and releases using configured thresholds and emit human‑readable summaries and machine‑readable totals.

## Rationale
Quantified coverage gates provide objective evidence of test sufficiency and prevent regressions.

## Verification
Method(s): Test | Inspection | Demonstration
Acceptance Criteria:
- AC1. The PR coverage workflow fails when totals fall below thresholds in `docs/compliance/coverage-thresholds.json`.
- AC2. The workflow writes `artifacts/coverage-summary.md` and `artifacts/coverage_totals.json`.

## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: .github/workflows/coverage-gate.yml, .github/workflows/test.yml, scripts/enforce_coverage_thresholds.py
