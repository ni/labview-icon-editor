# VS Code task shortlist

Two VS Code tasks are provided for local builds of the LabVIEW Icon Editor, driven by the Integration Engine build tooling. Run them from **Terminal → Run Task…** (or `Ctrl/Cmd+Shift+B`).

## Using the devcontainer Ollama bench (Codespaces-friendly)
- Purpose: Linux devcontainer for dotnet tooling + the Ollama/executor loop; LabVIEW/VIPM builds remain Windows-only on the host.
- Defaults (devcontainer env): `OLLAMA_HOST=http://host.docker.internal:11435`, `OLLAMA_IMAGE=ghcr.io/svelderrainruiz/ollama-local:cpu-preloaded`, `OLLAMA_MODEL_TAG=llama3-8b-local:latest`; the host Docker socket is mounted and the scripts fail fast if the socket is missing or Docker Desktop is stopped. When you invoke the bench from a host PowerShell (outside the devcontainer), it now auto-falls back to `http://localhost:11435` while still honoring explicit overrides.
- Codespaces note: `.devcontainer/devcontainer.json` mirrors the VS Code extensions for Codespaces and forces the default shell to PowerShell (`pwsh`) so **Terminal → Run Task…** exposes the Ollama Design Bench tasks in web or desktop clients without extra setup.
- Workflow (see [Codespaces workflow: Ollama Design Bench](./ollama-design-bench-codespaces.md) for the full sequence):
  0) Prefer a single action? Run **26** `Ollama: turn-key bench` to pull/start/health-check and optionally run the locked flows in one step (choose the flow + stop/reset behavior when prompted).
  1) Start Docker Desktop (or ensure Codespaces Docker is up) and open the devcontainer.
  2) Task **28** `Ollama: pull image` (GHCR owner/tag prompts).
  3) Task **29** `Ollama: start container` on 11435 with the persistent `ollama` volume (set `OLLAMA_CPUS`/`OLLAMA_MEM` to cap resources). Optional: provide a `.ollama` bundle path to import a model offline; it will retag to `OLLAMA_MODEL_TAG` if set.
  4) Task **27** `Ollama: health check` to confirm `OLLAMA_HOST` + `OLLAMA_MODEL_TAG`; keep `http://host.docker.internal:11435` inside the devcontainer or let the script default to `http://localhost:11435` on the host. Setting `OLLAMA_EXECUTOR_MODE=sim` now short-circuits the REST probe so you can run the bench without a live container when validating parity flows.
  5) Tasks **30/31/32** drive the allowlisted executor; they fail fast if the host is unreachable and now warn + default to `llama3-8b-local:latest` when you omit the model tag.
  6) Task **33** stops the container; task **34** stops and drops the model cache volume for a clean slate.

## Ollama locked tasks (30-32b)

- Two-turn, allowlisted PowerShell executor (package-build, source-distribution, local-sd-ppl) against `OLLAMA_HOST`; timeout prompted per task.
- Prep via the steps above; traffic stays on the host you pass (devcontainer default `http://host.docker.internal:11435`). Manual start alternative: `docker run -d --name ollama-local -p 11435:11435 -e OLLAMA_HOST=0.0.0.0:11435 -v ollama:/root/.ollama ghcr.io/<ghcr-owner>/ollama-local:<tag>`.
- Pull/tag the model the tasks expect: `docker exec -it ollama-local ollama pull llama3:8b` then `docker exec -it ollama-local ollama cp llama3:8b llama3-8b-local:latest`, or set `OLLAMA_MODEL_TAG` to your preferred tag and rerun the health check. Offline alternative: supply a `.ollama` bundle path in task **29** to import without hitting `registry.ollama.ai`.
- Custom models: update the input/model tag and re-run task 27 to confirm availability before triggering the locked tasks.
- Need a quick mock for successful runs (no tuned model handy)? Use `pwsh -NoProfile -File scripts/ollama-executor/Run-MockScenario.ps1 -Task source-distribution` (or `package-build` / `local-sd-ppl`). The helper spins up `MockOllamaServer`, injects the allowlisted command, sets `OLLAMA_HOST/MODEL_TAG/EXECUTOR_MODE`, runs the locked script, and tears everything down. Pass `-NoRun` to leave the mock server running so you can trigger the task yourself.
- Task **32b** adds a locked reset flow by shelling through OrchestrationCli `reset-source-dist`: it archives/culls `builds/LabVIEWIconAPI`, replays `Reset-SourceDistributionWorkspace.ps1` (commit-index + rebuild), and publishes a JSON summary. Run `pwsh -NoProfile -File scripts/ollama-executor/Run-MockScenario.ps1 -Task reset-source-dist` to simulate the same executor handshake when you just want to validate automation.
- Custom scripts: combine `-CommandScriptPath` with either native PowerShell hashtables (same session) or JSON strings (`-CommandScriptParameters '{"RepositoryPath":".","SupportedBitness":64}'` when launching via `pwsh -File`) to auto-generate ad-hoc commands, and pass `-LockedScriptPath`/`-LockedScriptParameters` to exercise new locked flows without hand-editing the task definitions.

## 01 Verify / Apply dependencies

- Runs Orchestration CLI `apply-deps` to confirm `vipm` is available and apply `runner_dependencies.vipc` for both 32-bit and 64-bit LabVIEW.
- Use this before first build on a machine or whenever dependencies change.
- Requires Windows + VIPM CLI on PATH; fails fast if `vipm` is missing.

## 02 Build LVAddon (VI Package)

- Runs Orchestration CLI `package-build` (calls IntegrationEngineCli under the hood) from the repo root using the default arguments in `.vscode/tasks.json`.
  - `SupportedBitness=64` for the top-level package and `LvlibpBitness=both` to emit 32-bit and 64-bit packed libraries.
  - `Major=0`, `Minor=1`, `Patch=0`, `Build=1` (override in the task definition or by editing the invocation before running it).
  - `CompanyName` and `AuthorName` default to the values baked into the task.
- Assumes dependencies are already applied (use the dependency task above).
- Outputs:
  - VIP artifact: `builds/vip-stash/` (top-level package for the selected bitness)
  - Packed libraries: `resource/plugins/lv_icon.lvlibp` (overwritten per build for each bitness produced)
- VIPM not available?
  - If `vipm` is not on PATH, the dependency task will fail and build packaging/VIPC steps are skipped; the lvlibp still builds and a placeholder `builds/vip-stash/vipm-skipped-placeholder.vip` is written.
  - After adding VIPM to PATH, delete the placeholder `.vip` and rerun the tasks to apply dependencies and create the real package.
- Orchestrator flags (run-build-or-package.ps1):
  - `-LabVIEWVersion` to override the LV year (default 2021), `-LvlibpBitness` for 32/64/both, `-SkipDevMode` to skip LocalHost binding, `-Simulate` to no-op lvlibp/VIPM work, `-LabVIEWMinorRevision` for VIPM (default 3).

## 20 Build: Source Distribution

- Runs `pwsh -NoProfile -File scripts/run-xcli.ps1 -Runner <runner> -- source-dist-build --repo . --commit-index builds/cache/commit-index.json --verbose-git --perf-cpu --allow-dirty`.
- Runner input (`sourceDistRunner`) defaults to `gcli` (x-cli/g-cli flow). Choose `labviewcli` to use `scripts/labview/build-source-distribution.ps1` (LabVIEWCLI) if g-cli is unavailable.
- Enforces a standard temp dir, stops stale XCli processes, and emits step/heartbeat/duration logs; artifacts land under `builds/` (manifest/csv/zip) when successful.
- Need to reset or archive a huge `builds/LabVIEWIconAPI` tree (thousands of files) before rerunning? Use `pwsh -NoProfile -File scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCli -- reset-source-dist --repo . --reset-archive-existing --reset-run-commit-index --reset-run-full-build --reset-emit-summary --reset-summary-json builds/reports/source-dist-reset.json` to inventory, optionally move the old payload under `builds/archive/<timestamp>/`, delete the working folders, regenerate the commit index in isolation, and finally kick off the task again (pass `--reset-additional-path` to track extra folders or `--reset-clear-additional-paths` to opt out of the default `builds/cache`). Add `--reset-dry-run` to preview actions. Task **32b** runs the same CLI entrypoint under the locked Ollama executor if you prefer a guarded workflow.

## 21 Verify: Source Distribution

- Runs `pwsh scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCli -- source-dist-verify --repo . --source-dist-log-stash --source-dist-strict`.
- Validates `builds/artifacts/source-distribution.zip` by checking every non-null `last_commit` in the manifest against repo git history and writes reports under `builds/reports/source-distribution-verify/<timestamp>/`.
- Strict mode treats missing/null commit hashes as failures; drop `--source-dist-strict` to allow nulls. Depends on task 20 to ensure the zip/manifest exist before verification.

## 22 Build PPL from Source Distribution

- Runs `pwsh -NoProfile -File scripts/ppl-from-sd/Build_Ppl_From_SourceDistribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2021 -SupportedBitness 64 -Major 0 -Minor 1 -Patch 0 -Build 0`.
- Extracts the source-distribution zip, copies tooling/scripts into the extracted tree, binds dev-mode to the extracted path, and runs the lvlibp build (no git metadata needed).
- Leave TMP/TEMP pointing to a writable location (`C:/temp` in the task definition).

## 23 Orchestration: SD->PPL (LabVIEWCLI)

- Runs OrchestrationCli `sd-ppl-lvcli` to serialize: lock -> temp/log/extract setup -> unbind/bind repo -> LabVIEWCLI Source Distribution build -> close/unbind -> extract the zip -> bind the extracted SD -> LabVIEWCLI Editor Packed Library build -> close/unbind -> release lock.
- Uses LabVIEWCLI for both build specs and g-cli only for bind/unbind; temp/log/extract paths live under a per-run user temp folder (fail-fast if unwritable).
- Logs phase durations and publishes a log-stash bundle when available; pass `--labviewcli-path/--labview-path/--lv-port/--temp-root/--log-root` to override defaults.

## 08 x-cli: VI Analyzer

- Runs `pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- vi-analyzer-run --request configs/vi-analyzer-request.sample.json`.
- Requires Windows with LabVIEW/LabVIEWCLI and `src/tools/icon-editor/Invoke-VIAnalyzer.ps1` (included) plus a VI Analyzer config (`src/configs/vi-analyzer/missing-in-project.viancfg` by default).
- Sets `XCLI_ALLOW_PROCESS_START=1` and `XCLI_REPO_ROOT` automatically; edit the request JSON to point at your LabVIEW version/paths and desired output locations.
- Results land under `tests/results/_agent/vi-analyzer/<label>` with `vi-analyzer.json`, report HTML, and optional RSL file.
- Depends on **DevMode: Bind (DevModeAgentCli)** to populate LocalHost.LibraryPaths before running.

## 09 x-cli: VI History (vi-compare-run)

- Runs `pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- vi-compare-run --request configs/vi-compare-run-request.sample.json`.
- Shells into `tools/icon-editor/Replay-ViCompareScenario.ps1` to replay a VI compare scenario; requires LabVIEW and a scenario JSON (sample at `scenarios/sample/vi-diff-requests.json`).
- Sets `XCLI_ALLOW_PROCESS_START=1` and `XCLI_REPO_ROOT` automatically; adjust the request JSON to your LabVIEW path, scenario, and output directories.
- Outputs a `vi-comparison-summary.json` plus optional bundles under `.tmp-tests/vi-compare-replays/…`.
- Depends on **DevMode: Bind (DevModeAgentCli)** to ensure LocalHost.LibraryPaths includes the repo.

## 06 DevMode: Bind (auto)

- Runs `pwsh -NoProfile -File scripts/task-devmode-bind.ps1 -RepositoryPath . -Mode bind -Bitness auto`, which first creates a temporary git worktree under `%LOCALAPPDATA%\labview-icon-editor\devmode-worktrees`, then derives the LabVIEW version **and bitness** from the repo VIPB and builds the `/devmode bind <year> <bitness> force` phrase automatically.
- Uses the devmode agent CLI (instead of PowerShell wrappers) to add the worktree path to LocalHost.LibraryPaths for the VIPB-declared bitness; no manual year edits required. Falls back to `dotnet run` if the published CLI is missing.

## 06b DevMode: Unbind (auto)

- Runs `pwsh -NoProfile -File scripts/task-devmode-bind.ps1 -RepositoryPath . -Mode unbind -Bitness auto` with the same auto-resolved version/bitness flow to remove this repo (preferring the latest devmode worktree under `%LOCALAPPDATA%\labview-icon-editor\devmode-worktrees`, if present) from LocalHost.LibraryPaths.
- Uses the same devmode agent CLI path and falls back to `dotnet run` if the published CLI is missing.

## 06c DevMode: Clear/Unbind all LabVIEW versions

- Runs `pwsh -NoProfile -File scripts/clear-labview-librarypaths-all.ps1` to remove LocalHost.LibraryPaths entries for all detected LabVIEW versions (32/64) and invoke OrchestrationCli `restore-sources` per version/bitness.
- Useful for resetting dev-mode tokens across multiple LabVIEW installs in one step.

## 17 Build (isolated worktree)

- Runs the build in a temporary git worktree and keeps the main repo untouched.
- Dev-mode isolation tip: before running, unbind the main repo (`06b DevMode: Unbind (auto)` or `pwsh scripts/task-devmode-bind.ps1 -RepositoryPath . -Mode unbind -Bitness both`). The worktree bind then writes LocalHost.LibraryPaths for the VIPB’s LabVIEW year/bitness to the worktree path without being blocked by an existing token.

## 18 Tooling: Clear CLI cache entry

- Runs `pwsh -NoProfile -File scripts/clear-tooling-cache.ps1 -CliName <name> -Version <ver> -Rid <rid>` to remove a specific `<CLI>/<version>/<rid>` under the tooling cache root (`%LOCALAPPDATA%\labview-icon-editor\tooling-cache` on Windows; `$HOME/.cache/labview-icon-editor/tooling-cache` on POSIX). The next probe-helper invocation will publish on miss and repopulate `<CLI>/<version>/<rid>/publish/`.

## 19 Tests: Probe helper smoke

- Runs `pwsh -NoProfile -File scripts/test/probe-helper-smoke.ps1` to exercise probe tiers (worktree/source/cache/publish), cache clear/republish, cache-key mismatch handling, and CLI `--print-provenance` outputs. Use this to verify probe/build/cache behavior locally.
- CLIs covered: IntegrationEngineCli, OrchestrationCli, DevModeAgentCli, XCli (provenance print is skipped for XCli due to its isolation guard).

## Analyze VI Packages (CLI)

The VS Code task was removed; invoke the analyzer directly:

```pwsh
pwsh -NoProfile -File scripts/analyze-vi-package/run-workflow-local.ps1 -VipArtifactPath "<vip or dir>" -MinLabVIEW "23.0"
```

Provide a real `.vip` (placeholders like `vipm-skipped-placeholder.vip` are skipped). `scripts/analyze-vi-package/VIPReader.psm1` auto-loads as part of the workflow.
