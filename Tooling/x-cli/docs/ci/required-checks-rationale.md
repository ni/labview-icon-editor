# Required Checks — Rationale and Guidance

This document explains why each required GitHub status check exists, what risk it mitigates, and how to remediate failures. It complements the live reference in `docs/ci/branch-protection.md` and the source‑of‑truth config in `docs/settings/branch-protection.expected.json`.

## Classic Protection (main)

**Pre-Commit / run**
- Purpose: Enforces formatting and lint hygiene consistently across languages before merge.
- Risk mitigated: Style drift, trivial CI breakages, and inconsistent tooling configurations.
- Typical failures: Formatting, import/order, basic lint violations.
- Remediation: Run `pre-commit run --all-files` locally or fix issues reported by the workflow.

**SRS Gate / SRS Compliance + Smoke**
- Purpose: Validates that SRS artifacts and required metadata conform to the repository’s specification baseline and passes basic smoke checks.
- Risk mitigated: Spec drift and broken minimum viability of SRS deliverables.
- Typical failures: Missing/invalid SRS headers, spec version mismatches, smoke test breaks.
- Remediation: Align docs under `docs/srs/` with `docs/SRS.md` and fix reported violations.

**SRS Gate / SRS Scripts - Unit Tests**
- Purpose: Ensures the SRS/traceability Python tooling is reliable via unit tests.
- Risk mitigated: Regressions in scripts that generate or validate compliance artifacts.
- Typical failures: Broken Python unit tests, contract changes not reflected in tests.
- Remediation: Update tests and implementation under `tests/__ci__` and related scripts.

**SRS Gate / Traceability (RTM) Verify**
- Purpose: Verifies the Requirements Traceability Matrix can be generated and is internally consistent.
- Risk mitigated: Loss of traceability between SRS items and tests, undermining auditability.
- Typical failures: Orphaned requirements/tests, invalid IDs, or broken RTM generation.
- Remediation: Fix mapping in `docs/module-srs-map.yaml`, SRS docs under `docs/srs/`, or affected tests.

**Tests Gate / Python Tests (serial)**
- Purpose: Executes Python test suites serially to avoid cross‑test interference.
- Risk mitigated: Flaky or order‑dependent tests hiding real defects.
- Typical failures: Test assertions, environment assumptions, path hygiene issues.
- Remediation: Fix tests under `tests/` and prefer stable, isolated fixtures.

**Tests Gate / Python Tests (parallel)**
- Purpose: Validates the suite is concurrency‑safe when executed in parallel.
- Risk mitigated: Hidden race conditions and shared state coupling in tests or code.
- Typical failures: Global state collisions, tempfile clashes, nondeterministic failures.
- Remediation: Remove shared state, randomize or isolate resources, honor temp dirs and fixtures.

**PR Coverage Gate / coverage**
- Purpose: Enforces configured line/branch coverage thresholds at the PR boundary.
- Risk mitigated: Quality regression by code entering without adequate tests.
- Typical failures: Overall or per‑file coverage drops below thresholds.
- Remediation: Add tests; see thresholds in `docs/compliance/coverage-thresholds.json` and guidance in `docs/coverage.md`.

**Docs Gate / Canonical Sources**
- Purpose: Ensures documentation derived from canonical sources/templates is up‑to‑date and consistent.
- Risk mitigated: Documentation drift, broken generated docs, or stale canonical indexes.
- Typical failures: Out‑of‑date generated docs, missing indices, or template sync errors.
- Remediation: Regenerate docs from `docs/templates/` and fix issues in sources or generation scripts.

**DoD Gate / dod**
- Purpose: Aggregates Definition‑of‑Done checks (labels, metadata, artifacts) before merge.
- Risk mitigated: Incomplete deliverables or missing review/validation evidence.
- Typical failures: Unmet DoD checklist items or missing artifacts/labels.
- Remediation: Follow `QA-CHECKLIST.md` and compliance guides under `docs/compliance/`.

**YAML Lint / lint**
- Purpose: Validates YAML across workflows and configs.
- Risk mitigated: CI breakages due to malformed YAML or schema issues.
- Typical failures: Indentation, invalid keys, or schema errors.
- Remediation: Correct YAML in `.github/workflows/` and other YAML files; re‑run lint.

## Rulesets (in addition to Classic)

These checks come from GitHub Rulesets and apply by pattern.

**main ruleset → coverage**
- Purpose: Ensures a successful coverage aggregation job on protected branches.
- Risk mitigated: Silent failures in the coverage pipeline that would mask gating data.
- Typical failures: Coverage job infra errors or report generation failures.
- Remediation: Repair the coverage workflow and report publish step.

**main ruleset → lychee**
- Purpose: Runs Markdown link + anchor checks using lychee, catching broken references.
- Risk mitigated: Broken documentation links and anchors.
- Typical failures: Dead external links, bad relative paths, missing anchors.
- Remediation: Update links or suppress known‑good exceptions via `.lychee.toml`; see `scripts/docs-link-check.ps1`.

**features-yaml-lint ruleset → YAML Lint / lint**
- Purpose: Applies a lightweight lint gate to feature branches (`feat/*`, `feature/*`).
- Risk mitigated: Early YAML errors without running the full pipeline on short‑lived branches.
- Typical failures: Same as YAML lint above.
- Remediation: Fix YAML; push again.

## Source of Truth and Verification
- Configuration: `docs/settings/branch-protection.expected.json`
- Reference: `docs/ci/branch-protection.md`
- Guard test: `scripts/tests/BranchProtection.Tests.ps1` (compares expectations vs. live settings)
- Live inspection: `scripts/ghops/tools/branch-protection-awareness.ps1`

## Change Process
- Update checks in GitHub (Settings → Branches/Rulesets).
- Refresh expectations in `docs/settings/branch-protection.expected.json` (patterns and check names).
- Validate locally: `pwsh -NoProfile -File scripts/tests/BranchProtection.Tests.ps1` or `pwsh ./scripts/qa.ps1`.

