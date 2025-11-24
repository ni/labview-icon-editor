---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Maps ISO/IEC/IEEE 29119-3 §5–§8 information items to the tailored LabVIEW Icon Editor testing documentation and CI evidence.
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
---

# ISO/IEC/IEEE 29119-3 Mapping (Tailored)

This mapping records where the project satisfies each ISO/IEC/IEEE 29119-3 §5–§8 information item or notes a waiver rationale for the tailored scope.

## §5 Test Documentation Process (information items)
| Information item | Satisfied in | Notes/waiver |
| --- | --- | --- |
| Document identification and control | Repository history; PR review gates via [`dod-aggregator.yml`](../../.github/workflows/dod-aggregator.yml) | Version control plus CI gates enforce review and traceability. |
| Storage and accessibility | [`docs/testing`](./) with generated reports under `reports/` | CI uploads status/completion reports for PRs/tags to release assets and artifacts. |
| Tailoring capture | [`Test Policy`](./policy.md) Tailoring Decisions; [`Test Plan`](./test-plan.md) §8.6 Tailoring Notes | Document set reduced to policy, strategy, plan, and CI-generated §8 reports. |
| Maintenance cadence | [`Test Strategy`](./strategy.md) Entry/Exit Hooks; [`docs/dod.md`](../dod.md) | Updates tied to Definition of Done and CI runs; no separate document control manual. |

## §6 Test Policy (information items)
| Information item | Satisfied in | Notes/waiver |
| --- | --- | --- |
| Scope and objectives | [`Test Policy`](./policy.md) introduction/scope | Project-level only; organization-wide policy is out of scope. |
| Roles and responsibilities | [`Test Policy`](./policy.md) Responsibilities | Maintainer, Automation QA, and Release Manager roles defined. |
| Tailoring rules | [`Test Policy`](./policy.md) Tailoring Decisions | Defines reduced artifact set and RTM/TRW-driven coverage expectations. |
| Compliance references | [`Test Policy`](./policy.md) Applicable Standards and References | CI workflows listed as enforcement mechanisms. |
| Approval approach | Maintainer sign-off described in [`Test Policy`](./policy.md) Responsibilities | Approvals recorded through PR review and release sign-off. |

## §7 Test Strategy (information items)
| Information item | Satisfied in | Notes/waiver |
| --- | --- | --- |
| Test levels and scope | [`Test Strategy`](./strategy.md) Approach | LabVIEW unit tests plus workflow/automation gates. |
| Techniques and coverage | [`Test Strategy`](./strategy.md) Approach and Reporting | RTM/TRW-driven coverage thresholds guide design and reporting. |
| Risk management | [`Test Strategy`](./strategy.md) Risk and Prioritization | High/Critical gaps block releases; waivers require ADRs. |
| Environments and data | [`Test Strategy`](./strategy.md) Environments and Data | Self-hosted LabVIEW runners and Ubuntu analysis runners. |
| Organization and roles | [`Test Strategy`](./strategy.md) Roles | Responsibilities for Maintainer, Automation QA, Release Manager. |
| Entry/exit criteria | [`Test Strategy`](./strategy.md) Entry/Exit Hooks | CI gates for PRs and release readiness. |
| Waived items | Continuous test process improvement program | Waived; improvements tracked via ADRs when needed. |

## §8 Test Plan (information items)
| Information item | Satisfied in | Notes/waiver |
| --- | --- | --- |
| Context and items under test | [`Test Plan`](./test-plan.md) §7.2.2 Context; §8.1 Context and Items Under Test | Lists scope constraints, test items, inputs, and out-of-scope boundaries. |
| Approach and environment | [`Test Plan`](./test-plan.md) §8.2 Approach and Environment | References the strategy for method selection and environments. |
| Deliverables | [`Test Plan`](./test-plan.md) §8.3 Deliverables | Includes CI-generated status/completion reports and supporting artifacts. |
| Completion criteria | [`Test Plan`](./test-plan.md) §8.4 Completion Criteria | Coverage/traceability thresholds, documentation gates, and reporting triggers. |
| Risks and contingencies | [`Test Plan`](./test-plan.md) §7.2.6 Risk Register; §8.5 Risks, Assumptions, and Contingencies | Product/project risks maintained in the register with runner outage contingency. |
| Tailoring notes | [`Test Plan`](./test-plan.md) §8.6 Tailoring Notes | Design/case/procedure specs are represented by RTM rows pointing to tests. |
| Schedule and resourcing | [`Test Plan`](./test-plan.md) §7.2.10 Schedule and Milestones; [`Test Strategy`](./strategy.md) Staffing (§7.2.9) | Dated milestones for sync/release windows plus staffing/owner expectations. |
| Progress/completion reporting | [`Test Report Template`](./templates/test-report-template.md); generated reports in `reports/` | CI fills ISO §8 progress/completion reports for PRs and tags/releases. |
