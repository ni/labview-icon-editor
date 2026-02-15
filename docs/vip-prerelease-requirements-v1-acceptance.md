# VI Package Develop Pre-Release Requirements v1.0 Acceptance Matrix

This matrix defines executable acceptance scenarios for `docs/vip-prerelease-requirements.md`.

| Scenario ID | Scope/Profile | Target VR IDs | Setup | Execution | Pass Criteria |
|---|---|---|---|---|---|
| A-001 | Core | VR-SCOPE-001, VR-SCOPE-002, VR-SCOPE-003, VR-SCOPE-004, VR-PUR-001, VR-PUR-002, VR-PUR-003, VR-PUR-004, VR-PUR-005, VR-PUR-006 | Load requirements document. | Parse `VR-` requirement IDs and normative statements. | IDs are unique and monotonic within each VR family; each `shall` statement is independently testable. |
| A-002 | Core | VR-TRIG-001, VR-TRIG-006, VR-TRIG-007, VR-TRIG-008, VR-TRIG-009, VR-TRIG-010 | Push merge commit to `develop` associated with merged PR targeting `develop`, where commit parent count is greater than 1 and PR `merge_commit_sha` equals `github.sha`. | Run `ci-composite.yml`. | Publish context marks run eligible with reason output indicating merged-PR merge-commit auto path and emits `ci_profile=full`. |
| A-003 | Core | VR-TRIG-002, VR-TRIG-007, VR-FAIL-001 | Push direct commit to `develop` without merged PR association. | Run `ci-composite.yml`. | Publish path is ineligible, `publish_status=skipped` is emitted, and workflow remains successful. |
| A-004 | Extended | VR-TRIG-004, VR-TRIG-005, VR-TRIG-007, VR-TRIG-008, VR-OPS-001, VR-OPS-002, VR-OPS-003, VR-OPS-004, VR-OPS-005, VR-OPS-006, VR-FAIL-005 | Dispatch workflow manually with three cases: valid publish intent (`publish_prerelease=true`, `expected_sha=<merged develop merge SHA>`, `strict_sha=true`), false intent (`publish_prerelease=false`), and invalid publish intent (missing `strict_sha=true` or non-eligible SHA). | Compare publish behavior and failure semantics across all dispatch runs. | Valid manual intent publishes; false intent skips; invalid publish intent fails fast with explicit policy errors before publication. |
| A-005 | Core | VR-VER-002, VR-VER-004, VR-VER-005, VR-VER-006 | Use merged PR labels on develop merge (`major`, `minor`, `patch`, none). | Execute version computation in eligible publish runs. | Bump type follows merged PR labels, with default `patch` when no release label exists; override interface behavior is valid. |
| A-006 | Core | VR-VER-003, VR-FAIL-004 | Apply conflicting merged PR release labels (for example `major` and `minor`). | Execute eligible develop publish run. | Version resolution fails with non-zero exit and explicit conflict error. |
| A-007 | Core | VR-VER-001 | Prepare run with known computed `VERSION` output. | Publish prerelease and inspect release metadata. | Release tag and title equal `needs.version.outputs.VERSION` exactly. |
| A-008 | Core | VR-PUB-001, VR-PUB-002, VR-PUB-006, VR-PUB-007, VR-PUB-008 | Prepare release notes file and eligible publish run. | Publish prerelease and inspect release flags/body and status artifact. | Release is `prerelease=true`, `draft=false`, body matches generated release notes content, and publish status file/artifact are emitted after successful prepublish gate. |
| A-009 | Core | VR-PUB-004, VR-AST-003 | Re-run publish for same computed version tag. | Execute two publish runs on same tag. | Existing prerelease is updated in place and same-named assets are replaced. |
| A-010 | Core | VR-AST-001, VR-AST-004 | Build VIP and emit all required artifacts for `full` or `pr-fast` profile. | Publish prerelease and list release assets. | Assets include `.vip`, release-notes markdown, `labviewcli-logs` evidence, `vip-build-status` evidence, Linux container packed library (`.lvlibp`), Windows container packed library (`.lvlibp`), and `codex-skill-layer`. |
| A-011 | Core | VR-AST-002, VR-FAIL-003 | Remove one required asset before publish step. | Execute eligible publish run. | Publish fails with non-zero exit due to missing required asset. |
| A-012 | Core | VR-SEC-001, VR-SEC-002, VR-SEC-003 | Configure publish job permissions explicitly. | Execute publish API operations. | Job runs with `contents: write`, token values are not logged, and policy is repository-agnostic. |
| A-013 | Core | VR-PUB-003, VR-FAIL-002 | Simulate release API failure (bad token or forced API error). | Execute eligible publish run. | Publish job fails and workflow reports failure. |
| A-014 | Core | VR-TRIG-003, VR-FAIL-001, VR-PUB-005 | Execute ineligible run types (`pull_request`, non-develop push, manual false intent). | Run workflow and inspect outputs/status file. | Publish path is skipped without failure; outputs include `publish_status=skipped`. |
| A-015 | Full | VR-GOV-001, VR-GOV-002, VR-GOV-003, VR-GOV-004 | Load requirements, acceptance, and trace documents. | Cross-check changed/new VR IDs against acceptance and trace artifacts. | All changed/new VR IDs map to at least one acceptance scenario and at least one trace row. |
| A-016 | Core/Extended | VR-TRIG-011, VR-PUB-009, VR-AST-005, VR-AST-006, VR-FAIL-006 | Prepare release-priority `workflow_dispatch` publish-intent runs (`publish_prerelease=true`, `strict_sha=true`, `expected_sha=<merged develop SHA>`, `force_gcli_lunit=true`) with and without a successful `full` run on `develop` in the previous 24h. | Execute both runs and inspect `publish-gate` plus release assets/status. | Freshness-qualified run publishes Linux and Windows container packed-library assets plus `codex-skill-layer`; stale/no-freshness run does not create/update prerelease and reports gate/freshness failure reason. |
| A-017 | Extended | VR-OPS-007, VR-OPS-008, VR-OPS-009 | Configure `gh` auth for current repository and run local operations scripts. | Execute `Tooling/Test-CiBranchProtection.ps1` and `Tooling/Get-CiProfileRuntimeBaseline.ps1`. | Branch-protection verification report and ci-profile runtime baseline reports are generated under `TestResults/agent-logs` with explicit pass/mismatch or sample sufficiency indicators. |

## Evidence Records

| Scenario ID | Status | Commit | CI Run | Notes |
|---|---|---|---|---|
| A-001 | Pass | local | local | Revalidated on 2026-02-08 via `pwsh -NoProfile -File .\\Tooling\\Test-VipPrereleaseRequirementsV1.ps1`; VR ID uniqueness/ordering and shall-atomicity checks passed. |
| A-002 | Planned | N/A | N/A | Populate after first merged-PR-to-develop publish run. |
| A-003 | Planned | N/A | N/A | Populate after direct-push develop validation run. |
| A-004 | Planned | N/A | N/A | Populate after valid, false-intent, and invalid workflow_dispatch intent runs. |
| A-005 | Planned | N/A | N/A | Populate after merged PR label matrix validation. |
| A-006 | Planned | N/A | N/A | Populate after conflicting-label negative test. |
| A-007 | Planned | N/A | N/A | Populate after metadata verification run. |
| A-008 | Planned | N/A | N/A | Populate after prerelease body/flag validation run. |
| A-009 | Planned | N/A | N/A | Populate after rerun upsert validation. |
| A-010 | Planned | N/A | N/A | Populate after asset set verification run. |
| A-011 | Planned | N/A | N/A | Populate after required-asset failure test. |
| A-012 | Planned | N/A | N/A | Populate after permission contract validation run. |
| A-013 | Planned | N/A | N/A | Populate after forced API failure run. |
| A-014 | Planned | N/A | N/A | Populate after skip-path validation matrix. |
| A-015 | Pass | local | local | Revalidated on 2026-02-08 via `pwsh -NoProfile -File .\\Tooling\\Test-VipPrereleaseRequirementsV1.ps1`; acceptance/trace coverage and unknown-ID checks passed. |
| A-016 | Planned | N/A | N/A | Populate after release-priority freshness/gating matrix is exercised on real workflow runs. |
| A-017 | Pass | local | local | Revalidated on 2026-02-10 by running `Tooling/Test-CiBranchProtection.ps1` and `Tooling/Get-CiProfileRuntimeBaseline.ps1`; reports were generated under `TestResults/agent-logs`. |
