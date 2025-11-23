---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Plan reuses the tailored policy/strategy and CI-generated §8 reports to keep project-level coverage, reporting, and release gates aligned with RTM/TRW.
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
document_control:
  unique_id: TEST-PLAN-001
  issuer: Automation QA
  approval_authority: Maintainer
  status: active
  change_history:
    - version: 1.1.0
      date: 2025-11-21
      description: Added §7.2 context, risk register, and schedule/milestones; linked plan into CI summary.
    - version: 1.0.0
      date: 2025-11-20
      description: Added §5.2 document control header, change log, and glossary reference.
  intro: >
    Project-level test plan that reuses the tailored policy/strategy and CI-generated §8 reports to govern PR and release readiness.
  scope: >
    Applies to the LabVIEW Icon Editor repository and the CI workflows that generate ISO 29119-3 §8 progress/completion reports.
  references:
    - docs/testing/policy.md
    - docs/testing/strategy.md
    - docs/testing/templates/test-report-template.md
    - docs/requirements/rtm.csv
    - docs/requirements/TRW_Verification_Checklist.md
  glossary: docs/testing/glossary.md
---

# Test Plan (ISO/IEC/IEEE 29119-3 §8)

Scope: project-level plan for the LabVIEW Icon Editor repository. It reuses the Test Policy and Strategy and provides the release/PR exit criteria. Owners: Maintainer (sign-off) and Automation QA (evidence curator).

## §5.2 Document Control
| Field | Value |
| --- | --- |
| Unique ID | `TEST-PLAN-001` |
| Issuer | Automation QA |
| Approval Authority | Maintainer |
| Status | Active |
| Change History | 2025-11-21 v1.1.0 - Added §7.2 context, risk register, schedule, and CI linkage; 2025-11-20 v1.0.0 - Added §5.2 header, change log, and glossary linkage. |
| Intro | Project-level test plan aligned to the tailored policy/strategy plus CI §8 reports. |
| Scope | LabVIEW Icon Editor repository and CI workflows that emit ISO 29119-3 §8 progress/completion reports. |
| References | `docs/testing/policy.md`; `docs/testing/strategy.md`; `docs/testing/templates/test-report-template.md`; `docs/requirements/rtm.csv`; `docs/requirements/TRW_Verification_Checklist.md` |
| Glossary | [`docs/testing/glossary.md`](./glossary.md) |

## §7.2.2 Context (project scope and constraints)
- Scope is the LabVIEW Icon Editor repository plus CI workflows (`ci.yml`, `dod-aggregator.yml`, `test-report.yml`) that generate ISO §8 status/completion reports.
- Drivers: RTM priorities and TRW checklist items determine coverage thresholds and reporting content; policy/strategy set the tailored artifact set (plan + CI-generated §8 reports).
- Constraints: LabVIEW tests depend on self-hosted `test-2021-x64`/`test-2021-x86` runners; outages pause merges (tracked in risk register) and require status reports noting the gap.
- Interfaces: release automation uploads completion reports and VIP assets; RTM coverage and ADR lint gates block merges when gaps/waivers are missing.

## §7.2.6 Risk Register (product + project)
| Risk ID | Type | Description | Impact (if realized) | Mitigation/Owner | Status |
| --- | --- | --- | --- | --- | --- |
| R-PROD-01 | Product | High/Critical RTM item missing coverage or traceability. | Release block until the gap is closed or an ADR-backed waiver is approved. | Automation QA adds tests/links; Maintainer approves/records waivers; enforced by RTM coverage/validation gates. | Monitored each PR/run |
| R-PROD-02 | Product | Portability or performance regression on `test-2021-x86` vs `test-2021-x64`. | Release blocker; may halt draft release and require hotfix branch. | Run dual-arch CI; compare against performance baselines; waivers require Maintainer approval and completion report note. | Monitored per tag/High RTM change |
| R-PROD-03 | Product | Workflow metadata drift (VIPB display info or release asset packaging). | Corrupt/discoverability issues in shipped VIP; failed release audit. | Pester workflow tests (`Test/ModifyVIPBDisplayInfo.Tests.ps1`); release job checks artifacts before upload. | Monitored |
| R-PROJ-01 | Project | Self-hosted LabVIEW runners unavailable or queue saturated. | CI unable to run LabVIEW suites; merges freeze and status reports flag outage. | Maintainer pauses protected branch merges; Automation QA files issue and tracks ETA; rerun tests when runner restored. | Open (contingency in §8.5) |
| R-PROJ-02 | Project | RTM/TRW drift from repository reality (stale requirements). | False sense of coverage; gates may pass while scope is outdated. | Weekly RTM/TRW sync (see schedule); checklist/XLSX regen gate in CI; Maintainer reviews RTM diffs on PRs. | Monitored weekly |
| R-PROJ-03 | Project | CI summary/reports missing from PR/release artifacts. | Loss of audit trail; manual verification needed before sign-off. | Test-report workflow uploads status report; release job attaches completion report; DoD summary points to this plan. | Monitored per run |

## §7.2.10 Schedule and Milestones
| Date (UTC) | Milestone | Owner | Entry/Exit criteria |
| --- | --- | --- | --- |
| 2025-11-21 | Publish updated test plan (context, risks, schedule) and wire into CI summaries. | Automation QA | Exit: `docs/testing/test-plan.md` merged; DoD summary references plan. |
| 2025-11-25 | RTM/TRW sync checkpoint before next release window. | Automation QA / Maintainer | Entry: open RTM/TRW diffs; Exit: CSV/XLSX regenerated, coverage thresholds verified ≥ High=100%/Overall=75%. |
| 2025-12-02 | Portability/performance smoke for upcoming tag (if release-ready). | Automation QA | Exit: measurements uploaded to `reports/performance-measurements.json`; portability matrix green or waivers logged. |
| 2025-12-05 | Earliest release candidate cut via draft release if gates pass. | Release Manager | Entry: RTM/ADR/Docs Link Check/DoD summary green; Exit: `reports/test-completion-<tag>.md` attached to release. |
| Weekly (Fri) | Risk register/plan review and CI gate health check. | Maintainer / Automation QA | Exit: risk statuses updated; schedule adjusted if runner/gate issues persist. |

## §8.1 Context and Items Under Test
- Test items: LabVIEW Icon Editor project (`lv_icon_editor.lvproj`), supporting scripts (`.github/scripts/*.py`), and workflows under `.github/workflows/`.
- Inputs: RTM (`docs/requirements/rtm.csv`) and TRW checklist (`docs/requirements/TRW_Verification_Checklist.md`).
- Out of scope: organization-wide quality manuals; they are replaced by the project tailoring recorded here.

## §8.2 Approach and Environment
- Method: RTM-driven regression with priorities determining coverage; execution via CI and self-hosted LabVIEW runners. Design choices inherit from `docs/testing/strategy.md`.
- Environments: `test-2021-x64` and `test-2021-x86` for LabVIEW unit tests; Ubuntu runners for analysis gates and reporting.
- Documentation set: policy, strategy, and this plan; ISO 29119-3 §8 progress/completion template (`docs/testing/templates/test-report-template.md`) emitted as CI reports.

## §8.3 Deliverables
- Progress report per PR run: `reports/test-status-<run>.md`.
- Completion report per tagged release: `reports/test-completion-<tag>.md` (attached to the GitHub Release).
- Supporting artifacts: `test-results.json`, RTM CSV/XLSX, TRW checklist, DoD summary artifact, lychee report.

## §8.4 Completion Criteria (tailored)
- RTM coverage: High/Critical = 100%; overall RTM test presence >= 75% (matches `.github/scripts/check_rtm_coverage.py` thresholds).
- Traceability: `.github/scripts/validate_rtm.py` succeeds; no missing code/test links for Critical items.
- Documentation gates: Docs Link Check green; ADR lint green; DoD Aggregator green.
- Reporting: `reports/test-status-<run>.md` generated for the PR run; `reports/test-completion-<tag>.md` generated and attached for the release tag.
- Releases: tag `vX.Y.Z` created manually/during release; draft-release workflow uploads artifacts (VIP + release notes + completion report).

## §8.5 Risks, Assumptions, and Contingencies
- Risk sources: RTM `priority` and any open TRW checklist actions. High/Critical gaps block release until closed or waived via ADR.
- Contingency: if LabVIEW runners are unavailable, freeze merges to protected branches; generate status report noting the outage and track remediation in a GitHub issue.

## §8.6 Tailoring Notes
- Document set reduced to policy/strategy/plan plus CI-generated §8 reports; design/case/procedure specs are represented by RTM rows pointing to tests.
- Waivers to coverage or traceability must be captured as ADRs and reflected in the next status/completion report.

## Change History
| Date | Version | Description |
| --- | --- | --- |
| 2025-11-21 | 1.1.0 | Added §7.2 context, risk register, schedule/milestones, and CI linkage. |
| 2025-11-20 | 1.0.0 | Added §5.2 document control header, change log, and glossary linkage. |
