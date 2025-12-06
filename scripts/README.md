# Scripts (legacy delegates)

PowerShell scripts remain for compatibility, but the supported entrypoint is the Orchestration CLI:

```
pwsh scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCli -- <subcommand> [options]
```

Subcommands cover apply-deps, restore-sources, labview-close, unit-tests, vi-analyzer, missing-check, and package-build. Prefer these over calling scripts directly; the scripts now emit a deprecation warning and act as thin delegates.

## Probe/build/cache helper (TOOL-010..016)
- CLIs are resolved via `scripts/common/resolve-repo-cli.ps1` in this order: worktree → source repo → cache → publish. Cache root is `%LOCALAPPDATA%\labview-icon-editor\tooling-cache/<CLI>/<version>/<rid>/publish/` (Windows) or `$HOME/.cache/labview-icon-editor/tooling-cache/<CLI>/<version>/<rid>/publish/` (POSIX).
- Provenance: run any CLI with `--print-provenance` to emit `path`, `tier`, `cacheKey`, and `rid`. The helper can enforce an `ExpectedCacheKey` to fail fast on mismatches.
- Cache maintenance: VS Code Task 18 “Tooling: Clear CLI cache entry” calls `scripts/clear-tooling-cache.ps1` for a specific `<CLI>/<version>/<rid>`; next helper run publishes on miss and repopulates.
- Validation: VS Code Task 19 “Tests: Probe helper smoke” runs `scripts/test/probe-helper-smoke.ps1` covering worktree/source/cache/publish tiers, cache clear/republish, cache-key mismatch handling, and provenance output.
- Tip: For legacy script delegates that still show raw `dotnet run` usage, prefer calling the CLI via the resolver (`pwsh scripts/common/resolve-repo-cli.ps1 -CliName <name> -RepoPath <path> -SourceRepoPath <path>`) to honor the probe/build/cache contract and provenance logging.
- Rollback: Tasks and callers should not rely on cache paths. If probe caching needs to be bypassed, adjust the helper to always select worktree/source (or add a bypass flag) while keeping task inputs/outputs unchanged; because tasks call CLIs by name/version, rollback does not affect task semantics.

Shared modules pattern (per `docs/adr/ADR-2025-011-repo-structure.md`):
- Keep orchestration/tooling at the repo root (`scripts/`, `Tooling/`, `configs/`, `docs/`).
- Put shared modules in `src/tools/` (e.g., `src/tools/*.psm1`, `src/tools/providers/*`) and expose thin loaders from `tools/` as needed (e.g., `tools/VendorTools.psm1`).
- Resolve paths from the repo root; do not move root orchestration into `src/`. Managed CLI preflights rely on these locations.

CI helpers:

- `scripts/git/ci-run-summary.ps1`: Summarize the latest workflow run for the current branch/HEAD and list failing jobs; add `-DownloadLogs` to save failing job logs under `artifacts/ci-logs/`. Use `-WaitForHeadRun` (with `-WaitTimeoutSeconds`/`-WaitIntervalSeconds`) right after pushing to wait for the new run to show up. Example: `pwsh scripts/git/ci-run-summary.ps1 -RepoPath . -WaitForHeadRun -DownloadLogs`.
- `scripts/git/ci-refine-loop.ps1`: End-to-end loop helper; waits for the latest run on the current branch, prints failing jobs, optionally downloads failing job logs, and can run a local test command. Example: `pwsh scripts/git/ci-refine-loop.ps1 -RepoPath . -WaitForHeadRun -DownloadLogs -TestCommand pwsh scripts/test/Test.ps1 -RepositoryPath . -SupportedBitness 64`.
- `scripts/ollama-executor/Run-CiRefineLoops.ps1`: Two+ loop driver for the custom agent; downloads failing logs, runs optional tests/patch commands each loop, and forwards extra CiRefineCli args. Extra args can be passed as a clean array or a single comma-delimited blob (e.g., `-ExtraArgs '--repo-slug,owner/repo,--run-id,123,--status-filter,completed,in_progress'`).
- `scripts/status/runner-status.ps1`: Quick runner + latest-run snapshot. Defaults to `Ollama Executor Smoke Test` workflow and current repo. Usage: `pwsh -NoProfile -File scripts/status/runner-status.ps1` or add `-WorkflowName "<workflow>"` / `-Repo owner/name` / `-Json` for machine-readable output. Helpful when diagnosing the self-hosted `self-hosted-windows-lv` runner for the Ollama executor.
