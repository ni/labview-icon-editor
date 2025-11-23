---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Lean tailoring to a repository-scoped document set (policy, strategy, plan, CI-generated §8 reports) driven by RTM/TRW-based coverage gates.
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
document_control:
  unique_id: TEST-POLICY-001
  issuer: Automation QA
  approval_authority: Maintainer
  status: active
  change_history:
    - version: 1.0.0
      date: 2025-11-20
      description: Initialized §5.2 header, change log, and glossary link.
  intro: >
    Project-level test policy for the LabVIEW Icon Editor repository; sets the minimum gating rules for PRs/tags.
  scope: >
    Applies to all testing artifacts in this repository, including CI-generated §8 reports created by the workflows.
  references:
    - docs/testing/strategy.md
    - docs/testing/test-plan.md
    - docs/requirements/rtm.csv
    - docs/requirements/TRW_Verification_Checklist.md
  glossary: docs/testing/glossary.md
---

# Test Policy (ISO/IEC/IEEE 29119-3 Tailored)

Scope: this policy applies to the LabVIEW Icon Editor project in this repository (project-level tailoring, not organization-wide). It sets the minimum bar for test planning, execution evidence, and reporting required for PRs and releases.

## §5.2 Document Control
| Field | Value |
| --- | --- |
| Unique ID | `TEST-POLICY-001` |
| Issuer | Automation QA |
| Approval Authority | Maintainer |
| Status | Active |
| Change History | 2025-11-20 v1.0.0 - Initialized §5.2 controls and glossary reference. |
| Intro | Project-level test policy for the LabVIEW Icon Editor repository; sets the minimum PR/tag gating rules. |
| Scope | Applies to repository-scoped testing artifacts and CI-generated §8 reports. |
| References | `docs/testing/strategy.md`; `docs/testing/test-plan.md`; `docs/requirements/rtm.csv`; `docs/requirements/TRW_Verification_Checklist.md` |
| Glossary | [`docs/testing/glossary.md`](./glossary.md) |

## Tailoring Decisions (Clause 4.1.3)
- Use RTM-driven, risk-weighted testing: priorities in `docs/requirements/rtm.csv` and TRW checkpoints in `docs/requirements/TRW_Verification_Checklist.md` drive coverage and exit criteria.
- Reduce document set to lean artifacts: policy, strategy, and test plan in `docs/testing/`; ISO 29119-3 §8 templates emitted by CI as test status (`reports/test-status-<run>.md`) and completion (`reports/test-completion-<tag>.md`) reports.
- Evidence must be produced by CI: DoD Aggregator, RTM validation/coverage, Docs Link Check, and test status/completion reports are required on PRs and tags; no manual-only gates.
- Project-only tailoring: organizational quality manuals are out of scope; exceptions must land as ADRs if they affect obligations.

## Principles
- Traceability-first: every requirement with `priority=High|Critical` shall map to a test path; coverage thresholds are enforced automatically.
- Risk-aware: residual risk is expressed via RTM priority and any open TRW findings; releases must be blocked if High/Critical gaps remain.
- Evidence is versioned: RTM, TRW checklist, test plan, and CI-generated reports live in-repo or as GitHub release assets.

## Responsibilities
- Maintainer: owns this policy, approves exceptions, and signs off on release completion reports.
- Automation QA: owns RTM integrity, TRW checklist currency, and CI evidence generation.
- Release Manager: ensures `reports/test-completion-<tag>.md` is attached to releases and matches DoD/RTM thresholds.

## Applicable Standards and References
- ISO/IEC/IEEE 29119-3 (Test Documentation): tailored document set and reporting structure.
- RTM source: `docs/requirements/rtm.csv`; TRW checkpoints: `docs/requirements/TRW_Verification_Checklist.md`.
- CI gates: `.github/workflows/dod-aggregator.yml`, `rtm-validate.yml`, `rtm-coverage.yml`, `docs-link-check.yml`, `test-report.yml`, `draft-release.yml`.
- Templates: `docs/testing/templates/test-report-template.md` (ISO 29119-3 §8 progress/completion template).

## Change History
| Date | Version | Description |
| --- | --- | --- |
| 2025-11-20 | 1.0.0 | Initialized §5.2 document control header, glossary reference, and change log starter. |
