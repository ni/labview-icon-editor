# ADR: Contributor License Agreement (CLA) Gate

- **ID**: ADR-2025-002  
- **Status**: Accepted  
- **Date**: 2025-11-23

## Context
We need a consistent, auditable way to ensure that contributors across many repositories have a valid Contributor License Agreement (CLA) on file before their changes can be merged. Here “CLA” always refers to the license agreement, not the “Certified LabVIEW Architect” credential. Today, CLA checks are ad hoc or repo-specific, which makes them hard to maintain, reason about, or reuse at scale. We also want a design that can be applied to hundreds of projects with minimal per-repo configuration, while remaining secure and easy to evolve. A portable org-level design is preferred over per-repo scripts so that policy changes are centralized and traceable.

## Options
- **A — Org-level manifest + reusable CLA gate workflow (chosen)**  
  A central `cla-manifest` repository stores CLA metadata, and a reusable `cla-gate` workflow in a shared automation repository enforces the gate on pull requests across all participating repos.
- **B — Per-repo CLA manifests and gate logic**  
  Each repository keeps its own manifest and CLA-check workflow, with similar logic duplicated across many repos.
- **C — Manual CLA checks only (no automated gate)**  
  CLA validation is done manually by reviewers or legal/compliance, without a CI-enforced gate.

## Decision
We adopt **Option A**: a manifest-driven, reusable `cla-gate` workflow that repositories can call via `workflow_call`. The gate **shall** be org-agnostic and read-only: it does not hardcode an organization, accepts inputs for `cla_manifest_repository` and `cla_manifest_file` plus a token, and never writes to the manifest. A manifest may be scoped per org or per repository; policy drift across manifests is acceptable, and the gate simply enforces the manifest it is pointed to. A manifest repository (org-wide or repo-specific) **shall** be the source of truth for CLA status for the scope it serves, and the shared `cla-automation` (or equivalent) repository **shall** host the reusable CLA gate workflow and associated validation scripts. Individual repositories, including this one, **shall** integrate the gate by adding a small workflow that invokes `cla-gate` on pull requests into protected branches and by requiring the `cla-gate` check to pass via branch protection rules. The gate **shall** fail closed when it cannot retrieve or validate the manifest.

## Requirements
- **CLA-001**: The organization **shall** maintain a single `cla-manifest` repository as the authoritative source of CLA status, with each record including at minimum: `github`, `cla_type`, `cla_version`, `signed_on`, `status` (e.g., active/superseded/inactive), and an `evidence_ref`.  
- **CLA-002**: The reusable `cla-gate` workflow **shall** validate pull requests by checking the PR author and all non-bot commit authors against the manifest; any missing or non-active entry **shall** cause the check to fail with a clear diagnostic.  
- **CLA-003**: Repositories adopting the org-level CLA policy **shall** invoke the `cla-gate` workflow on pull requests targeting protected branches (for example, `main`, `develop`, `release/*`, and `feature/*`).  
- **CLA-004**: Branch protection rules for protected branches **shall** require the `cla-gate` status check to pass before merges are allowed.  
- **CLA-005**: The `cla-manifest` and CLA automation repositories **shall** be protected with CODEOWNERS and branch protection rules to prevent unauthorized or unreviewed changes to CLA policy or data.  
- **CLA-006**: The reusable `cla-gate` workflow **shall not hardcode** an organization; it **shall** accept inputs `cla_manifest_repository` and `cla_manifest_file`, and use a provided token with minimal required scopes to read the manifest.  
- **CLA-007**: The CLA manifest scope **may** be per organization or per repository; the gate **shall** enforce whichever manifest it is configured to use, and policy drift across scopes is acceptable.  
- **CLA-008**: The `cla-gate` workflow **shall surface** in its output which `cla_manifest_repository` and `cla_manifest_file` were used and list any PR author or commit authors that failed the check.  
- **CLA-009**: The `cla-gate` workflow **shall support** forked PRs by allowing a read-only manifest mode (when no token is provided) for public manifests, and **shall fail closed** on protected branches when manifest access fails.  
- **CLA-010**: Documentation **shall** provide a minimal fork-friendly workflow snippet showing how to set `cla_manifest_repository`/`cla_manifest_file` inputs so forks can reuse the upstream manifest without hardcoded org names.  
- **CLA-011**: The `cla-gate` workflow **shall treat** the manifest as read-only, never attempting to write or update manifest data, and **shall** use a minimal-scope token (e.g., contents:read) when a token is provided.  
- **CLA-012**: Manifest changes **shall** be validated in CI against a JSON schema; schema or required-field violations **shall** fail the change.  
- **CLA-013**: Repositories consuming `cla-gate` **shall** pin the workflow to a tagged version (e.g., `@v1`) rather than `@main` to avoid drift.  
- **CLA-014**: Manifest updates **shall** include an audit note (who/why, CLA version) and be merged via PR with required reviewers; direct pushes to manifest branches are not allowed.  
- **CLA-015**: `cla-gate` **shall** run with a read-only token from a minimal-scope credential (e.g., GitHub App) when a token is required; PATs are disallowed unless explicitly approved.  
- **CLA-016**: If the manifest is public and no token is provided, `cla-gate` **may** read anonymously; if access fails, it **shall** fail closed on protected branches with a clear diagnostic.  
- **CLA-017**: `cla-gate` **shall** evaluate all non-bot commit authors and Co-authored-by trailers; failures **shall** list which identities lack an active CLA entry.  
- **CLA-018**: Documentation **shall** include mainline and forked workflow snippets and sample gate output (manifest source, failing handles), plus a short FAQ for troubleshooting CLA failures.  
- **CLA-019**: Protected branches (e.g., `main`, `develop`, `release/*`, `feature/*`) **shall** require the `cla-gate` status check via branch protection or rulesets.  
- **CLA-020**: The manifest **shall** document how to handle GitHub handle changes/merges; superseded handles **shall** be marked inactive when a new handle replaces them.  
- **CLA-021**: The manifest **shall declare** a schema version; `cla-gate` **shall** enforce compatibility and fail closed on unknown/unsupported versions.  
- **CLA-022**: `cla-gate` **shall** explicitly exempt only known bot accounts; all other non-human authors **shall** require CLA validation.  
- **CLA-023**: `cla-gate` **shall complete** within a defined timeout (e.g., <60s per run) and fail closed with a clear diagnostic if the timeout is exceeded.  
- **CLA-024**: If manifest data is cached, a maximum TTL **shall** be defined; caches **shall** be refreshed per PR/run to avoid stale decisions.  
- **CLA-025**: Manifest integrity **shall** be protected (e.g., checksum or signature); `cla-gate` **shall** verify integrity before use when provided.  
- **CLA-026**: `evidence_ref` targets **shall** follow retention/location guidance and **shall not** include PII/secrets in the manifest; storage location **shall** be documented.  
- **CLA-027**: Handle/email mapping rules **shall** be documented; when commit emails do not map to GH handles, the mapping **shall** be applied before CLA evaluation.  
- **CLA-028**: `cla-gate` **should emit** metrics (e.g., failures by reason) and support alerting when missing-CLA failures exceed a threshold.  
- **CLA-029**: `cla-gate` **should implement** retry/backoff and request caps to the manifest source to guard against DoS; on limit exceed, it fails closed with a clear diagnostic.  
- **CLA-030**: Failure messaging **should** use a standard auto-comment with intake/docs links and a concise template across repos.  
- **CLA-031**: `cla-gate` **should target** an availability SLO; if the manifest source is down, it fails closed and notifies maintainers per documented procedure.  
- **CLA-032**: `cla-gate` **may provide** a dry-run/smoke mode for onboarding (report-only), disabled on protected branches by default.  
- **CLA-033**: `cla-gate` **may optionally verify** that `evidence_ref` locations are reachable (without exposing contents) and warn if not.  
- **CLA-034**: Logs and outputs **should** be retained per policy and **shall not** include PII/secrets from the manifest or evidence refs; redaction rules **shall** be documented.  

## Consequences
- **+** CLA policy becomes consistent and enforceable across all participating repositories, with a single manifest and one implementation of gate logic to maintain.  
- **+** Portable across orgs and forks because the gate is input-driven (manifest repo/path) and does not hardcode an organization.  
- **+** Compliance, security, and legal teams can audit and update CLA status in one place without per-repo changes.  
- **+** Projects can opt in with minimal configuration (a short workflow that calls the reusable gate and a branch protection rule).  
- **–** There is upfront work to create and secure manifest and automation repositories (org-wide or per-repo) and to migrate existing CLA logic.  
- **–** The CLA gate introduces a hard dependency on the manifest and automation repos being available; failures there **shall block** merges until resolved (by design).  
- **–** Fork PRs and private manifests require careful token handling (read-only token or public manifest); missing access **shall** cause the gate to fail closed on protected branches.  
- **–** Maintaining multiple manifests (per-org or per-repo) can increase audit overhead and drift; each manifest **shall** still be protected (CODEOWNERS + branch protection) to limit risk.  

## Follow-ups
- [ ] Create an org-level `cla-manifest` repository with a documented JSON schema, governance rules, and CI validation.  
- [ ] Create an org-level `cla-automation` (or similar) repository exposing a reusable `cla-gate` workflow via `workflow_call`, plus a validator script.  
- [ ] Update this repository to replace local CLA checks with a call to `cla-gate` and protect `develop/main/release/*/feature/*` branches with the `cla-gate` status check.  
- [ ] Document the CLA intake process (issue template + manifest update PR) at the org level and link to it from this repo’s contributor docs.
- [ ] Add documentation snippets for fork-friendly `cla-gate` usage that set `cla_manifest_repository`/`cla_manifest_file` inputs without hardcoding an org, and explain token requirements for public vs. private manifests.
- [ ] Add an example `cla-gate` caller workflow (mainline) and a fork variant showing manifest inputs and expected output fields (manifest source, failing handles).

> Traceability: CLA-001–CLA-034 in `docs/requirements/requirements.csv`, CI tests for the reusable `cla-gate` workflow, and branch protection rules that require `cla-gate` on protected branches.
