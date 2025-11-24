---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Template for automated §8.4 test procedures used by CI or scripted LabVIEW suites.
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
document_control:
  unique_id: TEST-PROC-AUTO-TEMPLATE-001
  issuer: Automation QA
  approval_authority: Maintainer
  status: active
  change_history:
    - version: 1.0.0
      date: 2025-11-26
      description: Initial automated procedure template with start/stop/wrap-up sections.
  intro: >
    Skeleton for automated test procedures derived from RTM and model-based test case specs.
  scope: >
    Applies to LabVIEW/unit-test driven procedures executed via CI or local automation.
  references:
    - docs/testing/policy.md
    - docs/testing/strategy.md
    - docs/testing/test-plan.md
    - docs/testing/templates/test-report-template.md
  glossary: docs/testing/glossary.md
---

# <Feature> Automated Test Procedure (ISO/IEC/IEEE 29119-3 §8.4)

- Procedure ID: `<PROC-ID>`
- Applicable requirements: `<RTM IDs>`
- Test case specification: `<docs/testing/specs/<slug>-tcs.md>`
- Executor: `automation` (self-hosted LabVIEW runner)

## Start Conditions
- Environment ready: LabVIEW version `<version>` available on runner; repo checked out at `<commit/tag>`.
- Pre-conditions: fixtures `<fixture list>` installed; prerequisite services `<services>` available.
- Data: input payloads `<paths>` and expected results `<paths>`.

## Procedure Steps (ordered)
1) Launch runner environment (`<command>`).
2) Execute test suite `<suite name>` at `<path>`.
3) Collect artifacts (logs, `test-results.json`, generated reports).
4) Record outcomes against coverage items from `<spec path>` (e.g., `P1`, `P2`, ...).

## Expected Results
- All mapped test cases PASS; any FAIL is logged with defect or waiver ID.
- Artifacts uploaded: `<artifact list>`.

## Stop / Wrap-up
- Stop criteria: end of suite or first blocking failure.
- Wrap-up: archive logs, update completion/status report, attach artifacts to PR/tag run.

## Change History
| Date | Version | Description |
| --- | --- | --- |
| 2025-11-26 | 1.0.0 | Initial template. |
