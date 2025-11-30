# Workflows Inventory — x-cli

This document inventories each workflow under `.github/workflows/`, the purpose it serves, and whether we keep or remove it. The goal is to reduce hidden tech-debt and remove hard‑to‑justify jobs. We intentionally accept short‑term CI breakage to rebuild a minimal, well‑rationalized pipeline.

Legend: Keep = retained; Remove = deleted in this change.

See also: `docs/ci/workflows-rationale.md` for per‑workflow rationale and triggers.

## Core Build/Test/Release (Keep)
- build.yml — Main .NET build/test matrix.
- stage1-telemetry.yml — Stage 1 telemetry emission required by pipeline.
- stage2.yml — Ubuntu build/tests + artifacts.
- stage3.yml — Windows validation/tests consuming Stage 2 artifacts.
- stage2-3-ci.yml — Combined Stage 2/3 orchestration.
- build-release-assets.yml — Cross‑publish single‑file artifacts.
- publish-container.yml — Build/publish container images to GHCR.
- release.yml — Release publish flow; release‑dryrun.yml — dry‑run checks.
- create-tag.yml — Tagging utility for versioning.
- telemetry-aggregate.yml — Aggregates QA/CI telemetry.

## Quality Gates (Keep)
- pre-commit.yml — Runs repository pre‑commit hooks in CI.
- tests-gate.yml — Test gate; coverage-gate.yml — coverage thresholds.
- yaml-lint.yml — YAML lint; docs-gate.yml — docs link checks.
- bootstrap-check.yml — Runs agent bootstrap dry-run to ensure remotes/branches/secrets before workflow edits.
- srs-gate.yml — SRS compliance gate; srs-maintenance.yml — SRS upkeep.
- design-lock.yml — Design/spec lock to prevent drift.
- adr-lint.yml — ADR lint to keep architecture notes consistent.
- md-templates.yml — Markdown templates preview (non-blocking).
- md-templates-sessions.yml — Scheduled markdown template runs with domain contexts.

Badges:

[![Markdown Templates Preview](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates.yml/badge.svg)](../.github/workflows/md-templates.yml)
[![Markdown Templates Sessions](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates-sessions.yml/badge.svg)](../.github/workflows/md-templates-sessions.yml)

Job summaries surface “Effective thresholds: TopN, MinCount” based on repo variables `MD_TEMPLATES_TOPN` (default 10) and `MD_TEMPLATES_MINCOUNT` (default 1).

## Removed (low value or overlapping scope)
- 29148-bootstrap.yml — Obsolete bootstrapping; SRS gate/maintenance cover this. (Remove)
- codex-2way.yml, codex-execute.yml, codex-mirror-sign.yml, codex-orchestrator.yml, codex-reviewer.yml — Codex‑specific orchestration not required for x‑cli core. (Remove)
- dispatch-codex.yml, kickstart-codex-dev-loop.yml — Codex dispatch/dev loop; out of scope. (Remove)
- legacy validator gates (removed) — Integration not needed in minimal pipeline. (Remove)
- kv-runner-image.yml — Runner image build; maintain separately when needed. (Remove)
- discord-canary.yml — Canary notifications to Discord; optional. (Remove)
- validate-waterfall-state.yml, waterfall-advance.yml, waterfall-stuck-alert.yml — Waterfall process automation; not essential to x‑cli. (Remove)
- trigger-codex-orchestration.yml — External orchestration trigger; redundant. (Remove)
- dod-gate.yml — Separate DoD gate; overlaps with tests/coverage/docs gates. (Remove)
- enforce-codex-authorship.yml — Authorship policy not required for current flow. (Remove)

Notes
- We will re‑introduce targeted automation as concrete needs arise, with explicit SRS mapping and tests.
- If any removed workflow proves necessary, re‑add with a brief rationale and SRS/ADR references.

## Ownership Matrix (Re‑Add Criteria)

| Area | Primary | Backup | Success Metrics | Re‑Add Criteria | Notes |
| --- | --- | --- | --- | --- | --- |
| Build/Test/Release (build.yml, build‑release‑assets.yml, publish‑container.yml, release*.yml, create‑tag.yml) | Release (@team-release) | QA (@team-qa) | Artifacts built (linux‑x64, win‑x64) with checksums; `--help` smoke passes; job < 10m | Needed to produce versioned artifacts; SRS mapped; smoke required | Keep minimal; re‑add only on concrete release need |
| Staged CI (stage1‑telemetry.yml, stage2*.yml, stage3.yml) | DevOps (@team-devops) | QA (@team-qa) | Stage 2 publishes dist/x-cli-win-x64 + telemetry/manifest.json + summary; Stage 3 validates hashes and smokes `--help` | Re‑add gating only when Stage 2/3 split is necessary | Prefer a single gate unless strict staging adds value |
| Quality Gates (pre‑commit.yml, tests‑gate.yml, coverage‑gate.yml, yaml‑lint.yml, docs‑gate.yml, srs‑gate.yml, srs‑maintenance.yml, design‑lock.yml, adr‑lint.yml) | QA (@team-qa) | DevEx (@team-devex) | 0 lint errors; tests PASS; coverage ≥ policy; SRS lint OK; docs links OK | Enforce measurable acceptance | Consolidate where possible to reduce job count |
| Telemetry (telemetry‑aggregate.yml) | QA (@team-qa) | DevOps (@team-devops) | summary.json exists; diffs produced or baseline established; artifacts uploaded | Re‑add when telemetry is actively consumed by stakeholders | Optional until dashboards/reporting rely on it |
| Legacy Orchestration (removed group) | DevEx (@team-devex) | QA (@team-qa) | If re‑added: workflows complete < 10m; produce actionable PR feedback; SRS + tests included | Only if external orchestration returns with SRS + tests | Keep removed to reduce surface |
| Waterfall/Canary/Runner (removed group) | DevOps (@team-devops) | Infra (@team-infra) | If re‑added: labels/states correct; alerts actionable; < 2% false positives; job < 5m | Only if process governance or custom runners are reinstated | Re‑introduce with named owner + success criteria |
