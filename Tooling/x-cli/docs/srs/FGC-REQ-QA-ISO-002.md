# FGC-REQ-QA-ISO-002 - ISO/IEC 29148 Compliance Report
Version: 1.0

## Statement(s)
- RQ1. The repository shall compute ISO/IEC 29148 compliance of SRS pages and produce `docs/compliance/report.json` on maintenance runs.

## Rationale
Automated compliance evidence reduces manual audit effort and maintains requirements quality.

## Verification
Method(s): Test | Inspection | Demonstration
Acceptance Criteria:
- AC1. The SRS maintenance workflow generates `docs/compliance/report.json` without error.
- AC2. The report lists totals and per‑page statuses consistent with the SRS set in `docs/srs/`.

## Attributes
Priority: Medium
Owner: QA
Source: Standard — ISO/IEC 29148
Status: Proposed
Trace: .github/workflows/srs-maintenance.yml, scripts/compute_29148_compliance.py
