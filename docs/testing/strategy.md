---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Strategy aligns to the tailored document set and CI-first execution model that enforce RTM/TRW-driven coverage and reporting at the project level.
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
document_control:
  unique_id: TEST-STRATEGY-001
  issuer: Automation QA
  approval_authority: Maintainer
  status: active
  change_history:
    - version: 1.2.0
      date: 2025-11-20
      description: Added performance baseline format/runbook and repository locations.
    - version: 1.1.0
      date: 2025-11-20
      description: Documented test types (functional, performance, portability), techniques, completion criteria, communication, and staffing.
    - version: 1.0.0
      date: 2025-11-20
      description: Added §5.2 document control header, glossary reference, and change log starter.
  intro: >
    Project-level test strategy for the LabVIEW Icon Editor repository that operationalizes the policy into test levels, risk handling, and reporting cadence.
  scope: >
    Applies to all testing activities and CI workflows in this repository and informs the project test plan and generated §8 reports.
  references:
    - docs/testing/policy.md
    - docs/testing/test-plan.md
    - docs/requirements/rtm.csv
    - docs/requirements/TRW_Verification_Checklist.md
    - docs/testing/performance-baselines.json
    - docs/testing/templates/performance-baseline.json
  glossary: docs/testing/glossary.md
---

# Test Strategy (ISO/IEC/IEEE 29119-3 Tailored)

Scope: project-level strategy for the LabVIEW Icon Editor in this repository. It operationalizes the Test Policy and drives the Test Plan for PRs and releases.

## §5.2 Document Control
| Field | Value |
| --- | --- |
| Unique ID | `TEST-STRATEGY-001` |
| Issuer | Automation QA |
| Approval Authority | Maintainer |
| Status | Active |
| Change History | 2025-11-20 v1.2.0 - Added performance baseline format/runbook and storage locations; 2025-11-20 v1.1.0 - Documented test levels/types (functional, performance, portability), techniques, completion criteria, communication, and staffing; 2025-11-20 v1.0.0 - Added §5.2 header, glossary link, and change log. |
| Intro | Project-level test strategy that converts the policy into test levels, risk handling, and reporting cadence. |
| Scope | Applies to testing activities and CI workflows in this repository; informs the project plan and generated §8 reports. |
| References | `docs/testing/policy.md`; `docs/testing/test-plan.md`; `docs/requirements/rtm.csv`; `docs/requirements/TRW_Verification_Checklist.md`; `docs/testing/performance-baselines.json`; `docs/testing/templates/performance-baseline.json` |
| Glossary | [`docs/testing/glossary.md`](./glossary.md) |

## Approach
- Levels and types: LabVIEW unit tests under `Test/` plus targeted workflow/automation checks (RTM validation, coverage, ADR lint, link checks) with non-functional sanity (performance, portability) triggered by risk/priority.
- Design inputs: requirements in `docs/requirements/rtm.csv` (priority, verification method) and TRW checkpoints in `docs/requirements/TRW_Verification_Checklist.md`.
- Coverage thresholds: High/Critical requirements require 100% test presence; overall RTM requires >=75% test presence (enforced by `.github/scripts/check_rtm_coverage.py`).
- Execution model: CI-first. Unit tests run on self-hosted LabVIEW runners; RTM and documentation gates run on Ubuntu runners. Local execution mirrors CI via the DoD runbook in `docs/dod.md`.
- Reporting: CI emits ISO 29119-3 §8-aligned progress reports (`reports/test-status-<run>.md`) on PRs and completion reports (`reports/test-completion-<tag>.md`) on tags/releases.
- Performance baselines: version-controlled records live in `docs/testing/performance-baselines.json` using the template `docs/testing/templates/performance-baseline.json`; refreshed for High/Critical RTM changes and before releases.

## Test Levels, Types, and Techniques
- Functional / Unit: LabVIEW tests under `Test/Unit Tests/...` validate editor positioning/config persistence. Techniques: boundary-value combinations for INI states, state reset fixtures, and golden comparisons for persisted coordinates.
- Functional / Workflow: Pester suite `Test/ModifyVIPBDisplayInfo.Tests.ps1` drives `scripts/modify-vipb-display-info` against fixtures to guarantee release metadata correctness. Techniques: scenario scripting, isolated temp fixtures, and XML field assertions.
- Static / Compliance: RTM validation, RTM coverage, ADR lint, and Docs Link Check enforce traceability and documentation integrity. Techniques: rule-based linting, structural coverage across RTM rows, and broken-link detection.
- Performance: Timed smoke checks on editor startup/position adjustment flows and VIPB metadata update script. Techniques: measured runs (`Measure-Command` or LabVIEW profiler samples) compared to the last tagged baseline and recorded in the completion report. Triggered on High/Critical RTM items or before release.
- Portability: Cross-architecture runs on `test-2021-x64` and `test-2021-x86` for LabVIEW unit tests and workflow/Pester checks. Techniques: identical suites across architectures; any arch-specific failure is a release blocker unless explicitly waived and logged in RTM plus the completion report.

## Risk and Prioritization
- Risk signal: RTM `priority` plus any open TRW checklist findings. High/Critical gaps block releases. Medium/Low gaps are tracked but may defer if recorded in RTM and surfaced in status reports.
- Mitigation: missing coverage or broken traceability must be fixed or waived by a Maintainer via ADR if they affect exit criteria.

## Environments and Data
- Test environments: self-hosted LabVIEW runners `test-2021-x64`/`test-2021-x86` for execution; Ubuntu runners for analysis gates.
- Test artifacts: `test-results.json` (unit tests), RTM CSV/XLSX, TRW checklist, generated reports in `reports/`.

## Performance Baselines
- Store of record: `docs/testing/performance-baselines.json` (version-controlled); add entries using `docs/testing/templates/performance-baseline.json`.
- Fields per entry: scenario, architecture, metric name, unit, baseline_value, tolerance_pct (default 0.10), source (test/script), tag, commit, timestamp_utc, notes.
- Measurement runbook: for High/Critical RTM touches and pre-release, capture 3 samples per scenario/architecture (LabVIEW profiler or `Measure-Command`), record the median, and log the source test name in `source`.
- Review rules: regressions beyond tolerance_pct require a Maintainer waiver; variances and waivers are called out in the completion report.
- Report inputs: drop measured samples for the current run into `reports/performance-measurements.json` using `docs/testing/templates/performance-measurements.json`; release reports read this file to compare against baselines.

## Staffing (§7.2.9)
- Maintainer: final authority for waivers and release/block decisions; ensures performance/portability waivers are documented in RTM and completion reports.
- Automation QA: maintains RTM/TRW, curates test templates, instruments performance samples when triggered, and prepares status/completion reports.
- Release Manager: drives draft-release workflow, confirms required reports/artifacts are attached, and checks that portability/performance gates are satisfied or waived by Maintainer.
- Contributors: map changes to RTM IDs in PR descriptions, run the DoD aggregator locally, and flag performance/portability risk in the PR when touching relevant areas.

## Communication (§7.2.5)
- PR/CI: GitHub Checks plus `reports/test-status-<run>.md` attached to workflow summary; Maintainer references these before review/merge.
- Releases: `reports/test-completion-<tag>.md` uploaded by the release workflow and linked from the release notes; Release Manager confirms attachment.
- Exceptions: defects or waivers captured via GitHub Issues/ADRs with RTM ID linkage and called out in the next status/completion report; Maintainer signs off.
- Status cadence: CI runs emit automated status; weekly/as-needed summaries go to project maintainers when risks remain open across runs.

## Completion Criteria
- Functional: all High/Critical RTM items executed and passing; TRW checklist blocking items closed or waived; no open Sev-1/Sev-2 defects on touched areas.
- Performance: latest measured samples within tolerance_pct (default 10%) of stored baselines in `docs/testing/performance-baselines.json` or an approved waiver logged by Maintainer in RTM plus the completion report.
- Portability: tests pass on both `test-2021-x64` and `test-2021-x86`; any skipped architecture requires a Maintainer waiver noted in the completion report.
- Structural: RTM coverage >=75% overall and 100% for High/Critical; ADR lint and Docs Link Check passing; status/completion reports generated for the run/tag.

## Entry/Exit Hooks
- Entry (development/PR): DoD Aggregator green, RTM validation, RTM coverage, ADR lint, Docs Link Check; performance/portability checks triggered when the change touches High/Critical RTM items; test status report uploaded for the run.
- Exit (release): draft-release workflow completes, completion report attached for the tag, RTM thresholds met, performance sample recorded or waived, portability verified on both architectures, no broken links.

## Change History
| Date | Version | Description |
| --- | --- | --- |
| 2025-11-20 | 1.2.0 | Added performance baseline format/runbook and repository locations. |
| 2025-11-20 | 1.1.0 | Documented test levels/types (functional, performance, portability), techniques, completion criteria, communication, and staffing. |
| 2025-11-20 | 1.0.0 | Added §5.2 document control header, glossary reference, and change log starter. |

