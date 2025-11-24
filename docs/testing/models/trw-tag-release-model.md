# Tag & Release Trigger Test Model (§8.2)

- UID: `TM-TRW-001`
- Objective: Model the gate logic for the draft-release workflow so tests verify triggers, branch policy, and concurrency deduping.
- Priority: High (TRW-001).
- Strategy extract: Static/compliance gates (RTM validation, coverage, ADR lint, link check) plus workflow checks guard release automation (`docs/testing/strategy.md`, Approach).

## Model

### Decision table (workflow gating)
| Rule | Condition | Expected behavior |
| --- | --- | --- |
| R1 Trigger source | Event is `workflow_run` from `CI Pipeline` | Workflow starts; other events are rejected. |
| R2 Upstream result | `workflow_run.conclusion == success` | Proceed; otherwise exit before tag/release. |
| R3 Upstream cause | `workflow_run.event == push` | Proceed; otherwise exit. |
| R4 Branch policy | `head_branch` in allowlist (`main`, `develop`, `release-alpha/*`, `release-beta/*`, `release-rc/*` plus extensions) | Proceed; otherwise exit with no-op. |
| R5 No-op safety | For disallowed branches, workflow performs no tag/release actions | Run exits safely with diagnostic; no tags/releases created. |
| R6 Concurrency dedupe | Concurrency group includes SHA; `cancel-in-progress: true` | Only one run per commit; redundant runs cancel/queue. |
| R7 Evidence upload | TRW checklist and diagnostics are attached as artifacts | Artifacts present for audit when gates trigger/skip. |

## Traceability to RTM IDs
- TRW-001 (High) maps to rules G1–G7 to ensure the workflow only runs when upstream CI succeeds on allowed branches, dedupes per SHA, and produces audit evidence.
