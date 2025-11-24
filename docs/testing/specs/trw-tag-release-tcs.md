# Tag & Release Trigger Test Model (§8.2) Test Case Specification (§8.3)

- Model ID: `TM-TRW-001`
- Model source: `docs/testing/models/trw-tag-release-model.md`
- Related requirements: TRW-001 (High)
- Test assets: `docs/requirements/TRW_Verification_Checklist.md`
- Procedures: `docs/testing/procedures/trw-tag-release-procedure.md`

## Coverage Items
| ID | Description |
| --- | --- |
| R1 | Event is `workflow_run` from `CI Pipeline` | Workflow starts; other events are rejected. |
| R2 | `workflow_run.conclusion == success` | Proceed; otherwise exit before tag/release. |
| R3 | `workflow_run.event == push` | Proceed; otherwise exit. |
| R4 | `head_branch` in allowlist (`main`, `develop`, `release-alpha/*`, `release-beta/*`, `release-rc/*` plus extensions) | Proceed; otherwise exit with no-op. |
| R5 | For disallowed branches, workflow performs no tag/release actions | Run exits safely with diagnostic; no tags/releases created. |
| R6 | Concurrency group includes SHA; `cancel-in-progress: true` | Only one run per commit; redundant runs cancel/queue. |
| R7 | TRW checklist and diagnostics are attached as artifacts | Artifacts present for audit when gates trigger/skip. |

## Test Cases
| Case ID | Requirement | Priority | Test Path | Procedure | Coverage Items |
| --- | --- | --- | --- | --- | --- |
| TRW-001-TC1 | TRW-001 | High | `docs/requirements/TRW_Verification_Checklist.md` | `docs/testing/procedures/trw-tag-release-procedure.md` | R1, R2, R3, R4, R5, R6, R7 |