# VI Package Develop Pre-Release Requirements v1.0 Acceptance Matrix

This matrix defines executable acceptance scenarios for `docs/vip-prerelease-requirements.md`.

| Scenario ID | Scope/Profile | Target VR IDs | Setup | Execution | Pass Criteria |
|---|---|---|---|---|---|
| A-001 | Core | VR-SCOPE-001, VR-SCOPE-002, VR-SCOPE-003, VR-SCOPE-004, VR-PUR-001, VR-PUR-002, VR-PUR-003, VR-PUR-004, VR-PUR-005, VR-PUR-006 | Load requirements document. | Parse `VR-` requirement IDs and normative statements. | IDs are unique and monotonic within each VR family; each `shall` statement is independently testable. |
| A-002 | Core | VR-TRIG-001, VR-TRIG-006 | Push merge commit to `develop` associated with merged PR targeting `develop`. | Run `ci-composite.yml`. | Publish context marks run eligible with reason output indicating auto merged-PR path. |
| A-003 | Core | VR-TRIG-002, VR-FAIL-001 | Push direct commit to `develop` without merged PR association. | Run `ci-composite.yml`. | Publish job reports `publish_status=skipped` and workflow remains successful. |
| A-004 | Extended | VR-TRIG-004, VR-TRIG-005, VR-OPS-001, VR-OPS-002, VR-OPS-003, VR-OPS-004 | Dispatch workflow manually with `publish_prerelease=true` and then with `publish_prerelease=false`. | Compare publish job behavior across both runs. | Publish occurs only when input is `true`; `false` run is skipped; SHA pinning contract is enforced for manual publish intent. |
| A-005 | Core | VR-VER-002, VR-VER-004, VR-VER-005, VR-VER-006 | Use merged PR labels on develop merge (`major`, `minor`, `patch`, none). | Execute version computation in eligible publish runs. | Bump type follows merged PR labels, with default `patch` when no release label exists; override interface behavior is valid. |
| A-006 | Core | VR-VER-003, VR-FAIL-004 | Apply conflicting merged PR release labels (for example `major` and `minor`). | Execute eligible develop publish run. | Version resolution fails with non-zero exit and explicit conflict error. |
| A-007 | Core | VR-VER-001 | Prepare run with known computed `VERSION` output. | Publish prerelease and inspect release metadata. | Release tag and title equal `needs.version.outputs.VERSION` exactly. |
| A-008 | Core | VR-PUB-001, VR-PUB-002, VR-PUB-006, VR-PUB-007 | Prepare release notes file and eligible publish run. | Publish prerelease and inspect release flags/body and status artifact. | Release is `prerelease=true`, `draft=false`, body matches generated release notes content, and publish status file/artifact are emitted. |
| A-009 | Core | VR-PUB-004, VR-AST-003 | Re-run publish for same computed version tag. | Execute two publish runs on same tag. | Existing prerelease is updated in place and same-named assets are replaced. |
| A-010 | Core | VR-AST-001, VR-AST-004 | Build VIP and emit all required artifacts. | Publish prerelease and list release assets. | Assets include `.vip`, release-notes markdown, `gcli-logs` evidence, and `vip-build-status` evidence. |
| A-011 | Core | VR-AST-002, VR-FAIL-003 | Remove one required asset before publish step. | Execute eligible publish run. | Publish fails with non-zero exit due to missing required asset. |
| A-012 | Core | VR-SEC-001, VR-SEC-002, VR-SEC-003 | Configure publish job permissions explicitly. | Execute publish API operations. | Job runs with `contents: write`, token values are not logged, and policy is repository-agnostic. |
| A-013 | Core | VR-PUB-003, VR-FAIL-002 | Simulate release API failure (bad token or forced API error). | Execute eligible publish run. | Publish job fails and workflow reports failure. |
| A-014 | Core | VR-TRIG-003, VR-FAIL-001, VR-PUB-005 | Execute ineligible run types (`pull_request`, non-develop push, manual false intent). | Run workflow and inspect outputs/status file. | Publish path is skipped without failure; outputs include `publish_status=skipped`. |
| A-015 | Full | VR-GOV-001, VR-GOV-002, VR-GOV-003, VR-GOV-004 | Load requirements, acceptance, and trace documents. | Cross-check changed/new VR IDs against acceptance and trace artifacts. | All changed/new VR IDs map to at least one acceptance scenario and at least one trace row. |

## Evidence Records

| Scenario ID | Status | Commit | CI Run | Notes |
|---|---|---|---|---|
| A-001 | Pass | local | local | Revalidated on 2026-02-08 via `pwsh -NoProfile -File .\\Tooling\\Test-VipPrereleaseRequirementsV1.ps1`; VR ID uniqueness/ordering and shall-atomicity checks passed. |
| A-002 | Planned | N/A | N/A | Populate after first merged-PR-to-develop publish run. |
| A-003 | Planned | N/A | N/A | Populate after direct-push develop validation run. |
| A-004 | Planned | N/A | N/A | Populate after two workflow_dispatch intent runs. |
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
