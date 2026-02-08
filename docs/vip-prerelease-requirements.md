# VI Package Develop Pre-Release Requirements v1.0

**Document Control**

| Field | Value |
|---|---|
| Document ID | LVIE-VPR-REQ-v1 |
| Semantic Revision | v1.0 |
| Product | CI Pipeline (Composite) pre-release publication |
| Scope | develop prerelease publication |
| Status | Draft v1.0 |

## Scope Expansion Model (Normative)

Profiles:
- `Core`: mandatory behavior for eligibility, version, publish, and asset contracts.
- `Extended`: adds manual backfill and operational controls.
- `Full`: adds governance and revision controls.

Profile rule:
- Full conformance implies Extended conformance.
- Extended conformance implies Core conformance.

## Requirement ID Families (Normative)

- `VR-SCOPE`: profile and applicability rules.
- `VR-PUR`: purpose and non-goal boundaries.
- `VR-TRIG`: event eligibility and trigger gating.
- `VR-VER`: version and bump derivation rules.
- `VR-PUB`: release creation/update contract.
- `VR-AST`: release asset contract.
- `VR-OPS`: manual backfill and operations.
- `VR-SEC`: permissions and secret handling.
- `VR-FAIL`: failure and skip semantics.
- `VR-GOV`: governance and traceability.

## 1. Scope and Purpose

VR-SCOPE-001: Requirements in this document shall be grouped into Core, Extended, and Full profiles.
VR-SCOPE-002: Full conformance shall require satisfaction of all applicable mandatory requirements in Extended and Core profiles.
VR-SCOPE-003: Extended conformance shall require satisfaction of all applicable mandatory requirements in Core profile requirements.
VR-SCOPE-004: Requirements using should or may are non-blocking for conformance claims.

VR-PUR-001: The CI pipeline shall publish a GitHub prerelease for eligible develop publication events.
VR-PUR-002: Publication behavior shall use artifacts produced by the same CI run.
VR-PUR-003: The workflow contract shall expose machine-readable publish status outputs.
VR-PUR-004: Stable or final release publication on `main` shall be out of scope for this document.
VR-PUR-005: Legacy alpha/beta/rc channel governance shall be out of scope for this document.
VR-PUR-006: This document shall be the normative contract for develop prerelease publication behavior.

## 2. Trigger and Eligibility (Core)

VR-TRIG-001: Eligible auto-publish events shall be `push` events on `refs/heads/develop` where `github.sha` is associated with a merged pull request targeting `develop`.
VR-TRIG-002: Direct pushes to `develop` without merged pull-request association shall skip prerelease publication.
VR-TRIG-003: `pull_request` events shall never publish prereleases.
VR-TRIG-004: `workflow_dispatch` runs shall publish only when the boolean input `publish_prerelease` is `true`.
VR-TRIG-005: `workflow_dispatch` runs with `publish_prerelease` not equal to `true` shall skip prerelease publication.
VR-TRIG-006: Trigger evaluation shall emit publish intent and reason outputs for downstream jobs.

## 3. Version and Bump Contract (Core)

VR-VER-001: Release `tag_name` and release title shall equal `needs.version.outputs.VERSION` exactly.
VR-VER-002: Eligible develop publish runs shall derive bump type from merged pull-request labels `major`, `minor`, or `patch`, defaulting to `patch` when none are present.
VR-VER-003: Conflicting merged pull-request release labels shall fail version resolution.
VR-VER-004: The compute-version interface shall support optional `bump_type_override` input values `major`, `minor`, `patch`, or `none`.
VR-VER-005: When `bump_type_override` is provided, compute-version shall use it instead of event-derived bump type.
VR-VER-006: Manual backfill runs without merged pull-request association may use `none` bump override.

## 4. Publish Contract (Core)

VR-PUB-001: Eligible publish runs shall create or update a GitHub release with `prerelease=true` and `draft=false`.
VR-PUB-002: Release body content shall be sourced from generated `Tooling/deployment/release_notes.md`.
VR-PUB-003: Publish failures on eligible runs shall fail the workflow.
VR-PUB-004: Reruns for an existing release tag shall update the existing prerelease rather than create a second prerelease.
VR-PUB-005: Publish job outputs shall include `release_tag`, `release_url`, `release_id`, and `publish_status`.
VR-PUB-006: Publish job status shall be written to `builds/status/prerelease-publish.json`.
VR-PUB-007: The status file in VR-PUB-006 shall be uploaded as artifact `prerelease-publish-status`.

## 5. Asset Contract (Core)

VR-AST-001: Required prerelease assets shall include the built `.vip`, versioned release-notes markdown file, `gcli-logs`, and `vip-build-status` evidence.
VR-AST-002: Missing required assets shall fail eligible publish runs.
VR-AST-003: Reruns shall replace same-named assets on the existing prerelease.
VR-AST-004: Build-vip job outputs shall expose at least VIP artifact name and release-notes artifact name for publish job consumption.

## 6. Operations and Manual Backfill (Extended)

VR-OPS-001: Manual backfill shall be available through `workflow_dispatch` with explicit publish intent input `publish_prerelease=true`.
VR-OPS-002: Manual backfill shall pin and validate the target SHA using `expected_sha` contract checks.
VR-OPS-003: Manual backfill publication shall reuse Core upsert and asset replacement rules.
VR-OPS-004: Manual backfill shall emit publish status outputs even when publication is skipped.

## 7. Security and Permissions (Core)

VR-SEC-001: Publish jobs shall request `contents: write` permission.
VR-SEC-002: Publish jobs shall not log GitHub token values to stdout or stderr.
VR-SEC-003: Publish behavior shall be repository-agnostic without requiring canonical owner checks.

## 8. Failure Semantics (Core)

VR-FAIL-001: Ineligible publish paths shall complete with `publish_status=skipped` without failing the workflow.
VR-FAIL-002: Eligible publish API failures shall terminate publish job execution with a non-zero exit code.
VR-FAIL-003: Required asset validation failures shall terminate publish job execution with a non-zero exit code.
VR-FAIL-004: Label-conflict failures in bump derivation shall terminate version resolution with a non-zero exit code.

## 9. Governance and Traceability (Full)

VR-GOV-001: Requirement changes shall be classified as Breaking, Clarifying, or Editorial.
VR-GOV-002: Breaking changes shall include migration notes.
VR-GOV-003: Each released revision shall include acceptance and trace artifacts.
VR-GOV-004: All changed or new VR IDs shall map to at least one acceptance scenario.

## 10. Public Interface Summary (Normative)

- `ci-composite.yml` dispatch input `publish_prerelease` (boolean, default `false`).
- `.github/actions/compute-version/action.yml` input `bump_type_override` (optional).
- `build-vip` job outputs for VIP and release-notes artifact identifiers.
- `publish-prerelease` job outputs: `release_tag`, `release_url`, `release_id`, `publish_status`.
- Status artifact: `prerelease-publish-status` containing `builds/status/prerelease-publish.json`.
