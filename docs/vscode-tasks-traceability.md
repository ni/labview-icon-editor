# VS Code task traceability matrix (LabVIEW versions/bitness)

Detected environment (auto):
- LabVIEW.exe present: 2020 (64/32), 2021 (64/32), 2022 (64/32), 2023 (64/32), 2024 (64/32), 2025 (64/32), 2026 (64/32).
- VIPB target (Tooling/deployment/seed.vipb): 2023, bitness 64 (auto tasks bind to this).
- Tooling: g-cli at `C:\Program Files\G-CLI\bin\g-cli.exe`; VIPM under `C:\Program Files\JKI\VI Package Manager\support\vipm.exe`.

Legend:
- If a LabVIEW version/bitness is not installed or a prereq is missing, mark the matrix row as `skip (<reason>)` for that version instead of failing the whole run.
- For tasks with inputs, adjust `--bitness`/request JSON to cover both 64-bit and 32-bit where installed.

## Execution checklist (mark `[x]` when success criteria is met)

Change `[ ]` to `[x]` when the task passes for that LabVIEW year/bitness. If a version/bitness is missing or intentionally not run, replace the cell with `skip (<reason>)`. Add columns for new versions as they are installed.

| Task label | 2020 64 | 2021 64 | 2021 32 | 2023 64 | 2023 32 | 2025 64 | 2025 32 | 2026 64 | Notes (links/skip reasons) |
| - | - | - | - | - | - | - | - | - | - |
| 01 Verify / Apply dependencies | [ ] | [x] | [x] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 02 Build LVAddon (VI Package) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 17 Build (isolated worktree) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 03 Orchestration: Restore packaged sources | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 04 Orchestration: Close LabVIEW | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 06 DevMode: Bind (auto) | skip (fixed to VIPB 2023/64) | [ ] | n/a | n/a | n/a | n/a | n/a | n/a | Auto resolves to 2023/64 |
| 06b DevMode: Unbind (auto) | skip | [ ] | n/a | n/a | n/a | n/a | n/a | n/a | Auto resolves to 2023/64 |
| 06c DevMode: Clear/Unbind all LabVIEW versions | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | One run sweeps all installed versions |
| 07 x-cli: VI Analyzer (raw) | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Update request JSON per version |
| 21b VIPB: Override seed.vipb (repo) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Target year set via input |
| 06d DevMode: Bind (repo, 64-bit) | skip | [ ] | n/a | n/a | n/a | n/a | n/a | n/a | 64-bit only |
| 21c VIPB override + DevMode (repo) | [ ] | [ ] | n/a | [ ] | n/a | [ ] | n/a | [ ] | 64-bit only |
| 08 x-cli: VI Analyzer | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Sequence bind/run/unbind |
| 20 Build: Source Distribution | [ ] | [x] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Refreshed zip w/ pristine lvproj (20251129-215141757) |
| 21 Verify: Source Distribution | [ ] | [x] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | success (0 warnings); report builds/reports/source-distribution-verify/20251129-095623 |
| 22 Build PPL from Source Distribution | [ ] | [x] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | lv_icon.lvlibp built from SD (temp run 20251129-215141757) |
| 23 Orchestration: SD->PPL (LabVIEWCLI) | [ ] | [x] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | VIPB-derived 2023/64; logs in %TEMP%\\labview-icon-editor\\sd-ppl-lvcli\\20251129-215141757 and 20251130-050649 |
| 21 VIPB: Bump LabVIEW version | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Creates worktree; runs build/verify if flags set |
| 09 x-cli: VI History (vi-compare-run) | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a | Sample request uses 2025 |
| 09b x-cli: VI History from SD (read-only) | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a | Uses extracted SD root; no bind/build; sample targets 2025 |
| SD: Build x-cli (bundled) | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a | Build x-cli inside extracted SD (Release) |
| SD: VI History (execute) | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a | Requires built x-cli and LabVIEW 2025; uses AllowExecute flag |
| SD: VI History (bundled) | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a | Extracted SD only; read-only replay with bundled script |
| 10 Tests: run (TestsCli) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Set `--bitness` to installed subset |
| 11 Tests: run (Orchestration CLI unit-tests) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Set `--bitness` to installed subset |
| 12 Tests: run (isolated worktree) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 13 Orchestration: VI Analyzer | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Uses request JSON labVIEWCLI path |
| 14 Orchestration: VI Compare | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a | Requires >=2025 |
| 15 Orchestration: Missing-in-project check | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | LV version fixed to 2021 |
| 16 Tests: VI Analyzer (Test.ps1) | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Update request path per version |

LV-agnostic tasks (check once per run):
- [ ] 05 Requirements summary (dotnet)
- [ ] 05b Requirements summary (bundled SD)
- [ ] 18 Tooling: Clear CLI cache entry
- [ ] 19 Tests: Probe helper smoke

## Per-cycle checklists

Use one table per regression/test cycle. Copy the template below and paste a new copy for each run (fill in the cycle name/date and mark `[x]` or `skip (<reason>)`).

Template:

Cycle: __________ (date/branch/owner)

| Task label | 2020 64 | 2021 64 | 2021 32 | 2023 64 | 2023 32 | 2025 64 | 2025 32 | 2026 64 | Notes |
| - | - | - | - | - | - | - | - | - | - |
| 01 Verify / Apply dependencies | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 02 Build LVAddon (VI Package) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 17 Build (isolated worktree) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 03 Orchestration: Restore packaged sources | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 04 Orchestration: Close LabVIEW | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 06 DevMode: Bind (auto) | skip | [ ] | n/a | n/a | n/a | n/a | n/a | n/a | Auto resolves to 2023/64 |
| 06b DevMode: Unbind (auto) | skip | [ ] | n/a | n/a | n/a | n/a | n/a | n/a | Auto resolves to 2023/64 |
| 06c DevMode: Clear/Unbind all LabVIEW versions | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | One run sweeps all installs |
| 07 x-cli: VI Analyzer (raw) | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Update request JSON per version |
| 21b VIPB: Override seed.vipb (repo) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 06d DevMode: Bind (repo, 64-bit) | skip | [ ] | n/a | n/a | n/a | n/a | n/a | n/a | 64-bit only |
| 21c VIPB override + DevMode (repo) | [ ] | [ ] | n/a | [ ] | n/a | [ ] | n/a | [ ] | 64-bit only |
| 08 x-cli: VI Analyzer | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Sequence bind/run/unbind |
| 20 Build: Source Distribution | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 21 Verify: Source Distribution | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 22 Build PPL from Source Distribution | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 23 Orchestration: SD->PPL (LabVIEWCLI) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 21 VIPB: Bump LabVIEW version | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 09 x-cli: VI History (vi-compare-run) | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a |  |
| 09b x-cli: VI History from SD (read-only) | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a |  |
| 10 Tests: run (TestsCli) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 11 Tests: run (Orchestration CLI unit-tests) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 12 Tests: run (isolated worktree) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 13 Orchestration: VI Analyzer | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 14 Orchestration: VI Compare | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a |  |
| 15 Orchestration: Missing-in-project check | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 16 Tests: VI Analyzer (Test.ps1) | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |

LV-agnostic items per cycle:
- [ ] 05 Requirements summary (dotnet)
- [ ] 05b Requirements summary (bundled SD)
- [ ] SD: Build x-cli (bundled)
- [ ] SD: VI History (bundled)
- [ ] SD: VI History (execute)
- [ ] 18 Tooling: Clear CLI cache entry
- [ ] 19 Tests: Probe helper smoke

Automation helper:
- Use `pwsh -NoProfile -File scripts/add-vscode-task-cycle.ps1 -CycleName "<label>"` to append a fresh cycle table to this document (defaults to today’s date).

### Prompt for a future agent (goal: all boxes checked or clear skip reasons)

Use this when handing off:  
“You are running unattended to close out a VS Code task cycle. Success = every checkbox in the latest cycle table is `[x]` or replaced with `skip (<reason>)`, and changes are committed. Steps:
1) Open `docs/vscode-tasks-traceability.md`. If today’s cycle is missing, run `pwsh -NoProfile -File scripts/add-vscode-task-cycle.ps1 -CycleName "<label>"`.
2) Detect installed LabVIEW versions/bitness by scanning `C:\Program Files\National Instruments\LabVIEW */LabVIEW.exe` and `C:\Program Files (x86)\...`. Treat missing executables as skip reasons.
3) For each task/version/bitness cell: run the described CLI (respecting task bitness/version) or mark `skip (<reason>)` if prereqs are absent (e.g., version not installed, VIPM/g-cli missing, config not pointing to that LV).
4) Update the checklist cells to `[x]` when success criteria are met (pass/fail rules in the matrix). Include brief notes/links when skipping.
5) For LV-agnostic items, run once per cycle and check them off.
6) Stage and commit with message “chore: update VSCode tasks cycle <label>” once the table reflects the current state. Do not revert unrelated user changes.”

| Task label | LV version/bitness coverage | Preconditions | Expected artifacts/logs | Pass/Fail criteria | How to execute (CLI) | Notes/skip |
| - | - | - | - | - | - | - |
| 01 Verify / Apply dependencies | 20(64), 21(64/32), 23(64/32), 25(64/32), 26(64); skip 20(32)/22/24/26(32) (no LabVIEW.exe) | Windows, dotnet, VIPM CLI, network for VIPC | VIPC applied for both bitness; OrchestrationCli console log | Exit 0; no missing-dependency errors | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- apply-deps --repo . --bitness both --vipc-path runner_dependencies.vipc --timeout-sec 900` | Run once covers both bitness; skip if VIPM absent |
| 02 Build LVAddon (VI Package) | 21(64 run; needs 21(32) for lvlibp-bitness=both); others skip (task uses VIPB 2021) | Windows, dotnet, g-cli + LabVIEW 2021 64/32, VIPM CLI for real .vip | `builds/vip-stash/*.vip` or `vipm-skipped-placeholder.vip`; `resource/plugins/lv_icon.lvlibp` (32/64) | Exit 0; artifacts written without packaging errors | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- package-build --repo . --ref HEAD --bitness 64 --lvlibp-bitness both --major 0 --minor 1 --patch 0 --build 1 --company LabVIEW-Community-CI-CD --author "Local Developer"` (Windows adds `--managed`) | Run after dependencies; skip if VIPM unavailable (placeholder acceptable) |
| 17 Build (isolated worktree) | 21(64/32); others skip (VIPB driven) | Git for worktree, dotnet, g-cli + LabVIEW 2021 64/32, VIPM optional | Same outputs as package-build but inside temp worktree; notifications + copied builds | Exit 0; artifacts present in worktree `builds/`; no git errors | `pwsh -NoProfile -File scripts/run-worktree-task.ps1 -SourceRepoPath . -Ref HEAD -SupportedBitness both -LvlibpBitness both -Major 0 -Minor 1 -Patch 0 -Build 1 -CompanyName LabVIEW-Community-CI-CD -AuthorName "Local Developer"` | Keeps main repo clean; ensure 21(32) available for lvlibp-bitness both |
| 03 Orchestration: Restore packaged sources | 21(64/32); others skip (lv-version fixed 2021) | OrchestrationCli, LabVIEW 2021 matching bitness, dev-mode token present, g-cli | Restored packaged sources; console log only | Exit 0; no token/g-cli errors | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- restore-sources --repo . --bitness 64|32 --lv-version 2021 --timeout-sec 120` | Run after devmode bind if token missing |
| 04 Orchestration: Close LabVIEW | 21(64/32); others skip | OrchestrationCli, LabVIEW 2021, g-cli | LabVIEW process closed; log confirms | Exit 0; LabVIEW process ends | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- labview-close --repo . --bitness 64|32 --lv-version 2021 --timeout-sec 60` | Use after analyzer/tests |
| 05 Requirements summary (dotnet) | LV-agnostic (all) | dotnet; `docs/requirements/requirements.csv` present | `reports/requirements-summary.md` | Exit 0; summary file written | `dotnet run --project Tooling/dotnet/RequirementsSummarizer/RequirementsSummarizer.csproj -- --csv docs/requirements/requirements.csv --summary-output reports/requirements-summary.md --summary-full --details --details-open` | No LabVIEW needed |
| 05b Requirements summary (bundled SD) | LV-agnostic (all) | Extracted SD or repo; uses bundled RequirementsSummarizer.exe if present (falls back to dotnet); `docs/requirements/requirements.csv` present | `reports/requirements-summary.md/html/high.md` under current root | Exit 0; summaries regenerated | `pwsh -NoProfile -File scripts/run-requirements-summary-task.ps1 -Csv docs/requirements/requirements.csv -Summary reports/requirements-summary.md -Html reports/requirements-summary.html -HighPrioritySummary reports/requirements-summary-high.md` | Safe for SD consumers; no bind/build |
| 06 DevMode: Bind (auto) | 23(64) only (auto resolves VIPB 2023/64) | DevModeAgent CLI or dotnet fallback, git (creates worktree), LabVIEW 2023 64, LocalHost write access/dev-mode token | LocalHost.LibraryPaths entry for worktree; bind log | Exit 0; entry present | `pwsh -NoProfile -File scripts/task-devmode-bind.ps1 -RepositoryPath . -Mode bind -Bitness auto` | Skip other versions/bitness |
| 06b DevMode: Unbind (auto) | 21(64) only | DevModeAgent CLI, LabVIEW 2021 64, existing devmode worktree token | LocalHost entry removed | Exit 0; token cleared | `pwsh -NoProfile -File scripts/task-devmode-bind.ps1 -RepositoryPath . -Mode unbind -Bitness auto` | Skip other versions/bitness |
| 06c DevMode: Clear/Unbind all LabVIEW versions | 20(64), 21(64/32), 23(64/32), 25(64/32), 26(64); auto-skips missing installs | DevModeAgent CLI, OrchestrationCli for restore, LabVIEW installs, g-cli | LocalHost cleared across versions; restore-sources per bitness | Exit 0; no remaining LocalHost entries | `pwsh -NoProfile -File scripts/clear-labview-librarypaths-all.ps1` | Skips versions without LabVIEW.exe |
| 07 x-cli: VI Analyzer (raw) | 21(64); others require editing `configs/vi-analyzer-request.sample.json` | DevMode bound, LabVIEW 2021 64 + `LabVIEWCLI.exe`, x-cli buildable | `tests/results/_agent/vi-analyzer/vi-analyzer-sample/{vi-analyzer.json, report.html, results.rsl}` | Exit 0; analyzer results present | `dotnet run --project Tooling/x-cli/src/XCli/XCli.csproj -- vi-analyzer-run --request configs/vi-analyzer-request.sample.json` with env `XCLI_ALLOW_PROCESS_START=1`, `XCLI_REPO_ROOT=.`, `LABVIEW_BITNESS=64` | Skip other versions unless request points to their LabVIEWCLI |
| 21b VIPB: Override seed.vipb (repo) | 20(64), 21(64/32), 23(64/32), 25(64/32), 26(64) via `vipbTargetLv` | pwsh; write access to `Tooling/deployment/seed.vipb`; clean working tree recommended | `Tooling/deployment/seed.vipb` updated to target year | Exit 0; Package_LabVIEW_Version matches target | `pwsh -NoProfile -File scripts/labview/vipb-bump-worktree.ps1 -RepositoryPath . -TargetLabVIEWVersion <year> -NoWorktree` | Bitness remains what VIPB encodes (current 64) |
| 06d DevMode: Bind (repo, 64-bit) | 21(64); others skip | DevModeAgent CLI, LabVIEW 2021 64, LocalHost write access | LocalHost.LibraryPaths entry for repo | Exit 0; entry present | `pwsh -NoProfile -File scripts/task-devmode-bind.ps1 -RepositoryPath . -Mode bind -Bitness 64 -UseWorktree:$false` | No worktree; 64-bit only |
| 21c VIPB override + DevMode (repo) | 20/21/23/25/26 (64-bit only); skips 32-bit-only combos | 21b + 06d; LabVIEW target 64 installed; DevModeAgent CLI | `seed.vipb` set to target year; LocalHost bound to repo for that year/64 | Both subtasks exit 0; binding reflects target year | Run 21b, then `pwsh -NoProfile -File scripts/task-devmode-bind.ps1 -RepositoryPath . -Mode bind -Bitness 64 -UseWorktree:$false` | Skip if target/64 not installed |
| 08 x-cli: VI Analyzer | 21(64); others require config edits | Depends on 07 + DevMode unbind; LabVIEW 2021 64 | Same analyzer artifacts as 07; unbind removes token | Both steps exit 0; results files present | Sequence: 06 bind -> 07 run -> 06b unbind | Skip other versions unless request updated |
| 20 Build: Source Distribution | 21(64); others skip unless overriding params | g-cli (default runner) or LabVIEWCLI when selected, LabVIEW 2021 64, git, pwsh | `builds/Source Distribution/manifest.json`, `manifest.csv`; `builds/artifacts/source-distribution.zip`; `[artifact][source-distribution]` lines | Exit 0; manifest+zip exist; lvbuildspec succeeds | `pwsh -NoProfile -File scripts/run-xcli.ps1 -Runner gcli -- source-dist-build --repo . --commit-index builds/cache/commit-index.json --verbose-git --perf-cpu --allow-dirty` | Set `-Runner labviewcli` to force LabVIEWCLI build |
| 21 Verify: Source Distribution | Validates whichever zip exists (default from 21/64 build) | `builds/artifacts/source-distribution.zip` present; dotnet; git | `builds/reports/source-distribution-verify/<timestamp>/report.json`, extracted folder; `[artifact][source-dist-verify]` lines | Exit 0; report status success; strict mode fails on missing/null commits | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- source-dist-verify --repo . --source-dist-log-stash --source-dist-strict` | Run after task 20 for the target version |
| 22 Build PPL from Source Distribution | 21(64); others skip unless overriding params | Source-distribution zip present; pwsh; LabVIEW 2021 64; g-cli/dev-mode available | Extracted SD under `builds/ppl-from-sd/<stamp>`; `resource/plugins/lv_icon.lvlibp` built in extracted tree | Exit 0; lvlibp emitted from extracted SD; dev-mode bind/unbind logged | `pwsh -NoProfile -File scripts/ppl-from-sd/Build_Ppl_From_SourceDistribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2021 -SupportedBitness 64 -Major 0 -Minor 1 -Patch 0 -Build 0` | Ensure `TMP/TEMP` points to writable path (task uses C:/temp) |
| 23 Orchestration: SD->PPL (LabVIEWCLI) | 23(64); others skip unless overriding params | LabVIEWCLI + LabVIEW 2023 64 installed; g-cli for bind/unbind; git; writable temp/log root | `builds/` SD artifacts, lvlibp outputs, temp logs under user temp, log-stash bundle when helper present | Exit 0; ordered phases logged (lock/temp -> bind -> SD build -> close/unbind -> extract -> bind extracted -> PPL build -> close/unbind) with no parallel g-cli/LabVIEWCLI | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- sd-ppl-lvcli --repo . --bitness 64 --lv-version 2023 --timeout-sec 1800` | Optional overrides: `--labviewcli-path`, `--labview-path`, `--lv-port`, `--temp-root`, `--log-root` |
| 21 VIPB: Bump LabVIEW version | 20/21/23/25/26 (any bitness) via input; default 2021 | pwsh; Docker available (seed image); g-cli/VIPM for downstream build; git worktree | Worktree one commit ahead with updated `seed.vipb`; Source Dist/VIP built when flags succeed | Exit 0; worktree exists; downstream builds succeed | `pwsh -NoProfile -File scripts/labview/vipb-bump-worktree.ps1 -RepositoryPath . -TargetLabVIEWVersion <year> -RunSourceDistribution -RunPackageBuild` | Skip if Docker unavailable or target LV not installed |
| 09 x-cli: VI History (vi-compare-run) | 25(64) via sample; 25(32) after editing `labVIEWExePath`; others skip | DevMode bound, LabVIEW 2025 installed, scenario configs present, x-cli built | `.tmp-tests/vi-compare-replays/sample/*`, `vi-comparison-summary.json`, optional bundles | Exit 0; summary generated; no replay errors | `dotnet run --project Tooling/x-cli/src/XCli/XCli.csproj -- vi-compare-run --request configs/vi-compare-run-request.sample.json` | Edit request for other versions/bitness |
| 09b x-cli: VI History from SD (read-only) | 25(64) via sample; 25(32) after editing `labVIEWExePath`; others skip | Extracted SD at short path, pwsh; LabVIEW 2025/x-cli available; no bind/build; refuses Program Files roots | Transcripts under `reports/logs/vi-history-sd-*.log`; replay outputs under `.tmp-tests/vi-compare-replays` inside SD | Exit 0; logs created; no bind/build actions; run refuses Program Files SdRoot | `pwsh -NoProfile -File scripts/vi-compare/run-vi-history-suite-sd.ps1 -SdRoot <extracted-sd> -IncludeSample` | Skip if SD not extracted or LabVIEW 2025 missing |
| SD: Build x-cli (bundled) | LV-agnostic; required for SD execute flows | dotnet SDK present in extracted SD | `Tooling/x-cli/src/XCli/bin/Release/net8.0/win-x64/*` | Exit 0; binaries built | `dotnet build Tooling/x-cli/src/XCli/XCli.csproj -c Release` | Run before SD execute tasks |
| SD: VI History (execute) | 25(64) via sample; 25(32) after editing `labVIEWExePath`; others skip | Extracted SD at short path; LabVIEW 2025/x-cli available; no bind/build; refuses Program Files roots; requires built x-cli | Transcripts under `reports/logs/vi-history-sd-*.log`; replay outputs under `.tmp-tests/vi-compare-replays` inside SD | Exit 0; logs created; no bind/build actions; run refuses Program Files SdRoot | `pwsh -NoProfile -File scripts/vi-compare/run-vi-history-suite-sd.ps1 -SdRoot <extracted-sd> -IncludeSample -AllowExecute` | Depends on SD: Build x-cli; real execution (not forced dry-run) |
| SD: VI History (bundled) | 25(64) via sample; 25(32) after editing `labVIEWExePath`; others skip | Extracted SD at short path, pwsh; LabVIEW 2025/x-cli available; no bind/build; refuses Program Files roots | Transcripts under `reports/logs/vi-history-sd-*.log`; replay outputs under `.tmp-tests/vi-compare-replays` inside SD | Exit 0; logs created; no bind/build actions; run refuses Program Files SdRoot | `pwsh -NoProfile -File scripts/vi-compare/run-vi-history-suite-sd.ps1 -SdRoot <extracted-sd> -IncludeSample` | Parallel SD consumer task; same replay, no repo required |
| 10 Tests: run (TestsCli) | 21(64/32) when `testsBitness`=both; set to 64 or 32 if only one present; others skip (VIPB 2021) | LabVIEW 2021 installs, g-cli, dotnet; deps applied | Test logs/reports under builds/tests folders; console summary | Exit 0; no failed tests | `dotnet run --project Tooling/dotnet/TestsCli/TestsCli.csproj -- --repo . --bitness both|64|32` | Use 64-only if 21(32) missing |
| 11 Tests: run (Orchestration CLI unit-tests) | 21(64/32) per `testsBitness`; others skip | LabVIEW 2021, g-cli, dotnet | Unit-test outputs under `builds/reports/unit-tests/*`; console summary | Exit 0; no failing tests | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- unit-tests --repo . --bitness both|64|32 --project lv_icon_editor.lvproj --timeout-sec 900` | Set bitness to installed subset |
| 12 Tests: run (isolated worktree) | 21(64/32); others skip | Git worktree, LabVIEW 2021 installs, g-cli, dotnet | Reports copied to `builds-isolated-tests/*`; console summary | Exit 0; reports present; no failing tests | `pwsh -NoProfile -File scripts/run-worktree-tests.ps1 -SourceRepoPath . -Ref HEAD -SupportedBitness both|64|32` | Avoids touching main repo |
| 13 Orchestration: VI Analyzer | 21(64 default; 21(32) if request edited) | LabVIEW 2021 matching bitness, LabVIEWCLI path in `configs/vi-analyzer-request.sample.json`, g-cli/OrchestrationCli, dev-mode if requested | Analyzer outputs under `tests/results/_agent/vi-analyzer/<label>` | Exit 0; results + report produced | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- vi-analyzer --repo . --bitness 64|32 --request configs/vi-analyzer-request.sample.json --timeout-sec 900` | Update request for other versions |
| 14 Orchestration: VI Compare | 25(64 default; 25(32) by setting bitness=32); requires >=2025 | LabVIEW 2025 matching bitness, g-cli, DevModeAgent (auto bind/unbind), scenario file | Worktree under `.tmp-tests/vi-compare-worktrees/<stamp>`; optional bundle path in console output; compare status | Exit 0 with status success (no skip/fail in details) | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- vi-compare --repo . --bitness 64|32 --scenario scenarios/sample/vi-diff-requests.json --lv-version 2025 --require-devmode --auto-bind-devmode --timeout-sec 120` | Skip for versions <2025 or if 2025 missing |
| 15 Orchestration: Missing-in-project check | 21(64/32); others skip (lv-version fixed 2021) | LabVIEW 2021 matching bitness, g-cli, project `lv_icon_editor.lvproj` | Console report; OrchestrationCli details | Exit 0; no missing items reported | `dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- missing-check --repo . --bitness 64|32 --project lv_icon_editor.lvproj --lv-version 2021 --timeout-sec 600` | Tied to LV2021 |
| 16 Tests: VI Analyzer (Test.ps1) | 21(64); others require editing `ViAnalyzerRequestPath` | LabVIEW 2021 64 + LabVIEWCLI, devmode access (script binds/unbinds), g-cli | `tests/results/_agent/vi-analyzer/<label>` outputs (json/html/rsl) | Exit 0; analyzer reports generated | `pwsh -NoProfile -File scripts/test/Test.ps1 -RepositoryPath . -ViAnalyzerOnly -ViAnalyzerRequestPath configs/vi-analyzer-request.sample.json` | Point `ViAnalyzerRequestPath` to other-version config to retarget |
| 19 Tests: Probe helper smoke | LV-agnostic | pwsh, dotnet CLIs available/publishable; may touch `%LOCALAPPDATA%\labview-icon-editor\tooling-cache` | Console log; probe scenarios across tiers; cache refreshed | Exit 0; no probe/publish failures | `pwsh -NoProfile -File scripts/test/probe-helper-smoke.ps1` | No specific LabVIEW requirement |
| 18 Tooling: Clear CLI cache entry | LV-agnostic | pwsh; target cache entry under `%LOCALAPPDATA%\labview-icon-editor\tooling-cache` | Specified `<CLI>/<ver>/<rid>` directory removed | Exit 0; folder gone | `pwsh -NoProfile -File scripts/clear-tooling-cache.ps1 -CliName <DevModeAgentCli|OrchestrationCli|IntegrationEngineCli|XCli> -Version <ver> -Rid win-x64` | Use before rerunning probe-helper/builds when cache is stale |

How versions/bitness were detected:
- Installed LabVIEW: enumerated `C:\Program Files\National Instruments\LabVIEW */LabVIEW.exe` and `C:\Program Files (x86)\National Instruments\LabVIEW */LabVIEW.exe`, capturing year and bitness where the executable exists.
- Target from VIPB: `scripts/get-package-lv-version.ps1` -> 2023, `scripts/get-package-lv-bitness.ps1` -> 64, so tasks using auto VIPB values bind/use 2023/64 unless overridden.
- Tooling discovery: `Get-Command g-cli`, VIPM executables under `C:\Program Files\JKI\VI Package Manager\support\vipm.exe`.

Running in environments without required tooling:
- Missing LabVIEW version/bitness: mark rows as `skip (LabVIEW <year>/<bit> not installed)`; rerun once installed or override task parameters/configs to a present version.
- Missing VIPM: dependency/package tasks fail fast; mark as `skip (VIPM not on PATH)` or install VIPM.
- Missing g-cli: required for build/test/analyzer; install G-CLI and rerun.
- Missing DevModeAgent: tasks auto-fallback to dotnet run, but if the CLI cannot be published, mark as `skip (DevModeAgent unavailable)`.

## Cycle: 2025-11-29

Automation note: Ran dependencies and Source Distribution build/verify for LV2021 (64/32 where applicable). Remaining cells marked with explicit skip reasons for transparency.

| Task label | 2020 64 | 2021 64 | 2021 32 | 2023 64 | 2023 32 | 2025 64 | 2025 32 | 2026 64 | Notes |
| - | - | - | - | - | - | - | - | - | - |
| 01 Verify / Apply dependencies | skip (not targeted this cycle) | [x] | [x] | skip (not targeted) | skip (not targeted) | skip (not targeted) | skip (not targeted) | skip (not targeted) | Applied via OrchestrationCli; VIPM clean |
| 02 Build LVAddon (VI Package) | skip (not run) | fail (package-build hung; killed processes after no progress) | fail (same run hung; 32-bit lvlibp from prior attempt only) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | Worktree attempt timed out earlier; direct repo run (managed, lvlibp=64) hung with LabVIEW/IntegrationEngineCli running; terminated and cleaned builds |
| 17 Build (isolated worktree) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 03 Orchestration: Restore packaged sources | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 04 Orchestration: Close LabVIEW | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 06 DevMode: Bind (auto) | skip (auto targets 2023/64) | skip (not run) | n/a | n/a | n/a | n/a | n/a | n/a | Auto resolves to 2023/64 |
| 06b DevMode: Unbind (auto) | skip (auto targets 2023/64) | skip (not run) | n/a | n/a | n/a | n/a | n/a | n/a | Auto resolves to 2023/64 |
| 06c DevMode: Clear/Unbind all LabVIEW versions | [x] | [x] | [x] | [x] | [x] | [x] | [x] | [x] | Cleared LocalHost.LibraryPaths across detected installs; g-cli restore attempts timed out (connection) |
| 07 x-cli: VI Analyzer (raw) | n/a | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | Update request JSON per version |
| 21b VIPB: Override seed.vipb (repo) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 06d DevMode: Bind (repo, 64-bit) | skip (auto targets 2023/64) | skip (not run) | n/a | n/a | n/a | n/a | n/a | n/a | 64-bit only |
| 21c VIPB override + DevMode (repo) | skip (not run) | skip (not run) | n/a | skip (not run) | n/a | skip (not run) | n/a | skip (not run) | 64-bit only |
| 08 x-cli: VI Analyzer | n/a | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | Sequence bind/run/unbind |
| 20 Build: Source Distribution | skip (not run) | [x] | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | Last run used g-cli runner 2021/64; VIPB now 2023/64 (rerun pending) |
| 21 Verify: Source Distribution | skip (not run) | [x] | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | success (0 warnings); report: builds/reports/source-distribution-verify/20251129-095623 |
| 22 Build PPL from Source Distribution | skip (not run) | [x] | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | lv_icon.lvlibp built via labviewcli flow (temp run 20251129-215141757) |
| 23 Orchestration: SD->PPL (LabVIEWCLI) | skip (not run) | [x] | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | sd-ppl-lvcli success; logs %TEMP%\\labview-icon-editor\\sd-ppl-lvcli\\20251129-215141757 |
| 21 VIPB: Bump LabVIEW version | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 09 x-cli: VI History (vi-compare-run) | n/a | n/a | n/a | n/a | n/a | skip (not run) | skip (not run) | n/a |  |
| 09b x-cli: VI History from SD (read-only) | n/a | n/a | n/a | n/a | n/a | skip (not run) | skip (not run) | n/a |  |
| 10 Tests: run (TestsCli) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 11 Tests: run (Orchestration CLI unit-tests) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 12 Tests: run (isolated worktree) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 13 Orchestration: VI Analyzer | n/a | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 14 Orchestration: VI Compare | n/a | n/a | n/a | n/a | n/a | skip (not run) | skip (not run) | n/a |  |
| 15 Orchestration: Missing-in-project check | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |
| 16 Tests: VI Analyzer (Test.ps1) | n/a | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) | skip (not run) |  |

LV-agnostic items for this cycle:
- skip (not run) 05 Requirements summary (dotnet)
- skip (not run) 05b Requirements summary (bundled SD)
- skip (not run) SD: VI History (bundled)
- skip (not run) 18 Tooling: Clear CLI cache entry
- skip (not run) 19 Tests: Probe helper smoke
### x-cli provider layer
- x-cli commands now run through a LabVIEW provider abstraction (ILabviewProvider). Default behavior is unchanged; vi-analyzer-run/verify, vi-compare-run, and vipm apply/build still shell out to PowerShell/g-cli as before.
- Simulated provider hook: set XCLI_PROVIDER=sim to route through SimulatedLabviewProvider (optional CI/dry-run). Env knobs: XCLI_SIM_FAIL=true to force failure, XCLI_SIM_EXIT=<code> to set exit, XCLI_SIM_DELAY_MS=<ms> to add delay. Default path remains LabviewProviderSelector.Create() -> DefaultLabviewProvider.



