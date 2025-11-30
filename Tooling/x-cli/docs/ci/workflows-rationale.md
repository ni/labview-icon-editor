# CI Workflows — Rationale (Non‑Required Checks)

This catalog documents all GitHub Actions workflows under `.github/workflows/` that are not covered by `docs/ci/required-checks-rationale.md`.

For a high‑level keep/remove inventory, see `docs/workflows-inventory.md`. For the checks that gate merges or rulesets, see `docs/ci/required-checks-rationale.md`.

## Scope
- Excludes required‑checks workflows: `pre-commit.yml`, `srs-gate.yml`, `tests-gate.yml`, `coverage-gate.yml`, `docs-gate.yml`, `yaml-lint.yml`.
- Includes build/release, security, tooling, and GitHub‑ops workflows that provide value but do not gate merges by default.

## Build, Test, Release
- `build.yml`
  - Purpose: Cross‑OS build/test, publish single‑file artifacts, and smoke `--help` on Linux/Windows for `develop`, `feature/*`, `release/*`, `hotfix/*`.
  - Triggers: push/pull_request; workflow_dispatch.
  - Artifacts: `dist/x-cli-linux-x64`, `dist/x-cli-win-x64`, notifications report.
  - Notes: Verifies module index generation on Linux.

- `build-cli.yml`
  - Purpose: Reusable build/pack workflow that emits a `cli_version` and a `.nupkg` artifact.
  - Triggers: `workflow_call` with optional `cli_version` input.
  - Artifacts: `cli-package/*.nupkg`.

- `build-release-assets.yml`
  - Purpose: Build release‑grade artifacts (single‑file binaries) and upload as artifacts; often reused/triggered by release processes.
  - Triggers: varies (see file); intended for release lines.
  - Artifacts: platform‑specific binaries.

- `publish-container.yml`
  - Purpose: Build and publish container images to GHCR using the packaged CLI; includes SBOM generation and smoke tests.
  - Triggers: push on `v*` tags; workflow_dispatch with `version` and `push_latest`.
  - Artifacts: SBOM (`sbom-<version>.spdx.json`); container pushed to `ghcr.io`.

- `release.yml`
  - Purpose: Full release pipeline − coverage, artifacts, and publishing.
  - Triggers: tag or manual; orchestrates packaging and publication.

- `release-dryrun.yml`
  - Purpose: Safe dry‑run of release steps (coverage aggregation, binaries, summaries) without publishing.
  - Triggers: workflow_dispatch with `version`.
  - Artifacts: coverage reports, HTML summary, published binaries in `artifacts/release/**`.

- `create-tag.yml`
  - Purpose: UI‑driven SemVer tag creation on the current commit.
  - Triggers: workflow_dispatch with `version` input.

## Staged CI & Telemetry
- `stage1-telemetry.yml`
  - Purpose: Produce and validate telemetry summary, upload artifacts, and optionally validate JSON schemas; runs a subset of telemetry tests.
  - Triggers: workflow_call, workflow_dispatch.
  - Artifacts: `.codex/telemetry.json`, `telemetry/summary.json`, telemetry TRX.

- `stage2.yml`
  - Purpose: Build/test and publish normalized single‑file artifacts (linux/win) with smoke tests; may consume Stage 1 outputs.
  - Triggers: workflow_call, workflow_run, workflow_dispatch (see file).
  - Artifacts: `dist/x-cli-linux-x64`, `dist/x-cli-win-x64` and test results.

- `stage3.yml`
  - Purpose: Windows‑centric validation using Stage 2 artifacts (hashes, smokes), ensuring cross‑OS parity.
  - Triggers: workflow_call/workflow_run as configured.

- `stage2-3-ci.yml`
  - Purpose: Convenience orchestration that runs Stage 2 and Stage 3 together in CI.

- `telemetry-aggregate.yml`
  - Purpose: Aggregate CI/QA telemetry, produce summaries/diffs for dashboards.
  - Artifacts: `telemetry/summary.json`, diff outputs.

- `telemetry-tests.yml`
  - Purpose: Run only the telemetry‑focused .NET tests across OS matrix and upload TRX.
  - Triggers: push/pull_request (see file).

## Security & Code Quality
- `codeql.yml`
  - Purpose: Static analysis via GitHub CodeQL for JavaScript/TypeScript and Python.
  - Triggers: push/pull_request on `main`/`develop`, weekly cron.
  - Behavior: Non‑blocking on PRs (soft analyze) but writes security events on push/cron.

- `design-lock.yml`
  - Purpose: Prevent unauthorized drift in key design/spec artifacts (policy/lint rules defined in repo).

- `adr-lint.yml`
  - Purpose: Lint Architecture Decision Records under `docs/adr/**`.
  - Triggers: pull_request touching ADRs.

- `diagnostics-lint.yml`
  - Purpose: Lint diagnostics and related scripts/config for consistency.

- `labels-sync.yml`
  - Purpose: Sync repository labels to a canonical set.

- `onboarding-check.yml`
  - Purpose: Validate onboarding prerequisites (secrets, permissions, branch defaults) for new contributors or repo bootstraps.

- `srs-maintenance.yml`
  - Purpose: Deterministic regeneration of SRS artifacts (index, VCRM, 29148 compliance report) on `main` or manual runs, with hints and JSON artifacts.
  - Triggers: push on `main`, workflow_dispatch.

## Documentation Tooling
- `md-templates.yml`
  - Purpose: Render/validate Markdown templates; publishes previews in job summary.
  - Triggers: pull_request/dispatch; non‑blocking feedback.

- `md-templates-sessions.yml`
  - Purpose: Scheduled runs of Markdown templates across domain contexts; produces summaries with TopN coverage.
  - Triggers: schedule; optional.

## GitHub Ops & Utilities
- `action-pr-target-ci.yml`
  - Purpose: Safely test composite action from untrusted PRs via `pull_request_target` with dry‑run posting and ShellCheck on PR diffs.
  - Triggers: pull_request_target; workflow_dispatch.

- `post-comment-or-artifact-ci.yml`
  - Purpose: CI for the composite action `post-comment-or-artifact` (dry‑run correctness across Linux/Windows).

- `post-comment-or-artifact-release.yml`
  - Purpose: Tag‑driven maintenance of rolling `v1` tag and ensuring a GitHub Release exists.

- `run-annotations.yml`
  - Purpose: Helper to fetch and surface run annotations (for reviewing external runs or summarizing CI output).

- `ghops-shim-tip.yml`
  - Purpose: Provide tips/shims for GitHub Ops flows; non‑blocking.

- `ghops-smoke.yml`
  - Purpose: Lightweight smoke checks for GitHub Ops scripts.

- `bootstrap-check.yml`
  - Purpose: Dry‑run the agent bootstrap on Linux/Windows to ensure scripts and expected environment remain green.

- `ai-reviewer.yml`
  - Purpose: Coordinate an AI reviewer bot for PRs or manual invocation; mints an org app token when available and uploads review artifacts.
  - Triggers: pull_request, issue_comment(created), workflow_dispatch with optional PR number.

## How to Evolve
- Additions: Include brief rationale, SRS/ADR references, and, if gating, update `docs/ci/required-checks-rationale.md` and `docs/settings/branch-protection.expected.json`.
- Deletions: Update `docs/workflows-inventory.md` and remove references from docs/scripts.
- Ownership: Keep primary/backup owners aligned with `docs/workflows-inventory.md`.
