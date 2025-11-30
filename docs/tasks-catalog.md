# VS Code Tasks Catalog

Core tasks are now driven by the Orchestration CLI (PS scripts remain as delegates). Outputs land in `builds/vip-stash/` (VIP artifact) and `resource/plugins/lv_icon.lvlibp` (packed libraries). If `vipm` is not on PATH, the dependency task will fail and build VIPC/VIPM steps are skipped; the lvlibp still builds, and a placeholder `builds/vip-stash/vipm-skipped-placeholder.vip` is written. After adding VIPM to PATH, delete the placeholder `.vip` and rerun the tasks to create the real package.

| Task | Notes |
| --- | --- |
| 01 Verify / Apply dependencies | Orchestration CLI `apply-deps` applies `runner_dependencies.vipc` for 32-bit and 64-bit. Requires `vipm` on PATH. |
| 02 Build LVAddon (VI Package) | Orchestration CLI `package-build` (managed on Windows) with defaults `0.1.0.1`, `bitness=64`, `LvlibpBitness=both`. Adjust `.vscode/tasks.json` if you need different defaults. |
| 08 x-cli: VI Analyzer | Runs `vi-analyzer-run` via x-cli with `configs/vi-analyzer-request.sample.json`. Requires LabVIEW/LabVIEWCLI and `src/tools/icon-editor/Invoke-VIAnalyzer.ps1`; outputs to `tests/results/_agent/vi-analyzer/<label>`. |
| 09 x-cli: VI History (vi-compare-run) | Replays a VI compare scenario via x-cli using `configs/vi-compare-run-request.sample.json` and `tools/icon-editor/Replay-ViCompareScenario.ps1`; writes `vi-comparison-summary.json` and optional bundles under `.tmp-tests/vi-compare-replays/`. |
| 06 DevMode: Bind (auto) | Creates a temporary git worktree under `%LOCALAPPDATA%\labview-icon-editor\devmode-worktrees`, then binds LocalHost.LibraryPaths to that path via `scripts/task-devmode-bind.ps1 -Mode bind -Bitness auto`, deriving the LabVIEW version **and bitness** from the repo VIPB and calling `Tooling/dotnet/DevModeAgentCli`. |
| 06b DevMode: Unbind (auto) | Unbinds LocalHost.LibraryPaths via `scripts/task-devmode-bind.ps1 -Mode unbind -Bitness auto`, preferring the most recent devmode worktree in `%LOCALAPPDATA%\labview-icon-editor\devmode-worktrees` (if present) before falling back to the source repo. |
| 06c DevMode: Clear/Unbind all LabVIEW versions | Clears LocalHost.LibraryPaths entries for all detected LabVIEW versions (32/64) and runs OrchestrationCli `restore-sources` per version/bitness via `scripts/clear-labview-librarypaths-all.ps1`. |
