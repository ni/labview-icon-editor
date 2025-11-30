# Log Stash (design)

Purpose: provide a consistent, commit-keyed stash for build/test/runtime logs so CI artifacts, local troubleshooting, and compliance checks can point to one place with structured metadata.

Structure note: per `docs/adr/ADR-2025-011-repo-structure.md`, orchestration/tooling stays at the repo root (`scripts/`, `Tooling/`, `configs/`, `docs/`), shared modules live under `src/tools/` (with thin loaders in `tools/`), and tasks/CI resolve paths from the repo root rather than relocating assets into `src/`; preflights should check required modules/specs in those locations.

## Goals
- Single home for logs keyed by commit (and optionally run/job) under `builds/log-stash/`.
- Standard manifest that captures producer, status, LabVIEW version/bitness, timestamps, and attachments for each log bundle.
- Easy upload in CI (zip or raw paths) and quick local discovery without breaking existing `builds/logs/*.log` locations.
- Bounded retention/cleanup so log bundles do not outgrow the repo or CI artifacts.

## Non-goals
- Replacing the existing `builds/logs` naming used by scripts; the stash wraps it.
- Shipping centralized log search/analysis; this design is about capture, structure, and retention.
- Changing VIP/PPL/test stashes beyond linking to logs.

## Current state (gaps)
- Logs land in `builds/logs/` with ad-hoc names (`build-*.log`, `test-*.log`, `vipm-*.log`); no index or consistent metadata.
- `scripts/test/Test.ps1` writes a manifest in `builds/test-stash/<commit>/manifest.json` but only stores a relative log path; build/devmode/VIP steps do not.
- CI artifacts rely on manual path selection; reruns overwrite by timestamp but are not discoverable by commit/run.
- No retention strategy; logs accumulate in working copies and CI artifacts without pruning.

## Proposed design

### Layout
- Root: `builds/log-stash/`
- Per-commit folder: `builds/log-stash/<commit>/`
- Per-event bundle: `builds/log-stash/<commit>/<category>/<timestamp>-<label>/`
  - `category` examples: `build`, `test`, `vipm-install`, `vipm-uninstall`, `devmode`, `analysis`.
  - `label` defaults to the producer script or workflow job name (e.g., `ci-build`, `local-test`).
  - Contents:
    - `manifest.json`
    - `logs/` (copied from `builds/logs/*.log`, preserving original filename)
    - `attachments/` (optional) for JSON snapshots, INI dumps, screenshots, or bundle zips.
    - Optional `bundle.zip` (log + attachments) for CI upload convenience.
- Index (append-only, bounded): `builds/log-stash/index.json` keeps the last N entries with pointers to bundle paths and statuses.

### Manifest schema (per bundle)
```json
{
  "type": "log",
  "category": "test",
  "commit": "c067402",
  "git_ref": "refs/heads/develop",
  "run": {
    "ci": true,
    "provider": "github",
    "run_id": 123456789,
    "job": "test",
    "attempt": 1
  },
  "labview_version": "2021",
  "bitness": ["32", "64"],
  "producer": {
    "script": "scripts/test/Test.ps1",
    "task": "Test",
    "args": {
      "SupportedBitness": "both"
    }
  },
  "status": "success",
  "started_utc": "2025-11-27T17:34:00Z",
  "duration_ms": 64000,
  "files": {
    "logs": ["builds/log-stash/c067402/test/20251127-0934-ci-test/logs/test-20251127-092828.log"],
    "attachments": [
      "builds/log-stash/c067402/test/20251127-0934-ci-test/attachments/test-results.json"
    ],
    "bundle": "builds/log-stash/c067402/test/20251127-0934-ci-test/bundle.zip"
  },
  "notes": [
    "Transcript captured with Start-Transcript",
    "Results mirrored in builds/test-stash/c067402/manifest.json"
  ]
}
```

### Producer behavior
- Add a helper (e.g., `scripts/log-stash/Write-LogStashEntry.ps1`) that:
  - Creates the bundle directory (commit + category + timestamp/label).
  - Copies provided log paths into `logs/`; optional attachments into `attachments/`.
  - Writes `manifest.json` with the schema above (fields omitted when unknown).
  - Updates `builds/log-stash/index.json` (trim to last N entries, default 50).
  - Returns bundle paths for the caller to emit as `[artifact]` lines.
- Scripts keep writing to `builds/logs/*.log` as today; the helper is invoked once the log path is known.
- Default label inputs:
  - CI: `<job-name>` or `<job>-attempt-<n>`.
  - Local: script name or user-provided `-LogLabel`.

### Workflows to wire
1) `scripts/test/Test.ps1`: after Stop-Transcript, call helper with transcript path + test-results attachment; update test-stash manifest to also point at the log-stash bundle.
2) `scripts/build/Build.ps1`: stash build transcript and the VIPM log; include lvlibp/vip manifest paths in attachments.
3) `scripts/install-vip/*`: stash vipm install/uninstall logs with inputs (vip path, bitness hints) and exit status.
4) Dev-mode bind/unbind scripts: stash binder console output and `reports/dev-mode-bind.json`.
5) Analysis helpers (vi-analyzer/vi-compare) when run via x-cli tasks: stash analyzer logs and summary JSON.

### CI artifact strategy
- Each job uploads its bundle zip (or `logs/` folder) as `log-stash-<job>.zip`.
- Draft-release and DoD/reporting workflows reference `builds/log-stash/index.json` to link logs in reports.
- Keep artifact names consistent with stash labels for traceability.

### Example: VI compare (dry-run or real)
- Wrapper: `scripts/vi-compare/RunViCompareReplay.ps1 -RequestPath configs/vi-compare-run-request.sample.json`.
- Emits capture under `.tmp-tests/vi-compare-replays/<label>/captures/<pair>/` with:
  - `session-index.json` (schema `teststand-compare-session/v1`, status `success|failed|dry-run`, reason)
  - `lvcompare-capture.json` (schema `labview-cli-capture@v1`, status, timestamp, CLI context when executed)
  - `compare-report.html` (human-readable summary; dry-run message when CLI skipped)
- Log-stash bundle: category `compare`, label from request or default, attachments include the three capture files.
- Managed Integration Engine step can treat dry-run as success for environments without LV CLI, and fail on `failed` unless explicitly optional.

### Retention and cleanup
- Add `scripts/log-stash/Cleanup-LogStash.ps1`:
  - Retain last N bundles per category (default 10) and max age (default 14 days) unless `KEEP_LOG_STASH_ALL` is set.
  - Option to prune only attachments while keeping manifests for audit.
- CI can invoke cleanup post-upload to keep workspaces small; local runs are opt-in.

### Backward compatibility
- Existing consumers that read `builds/logs` or `builds/test-stash` keep working; paths are copied, not moved.
- Manifests reference relative paths so bundles move cleanly into CI artifacts or zipped exports.
- No change to VIP/PPL stash semantics; they can link to log bundles via attachments if desired.

## Implementation slices (proposed)
1) MVP: create helper module, wire `Test.ps1` and `Build.ps1`, emit bundle zips, add cleanup script, and document usage.
2) CI adoption: upload bundles from test/build jobs; link in reports (completion/status/DoD summaries).
3) Coverage expansion: bind/unbind, vipm install/uninstall, vi-analyzer/vi-compare.
4) Index polish: add simple `log-stash ls` helper (PowerShell) to query by commit/category/status.

## Open questions
- Do we want per-run subfolders even when commit is unknown (`manual`)? Proposal: use `manual/<timestamp>-<label>/`.
- Should we compress logs by default (zip) or leave raw unless `-Compress` is passed?
- How many bundles should be preserved in developer worktrees vs CI runners (defaults above are suggestions)?
- Is a slim JSON index enough, or do we also want a Markdown summary for humans?

## Change history
- 2025-11-27: Initial design draft for log-stash.
