# Configuration Management Plan (ISO 10007 alignment)

Scope: LabVIEW Icon Editor community project CM practices mapped to ISO 10007 clauses 5.2–5.6. Applies to source, docs, tests, build artifacts, and release outputs governed in this repository.

## 5.2 CM planning and management
- Policy: All CM gates live in `docs/dod.md`; DoD Aggregator (`.github/workflows/dod-aggregator.yml`) must be green on PRs.
- Roles: Maintainers own approvals; Release Manager owns tags/releases; Automation QA owns RTM integrity and CM evidence.
- Baselines:
  - Product baselines: `lv_icon_editor.lvproj`, `resource/`, `vi.lib/` (checked-in LabVIEW code), `Test/`.
  - Requirements/test design baselines: `docs/requirements/rtm.csv` (with model_id/coverage_item_id/procedure_path), `docs/requirements/TRW_Verification_Checklist.*`, test models/specs/procedures under `docs/testing/models/`, `docs/testing/specs/`, `docs/testing/procedures/`, templates in `docs/testing/templates/`, status/completion/readiness logs in `reports/`.
  - Architecture/decision baseline: `docs/adr/adr-index.md`, `docs/adr/ADR-*.md`.
  - Release baseline: SemVer tags `vX.Y.Z` plus uploaded VIP/package artifacts via `.github/workflows/draft-release.yml` (draft) and attached test completion report.
- Change vehicles: pull requests; emergency fixes via hotfix branches (`hotfix/*`) with same gates.

## 5.3 Configuration identification
- Items uniquely identified by path + git commit; releases identified by SemVer tag (`vX.Y.Z`) and GitHub Release page.
- Traceability maintained in `docs/requirements/rtm.csv` (id → code_path/test_path), validated by `.github/scripts/validate_rtm.py`.
- ADRs indexed in `docs/adr/adr-index.md`; templates in `docs/adr/adr-template.md`.
- Workflows governing CM evidence: `docs-link-check.yml`, `rtm-validate.yml`, `rtm-coverage.yml`, `adr-lint.yml`, `dod-aggregator.yml`, `draft-release.yml`.

## 5.4 Configuration change control
- Entry: Proposed changes via PR with linked requirement/ADR; mandatory gates listed in `docs/dod.md`.
- Reviews: Maintainer approval required; breaking changes document rationale in ADRs.
- Automated controls:
  - RTM validation (`.github/scripts/validate_rtm.py`) blocks missing paths.
  - RTM coverage (`.github/scripts/check_rtm_coverage.py`) enforces ≥100% High/Critical, ≥75% overall test presence.
  - ADR lint (`.github/scripts/lint_requirements_language.py`) rejects vague language.
  - Docs link check via `lycheeverse/lychee-action@v1`.
- Emergency change: hotfix branch + expedited review; same gates must pass before merge/tag.

## 5.5 Configuration status accounting
- Status sources:
  - GitHub PR checks (DoD Aggregator summary, RTM, coverage, ADR lint, link check, unit tests).
  - RTM and test artifacts: `docs/requirements/rtm.csv`, `docs/requirements/TRW_Verification_Checklist.*`, test models/specs/procedures (`docs/testing/models/`, `docs/testing/specs/`, `docs/testing/procedures/`), readiness logs (`reports/test-data-readiness-*.md`, `reports/test-env-readiness-*.md`), execution logs, structured results (`reports/test-results-*.json`), and status/completion reports.
- Release records: GitHub Releases with VIP/package artifacts and notes (from `.github/workflows/draft-release.yml`), completion report attached.
- Reports:
  - DoD summary artifact (aggregated gate outcomes).
  - Test execution, readiness, and structured results artifacts attached by CI.
  - Lychee report artifact (`lychee/*.json`).
  - Release notes (`Tooling/deployment/release_notes.md`).

## 5.6 Configuration audit
- Functional/configuration audit prerequisites: DoD Aggregator must be green (valid RTM, coverage, ADR lint, link check); test readiness (data/env) and execution logs present.
- Physical audit: release tag `vX.Y.Z` must exist and match HEAD; artifacts uploaded via draft-release workflow including completion report and structured results.
- RTM/model/spec audits: run `.github/scripts/validate_rtm.py` and `.github/scripts/check_rtm_coverage.py` locally before PR; ensure RTM links to model_id, coverage_item_id, procedure_path; test models/specs/procedures present for touched RTM rows.
- ADR audit: ensure `docs/adr/adr-index.md` updated and ADRs pass lint.
- Release audit checklist (pre-release):
  - Completion report generated and attached.
  - Structured results, execution log, readiness reports (data/environment) attached.
  - RTM/model/spec/procedure links valid for changed requirements.
  - Release artifacts (.vip, release notes) aligned to computed version.

## Runbook (operational steps)
Local:
1) `python3 docs/requirements/sync_trw_csv_to_xlsx.py`
2) `python3 .github/scripts/validate_rtm.py`
3) `python3 .github/scripts/check_rtm_coverage.py`
4) `python3 .github/scripts/lint_requirements_language.py`
5) `pwsh -File scripts/unit-tests/unit_tests.ps1 -RepositoryPath \"$PWD\"`

CI/PR:
- DoD Aggregator / `dod-aggregator.yml` runs RTM validation, RTM coverage, ADR lint, docs link check; uploads DoD summary artifact.
- Dedicated gates also run: RTM validate (`rtm-validate.yml`), RTM coverage (`rtm-coverage.yml`), ADR lint (`adr-lint.yml`), Docs Link Check (`docs-link-check.yml`).

Release:
- Merge to release/*/main triggers CI; publish via `.github/workflows/draft-release.yml` to stage `vX.Y.Z` artifacts and release notes (draft). Verify completion report and test artifacts (structured results, readiness, execution log) before finalizing.

## References
- Definition of Done: `docs/dod.md`
- Traceability: `docs/requirements/rtm.csv`
- TRW checklist: `docs/requirements/TRW_Verification_Checklist.md`
- ADR index: `docs/adr/adr-index.md`
- Release workflow: `.github/workflows/draft-release.yml`


