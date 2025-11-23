---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Template reflects the tailored project-level §8 progress/completion reports emitted by CI for RTM/TRW-driven gates.
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
document_control:
  unique_id: TEST-REPORT-TEMPLATE-001
  issuer: Automation QA
  approval_authority: Maintainer
  status: active
  change_history:
    - version: 1.0.0
      date: 2025-11-20
      description: Added §5.2 document control header, glossary reference, and change log starter.
  intro: >
    Template for ISO/IEC/IEEE 29119-3 §8 progress and completion reports emitted by CI runs.
  scope: >
    Applies to CI-generated test status reports for PRs and test completion reports for release tags in this repository.
  references:
    - docs/testing/policy.md
    - docs/testing/strategy.md
    - docs/testing/test-plan.md
    - .github/scripts/generate_test_status.py
    - .github/scripts/generate_test_report.py
  glossary: docs/testing/glossary.md
---

# Test Report Template (ISO/IEC/IEEE 29119-3 §8 – Progress & Completion)

Use this skeleton for CI-generated reports (`reports/test-status-<run>.md` for PRs, `reports/test-completion-<tag>.md` for releases). Tokens (`<...>`) are replaced by `generate_test_status.py`.

## §5.2 Document Control
| Field | Value |
| --- | --- |
| Unique ID | `TEST-REPORT-TEMPLATE-001` |
| Issuer | Automation QA |
| Approval Authority | Maintainer |
| Status | Active |
| Change History | 2025-11-20 v1.0.0 - Added §5.2 header, glossary link, and change log. |
| Intro | Template for ISO/IEC/IEEE 29119-3 §8 progress/completion reports emitted by CI runs. |
| Scope | CI-generated status reports for PRs and completion reports for release tags in this repository. |
| References | `docs/testing/policy.md`; `docs/testing/strategy.md`; `docs/testing/test-plan.md`; `.github/scripts/generate_test_status.py`; `.github/scripts/generate_test_report.py` |
| Glossary | [`docs/testing/glossary.md`](../glossary.md) |

1) **§8.1 Context and Scope**
   - Run/tag: `<run_or_tag>`
   - Event/branch: `<event>`; commit `<sha_short>`
   - Scope: LabVIEW Icon Editor repository; project-level tailoring.

2) **§8.2 Summary and Status**
   - Completion: `<PASS|FAIL>` at UTC `<timestamp>`.
   - Coverage: High/Critical `<x>/<y> = <pct>`; Overall `<x>/<y> = <pct>`; thresholds: 100% / 75%.
   - Suites exercised: `<suite_list>`.

3) **§8.3 Variances and Blocking Issues**
   - RTM gaps: `<list of missing test paths or "none">`.
   - Other blockers: `<link or "none">`.

4) **§8.4 Risks and Mitigations**
   - Risk signal from RTM `priority` and TRW checklist.
   - Mitigation/owner: `<actions>` by `<owner>`.

5) **§8.5 Evidence**
   - RTM: `docs/requirements/rtm.csv`; TRW: `docs/requirements/TRW_Verification_Checklist.md`.
   - CI gates: DoD Aggregator, RTM validation/coverage, ADR lint, Docs Link Check, unit tests.
   - Report source: `<report_path>`.

6) **§8.6 Next Steps**
   - For PRs: fix listed gaps or proceed to merge if PASS.
   - For releases: confirm completion report is attached to the GitHub Release assets.

## Change History
| Date | Version | Description |
| --- | --- | --- |
| 2025-11-20 | 1.0.0 | Added §5.2 document control header, glossary reference, and change log starter. |
