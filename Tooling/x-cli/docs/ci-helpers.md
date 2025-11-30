# CI Helpers — Quick Index

This page lists the core CI helpers, where they live, what they do, and how to consume their outputs (JSON schemas, summaries, and comments). Keep this list in sync as helpers evolve.

## ghops wrappers (GitHub CLI orchestration)
- Paths: `scripts/ghops/*.ps1`, `scripts/ghops/*.sh`
- What: PR create, run watch/rerun, artifacts download, release tag.
- JSON: all wrappers support `-Json/--json` (used by `ghops-smoke.yml`).
- Tests: `scripts/ghops/tests/Ghops.Tests.ps1` (dry-run + JSON mode).
- Notes: shim guard stubs `pre-commit`/`ssh` when missing; see README/CONTRIBUTING for the manual pre-commit command.
- Token helper: `scripts/ghops/tools/use-local-github-token.{ps1,sh}` — adds `.tools/bin` to PATH for the current shell, loads `.secrets/github_token.txt`, optional `-Login/--login` to authenticate gh.
- Update PR (with rescue fallback): `scripts/ghops/tools/update-pr-with-rescue.{ps1,sh}`
  - Saves a rescue branch at the PR head before updating.
  - Modes:
    - Server: `-Strategy server-update-branch` (uses GitHub API; fast path)
    - Local: `-Strategy merge-develop -Prefer pr|develop` (merges base into head with `-X ours|theirs`)
  - Example:
    - Windows: `pwsh -File scripts/ghops/tools/update-pr-with-rescue.ps1 -Repo owner/name -Pr 123 -Strategy server-update-branch`
    - POSIX: `bash scripts/ghops/tools/update-pr-with-rescue.sh --repo owner/name --pr 123 --strategy merge-develop --prefer pr`
- PATH bootstrap (optional, persistent): `scripts/ghops/tools/bootstrap-path.{ps1,sh}` — appends a small, idempotent snippet to your shell profile(s) to include `.tools/bin` on PATH in new terminals. Use `-EchoOnce`/`--echo-once` to print a short confirmation once per session.

### Optional: GitKraken CLI Passthrough (Developer Convenience)

- What: opt-in passthrough so common, read-only git commands can be executed via GitKraken CLI (`gk`) for nicer UX. CI remains on native `git`.
- Scripts: `scripts/ghops/tools/git-pass.{ps1,sh}` export `Invoke-Git` / `invoke_git`.
- Enable (dev shell):
  - PowerShell: `. scripts/ghops/tools/git-pass.ps1; $env:USE_GK_PASSTHROUGH='1'; Invoke-Git status`
  - POSIX: `source scripts/ghops/tools/git-pass.sh; USE_GK_PASSTHROUGH=1 invoke_git status`
- Force tool selection:
  - `GIT_TOOL=git|gk|auto` (default `auto`). `auto` uses `gk` only if `USE_GK_PASSTHROUGH=1` and `gk` is available.
- Allowlist (safe by default):
  - Defaults: `status,log,show,diff,rev-parse,describe,ls-files,remote -v,branch,config --get`
  - Expand with: `GIT_PASSTHROUGH_ALLOW='status,log,show,fetch'` or allow all with `GIT_PASSTHROUGH_ALLOW='*'`.
- Alias (optional):
  - Dev-only: `GIT_ALIAS=1` to alias `git` to the wrapper in the current session. Never used in CI.
- Notes:
  - Guarded in CI: when `CI=1`/`GITHUB_ACTIONS=1`, wrappers always use native `git` regardless of env toggles.
- Not a substitute for GitHub CLI; Actions/Checks/logs still use `gh`.

### Token Awareness (Org Access)
### Branch Protection Awareness (Local)

- Awareness helper: `scripts/ghops/tools/branch-protection-awareness.ps1` prints effective required checks for a branch, combining classic protection and rulesets.
- Expectations: `docs/settings/branch-protection.expected.json` (source of truth) and `docs/ci/branch-protection.md` (human-readable summary).
- Guard runner: `scripts/dev/check-branch-protection.ps1` executes Pester tests (`scripts/tests/BranchProtection.Tests.ps1`) that compare the documented expectations with live GitHub settings.
- CI presence: none (developer-only guard). Tests skip with an Inconclusive result if `gh` is unauthenticated or no token is available.


- Script: `scripts/ghops/tools/token-awareness.ps1`
- Purpose: detect token transport (gh vs REST), list advertised scopes, and verify whether the token can see your organization.
- Usage:
  - `pwsh -File scripts/ghops/tools/token-awareness.ps1 -Repo <owner/name> -Json`
  - Flags: `-Org <owner>` overrides owner inference; `-Transport auto|gh|rest` controls transport.
- Docs: `docs/ci/token-awareness.md`
- Integrated helpers (e.g., `get-run-annotations.ps1`) run a preflight automatically; disable with `-NoPreflightToken` if needed.
- CI tip: map an org-scoped token to `GH_TOKEN` in steps that need org access:
  - `env: { GH_TOKEN: ${{ secrets.GH_ORG_TOKEN }} }`

### Run Annotations (Diagnostics)
- Helper: `scripts/ghops/tools/get-run-annotations.ps1`
- Purpose: fetch check-run annotations for a workflow run’s `head_sha`.
- Usage:
  - `pwsh -File scripts/ghops/tools/get-run-annotations.ps1 -Repo <owner/name> -RunId <id> -Out artifacts/gh-run-annotations.json -Json`
- Docs: `docs/ci/github-actions-annotations.md`
- Auto artifact (optional): set repo variable `UPLOAD_RUN_ANNOTATIONS=1` to enable `.github/workflows/run-annotations.yml` to upload `gh-run-annotations.json` for each completed run.

## ghops JSON aggregation
- Workflow: `.github/workflows/ghops-smoke.yml`
- Artifacts: `ghops-logs`, `ghops-logs-ps`, `ghops-logs-all/` (unified `all-logs.json`).
- Schema: `docs/schemas/v1/ghops.logs.v1.schema.json` (validated via PowerShell and Ajv).
- Summary: Job Summary prints quick counts; optional PR comment gated by labels.

## Mergeability Check (PRs)
- Script: `scripts/check-mergeable.ps1`
- Purpose: surface GitHub PR merge conflicts early in CI and local runs.
- Usage:
  - CI: add a step guarded by `if: github.event_name == 'pull_request'` and run `pwsh ./scripts/check-mergeable.ps1` (uses `GITHUB_EVENT_PATH` and `GITHUB_TOKEN`).
  - Local: `pwsh ./scripts/check-mergeable.ps1 -Owner org -Repo repo -Pr 123`
- Behavior: prints `mergeable` and `mergeable_state` and exits non‑zero on conflicts.

## RTM (Traceability Verify)
- Tool: `tools/rtm-verify-ts` (TypeScript, Node 20)
- Outputs: `telemetry/rtm/rtm-summary.json` (`rtm.verify/v1`)
- Schema: `docs/schemas/v1/rtm.verify.v1.schema.json` (validated via PowerShell and Ajv).
- Summary: Job Summary (counts + failing IDs top N). Optional PR comment on failure.

## Lychee (docs links)
- Workflow: `.github/workflows/docs-gate.yml` (job name/id: `lychee`)
- Config: `.lychee.toml` (offline, include fragments)
- Notes: Required branch‑protection check; keep job id/name as `lychee`.

Local run (Docker)
- Prereq: Docker Desktop/Engine installed and running.
- POSIX:
  ```bash
  docker run --rm -v "$PWD:/data" -w /data lycheeverse/lychee:latest \
    --config .lychee.toml --no-progress --offline --include-fragments .
  ```
- PowerShell (Windows):
  ```pwsh
  $repo = (Get-Location).Path
  docker run --rm -v "${repo}:/data" -w /data lycheeverse/lychee:latest `
    --config .lychee.toml --no-progress --offline --include-fragments .
  ```
- Scope: scans local Markdown only; external `http(s)`/`mailto` links are excluded by `.lychee.toml`.

Convenience wrappers
- POSIX: `./scripts/docs-link-check.sh [path]`
- Windows: `pwsh ./scripts/docs-link-check.ps1 [-Path path]`

## Pester (scripts)
- Location: `scripts/tests/*.Tests.ps1`
- Local run:
  - `pwsh -NoProfile -Command "Invoke-Pester -Output Detailed -Script scripts/tests"`
- CI: Tests Gate includes a Windows job that installs Pester and runs these tests.
## External Actions
- Prefer external actions for PR comments and artifacts metadata:
  - `LabVIEW-Community-CI-CD/gha-post-pr-comment@v1`
  - `LabVIEW-Community-CI-CD/gha-artifacts-metadata@v1`
- Keep local equivalents for development or fallback only.

## Token Diagnostics (Composite)
- Path: `.github/actions/token-diagnostics/action.yml`
- What: Detects the effective GitHub token source used by repo helpers, cross‑platform. Outputs JSON and exposes fields as step outputs; optionally uploads an artifact.
- Inputs:
  - `upload-artifact` (default `true`)
  - `artifact-name` (default `token-info`)
- Outputs:
  - `found` (`true|false`), `kind` (`user|repo`), `source` (string), `length` (int), `token_preview` (masked), `json` (full JSON), `path` (file path on runner)
- Usage:
  ```yaml
  - name: Token diagnostics (debug)
    id: token_diag
    if: ${{ env.DEBUG_TOKEN_INFO == 'true' || env.DEBUG_TOKEN_INFO == '1' }}
    uses: ./.github/actions/token-diagnostics
    with:
      artifact-name: token-info-stage2
      upload-artifact: true
  - name: Token diagnostics summary
    if: ${{ env.DEBUG_TOKEN_INFO == 'true' || env.DEBUG_TOKEN_INFO == '1' }}
    run: |
      echo "### Token Diagnostics" >> "$GITHUB_STEP_SUMMARY"
      echo "- found: ${{ steps.token_diag.outputs.found }}" >> "$GITHUB_STEP_SUMMARY"
      echo "- kind: ${{ steps.token_diag.outputs.kind }}" >> "$GITHUB_STEP_SUMMARY"
      echo "- source: ${{ steps.token_diag.outputs.source }}" >> "$GITHUB_STEP_SUMMARY"
      echo "- length: ${{ steps.token_diag.outputs.length }}" >> "$GITHUB_STEP_SUMMARY"
      echo "- preview: ${{ steps.token_diag.outputs.token_preview }}" >> "$GITHUB_STEP_SUMMARY"
  ```
- Stage integrations:
  - Stage 1: `.github/workflows/stage1-telemetry.yml` supports `debug_token_info` (dispatch/call) and repo variable `DEBUG_TOKEN_INFO`; uploads `token-info-stage1` when enabled.
  - Stage 2: `.github/workflows/stage2.yml` supports `debug_token_info`; job exposes outputs `token_found`, `token_kind`, `token_source`, `token_length`, `token_preview` from the diagnostics step.
  - Stage 3: `.github/workflows/stage3.yml` uses `vars.DEBUG_TOKEN_INFO` to gate diagnostics and prints a summary.
  - Combined Stage 2–3: `.github/workflows/stage2-3-ci.yml` adds a `debug_token_info` input and propagates diagnostics from Stage 2 to Stage 3 via `needs.stage2_ubuntu_ci.outputs.*`.
- Local helpers used by the composite:
  - POSIX script: `scripts/print-effective-token.sh` (JSON, masked)
  - PowerShell script: `scripts/print-effective-token.ps1` (JSON, masked)

## Telemetry CLI
- See `docs/cli/telemetry.md` for the built-in C# summarizer.
- CI usage example (after QA steps):
  ```yaml
  - name: Summarize QA telemetry
    run: |
      dotnet run -- telemetry summarize \
        --in artifacts/qa-telemetry.jsonl \
        --out telemetry/summary.json \
        --history telemetry/qa-summary-history.jsonl
  ```
- Outputs: `telemetry/summary.json` (snapshot), optional `telemetry/qa-summary-history.jsonl` (one JSON line per run)

- Optional gate on failures:
  ```yaml
  - name: Telemetry gate (max failures)
    env:
      MAX_QA_FAILURES: 0
      # Optional per-step caps (comma-separated step=limit list)
      MAX_QA_FAILURES_STEP: test-python=0,build-release=0
    run: |
      dotnet run -- telemetry check --summary telemetry/summary.json --max-failures ${MAX_QA_FAILURES} \
        --max-failures-step test-python=0 --max-failures-step build-release=0
  ```

- Optional schema validation (run locally or in CI):
  ```bash
  dotnet run -- telemetry validate --summary telemetry/summary.json \
    --schema docs/schemas/v1/telemetry.summary.v1.schema.json
  dotnet run -- telemetry validate --events artifacts/qa-telemetry.jsonl \
    --schema docs/schemas/v1/telemetry.events.v1.schema.json
  ```
  - In QA locally: set `QA_VALIDATE_SCHEMA=1` to enable an extra validation step.
  - In Stage 1: pass `validate_schema: true` to the workflow dispatch, or set repo variable `VALIDATE_TELEMETRY_SCHEMA=1`.

### Stage 2/2–3 Toggles (validate + gates)

- Stage 2 (`.github/workflows/stage2.yml`) accepts optional inputs when using `workflow_dispatch`/`workflow_call`:
  - `validate_schema` (boolean) — validate Stage 1 summary/events using JSON Schemas.
  - `max_qa_failures` (string) — total failure gate (e.g., `0`).
  - `max_qa_failures_step` (string) — per-step gates, comma-separated list (e.g., `test-python=0,build-release=0`).
  - Repo-wide variables can be used instead: `VALIDATE_TELEMETRY_SCHEMA`, `MAX_QA_FAILURES`, `MAX_QA_FAILURES_STEP`.

- Stage 2–3 combined (`.github/workflows/stage2-3-ci.yml`) exposes the same inputs under `workflow_dispatch`.

Example (manual dispatch):

```yaml
on:
  workflow_dispatch:
    inputs:
      validate_schema:
        description: Validate Stage 1 telemetry
        required: false
        default: false
        type: boolean
      max_qa_failures:
        description: Total failures gate (e.g., 0)
        required: false
      max_qa_failures_step:
        description: Per-step gates (e.g., test-python=0,build-release=0)
        required: false
```

At runtime, Stage 2 will:
- Validate `telemetry/summary.json` (always) and `artifacts/qa-telemetry.jsonl` (if present) when `validate_schema`/`VALIDATE_TELEMETRY_SCHEMA` is true.
- Gate on failures using total/per-step inputs or variables if provided.

## JSON Schemas (Index)
- See `docs/schemas/README.md` for schema list and intended producers/consumers.

## Markdown Templates Preview & Sessions
- Badges:
  
  [![Markdown Templates Preview](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates.yml/badge.svg)](../.github/workflows/md-templates.yml)
  [![Markdown Templates Sessions](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates-sessions.yml/badge.svg)](../.github/workflows/md-templates-sessions.yml)
- Workflows: `.github/workflows/md-templates.yml`, `.github/workflows/md-templates-sessions.yml`
- Artifacts: `md-templates` (`*.example.md`), `md-templates-sessions-preview`, `md-templates-sessions`
- Rolling artifacts: `md-templates-suggestions-rolling-preview` (Preview), `md-templates-suggestions-rolling` (Sessions)
- Schema: `docs/schemas/v1/md.templates.sessions.v1.schema.json`
- Job Summary: shows totals and “Effective thresholds: TopN, MinCount” plus a Top placeholders table
- Configure via repo variables (Settings → Secrets and variables → Actions → Variables):
  - `MD_TEMPLATES_TOPN` (default 10)
  - `MD_TEMPLATES_MINCOUNT` (default 1)
   - `MD_TEMPLATES_HISTORY_PUBLISH` (1 to enable gh-pages append)
   - `MD_TEMPLATES_CYCLE_WINDOW` (default 8) and `MD_TEMPLATES_SUGGEST_MINCOUNT` (default 2)
- History (gh-pages):
  - blob: https://github.com/LabVIEW-Community-CI-CD/x-cli/blob/gh-pages/telemetry/templates/suggestions.jsonl
  - raw:  https://raw.githubusercontent.com/LabVIEW-Community-CI-CD/x-cli/gh-pages/telemetry/templates/suggestions.jsonl

