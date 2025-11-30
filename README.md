# LabVIEW Icon Editor (built with the Integration Engine)

Open-source LabVIEW Icon Editor, packaged as a `.vip`. This repo ships an "Integration Engine" (the build/dependency orchestration) that applies prerequisites and packages the Icon Editor with minimal inputs.

Repo layout is documented in ADR-2025-011 (root scripts/tooling, shared modules under `src/tools/`; see `docs/adr/ADR-2025-011-repo-structure.md`).

## Build with VS Code Tasks

Prerequisites
- Windows with LabVIEW 2021 SP1 (32-bit and/or 64-bit for the bitness you need)
- VIPM CLI (`vipm`) on PATH
- PowerShell 7+, Git with full history (for versioning)
 - Tooling cache/provenance: repo CLIs resolve via a shared helper (worktree → source → cache → publish) keyed by `<CLI>/<version>/<rid>`. Run any CLI with `--print-provenance` to see `path`, `tier`, `cacheKey`, and `rid`. Use VS Code task “Tooling: Clear CLI cache entry” (Task 18) to remove a specific cache key; the next helper run publishes on miss and repopulates `<CLI>/<version>/<rid>/publish/`.

### 01 Verify / Apply dependencies
Run **Terminal → Run Task → 01 Verify / Apply dependencies** to confirm `vipm` is available and apply `runner_dependencies.vipc` for both 32-bit and 64-bit LabVIEW. Run this before the build if dependencies have changed or you are setting up a new machine.

### 02 Build LVAddon (VI Package)

Use **Terminal → Run Task → 02 Build LVAddon (VI Package)** in VS Code to run the IntegrationEngineCli (`dotnet run --project Tooling/dotnet/IntegrationEngineCli`). By default it shells into the PowerShell wrapper to mirror CI; on Windows the task adds `--managed` to drive the managed orchestration directly. Outputs land in `builds/vip-stash/` (VIP artifact) and `resource/plugins/lv_icon.lvlibp` (overwritten for each bitness built). This task assumes dependencies have already been applied.
Default version inputs are `Major=0`, `Minor=1`, `Patch=0`, and `Build=1` (override in `.vscode/tasks.json` or when invoking the task).

VIPM not available?
- If `vipm` is not on PATH, the dependency task will fail and the build skips VIPC/VIPM steps, still builds the lvlibp, and writes a placeholder `builds/vip-stash/vipm-skipped-placeholder.vip` so you know packaging was skipped.
- After installing or exposing VIPM to PATH, delete the placeholder `.vip` and rerun the **02 Build LVAddon (VI Package)** task to create the real package.

### 20 Build: Source Distribution

Runs **Terminal -> Run Task -> 20 Build: Source Distribution** to invoke `scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath .` (the same step wired into the IntegrationEngine `build-source-distribution` command/managed flow). Outputs land in `builds/Source Distribution/manifest.json` + `manifest.csv` (fields: `path`, `last_commit`, `commit_author`, `commit_date`, `commit_source`, `size_bytes`) and `builds/artifacts/source-distribution.zip` (contains the distribution plus both manifests). Logs emit `[artifact]` and log-stash entries so CI/local runs surface the bundle consistently.

### 21 Verify: Source Distribution

Runs **Terminal -> Run Task -> 21 Verify: Source Distribution** to validate `builds/artifacts/source-distribution.zip` via `OrchestrationCli source-dist-verify --source-dist-log-stash --source-dist-strict`. Produces a verification report under `builds/reports/source-distribution-verify/<timestamp>/report.json`, emits `[artifact]` lines for the report/extracted folder, and fails on missing/invalid commit hashes (drop `--source-dist-strict` to allow null commits).

More details: see `docs/vscode-tasks.md`.

## Dev container & dotnet tooling
- Dev container: `.devcontainer/` (VS Code "Reopen in Container" with .NET 8 + PowerShell). On create, it restores and builds `Tooling/dotnet/RequirementsSummarizer` as a health check.
- Dotnet CLIs: see `Tooling/dotnet/README.md` for IntegrationEngineCli, VipbJsonTool, LvprojJsonTool, and RequirementsSummarizer usage.
- Requirements summary task: **Terminal → Run Task → Requirements summary (dotnet)** renders `reports/requirements-summary.md` from `docs/requirements/requirements.csv`.
- x-cli: vendored at `Tooling/x-cli/` (vi-analyzer and vi-compare helpers). Build with `dotnet build Tooling/x-cli/XCli.sln`; run with `dotnet run --project Tooling/x-cli/src/XCli/XCli.csproj -- --help`. VS Code tasks exist for `vi-analyzer-run` and `vi-compare-run` (see `.vscode/tasks.json`).

## Requirements & ISO/IEC/IEEE 29148 artifacts
- Source of truth: `docs/requirements/requirements.csv` (gated in CI by language and attribute checks).
- Supporting docs: `docs/requirements/glossary.md` and `docs/requirements/set-quality-checklist.md`; index in `docs/requirements/README.md`.
- Reports: `reports/requirements-summary.md` (rendered by the VS Code task/CI).
- Probe/provenance/cache: see `docs/provenance-and-cache.md` for probe order, `--print-provenance`, cache clear task (Task 18), and probe smoke validation (Task 19).


## Analyze VI Packages (CLI-only)

Run the analyzer directly-there is no VS Code task for this:

```pwsh
pwsh -NoProfile -File scripts/analyze-vi-package/run-workflow-local.ps1 -VipArtifactPath "<vip or dir>" -MinLabVIEW "21.0"
```

Provide a real `.vip` artifact (placeholders such as `vipm-skipped-placeholder.vip` are skipped) and the workflow auto-loads `scripts/analyze-vi-package/VIPReader.psm1`.


## Docs quicklinks
- Build & tasks: `docs/vscode-tasks.md`
- CI overview: `docs/ci-workflows.md`
- VIPM Docker helper: `Tooling/docker/vipm/README.md`
- Dev mode toggle: `scripts/set-development-mode/run-dev-mode.ps1` and `scripts/revert-development-mode/run-dev-mode.ps1`
- Tests: `docs/testing/policy.md` (and `Test/` for Pester)

