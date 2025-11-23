---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Template for manual §8.4 procedures when human validation is required (e.g., workflow governance).
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
document_control:
  unique_id: TEST-PROC-MANUAL-TEMPLATE-001
  issuer: Automation QA
  approval_authority: Maintainer
  status: active
  change_history:
    - version: 1.0.0
      date: 2025-11-26
      description: Initial manual procedure template with start/stop/wrap-up guidance.
  intro: >
    Skeleton for manual test procedures derived from RTM and model-based test case specs.
  scope: >
    Applies to checks requiring human verification (e.g., workflow triggers, UI review).
  references:
    - docs/testing/policy.md
    - docs/testing/strategy.md
    - docs/testing/test-plan.md
  glossary: docs/testing/glossary.md
---

# <Feature> Manual Test Procedure (ISO/IEC/IEEE 29119-3 §8.4)

- Procedure ID: `<PROC-ID>`
- Applicable requirements: `<RTM IDs>`
- Test case specification: `<docs/testing/specs/<slug>-tcs.md>`
- Executor: `<role>` (e.g., Automation QA)

## Start Conditions
- Environment ready: `<repo/state>` checked out; required credentials/secrets loaded.
- Pre-conditions: upstream workflow run(s) exist for branch `<branch>` with known conclusions.
- Data: links to upstream runs, expected branch allowlist, and acceptance notes.

## Procedure Steps (ordered)
1) Open upstream CI run URL `<url>` and verify trigger source/event.
2) Inspect downstream workflow run (or re-run) logs for gating conditions.
3) Compare observed behavior to coverage items `<coverage ids>` in `<spec path>`.
4) Capture evidence (screenshots/log excerpts) and attach to run.

## Expected Results
- All gating conditions satisfied for allowed branches; disallowed branches exit safely.
- Evidence captured for each coverage item.

## Stop / Wrap-up
- Stop criteria: all coverage items verified or a blocking defect recorded.
- Wrap-up: attach evidence to PR/tag; update TRW checklist status; log defects/waivers if needed.

## Change History
| Date | Version | Description |
| --- | --- | --- |
| 2025-11-26 | 1.0.0 | Initial template. |
