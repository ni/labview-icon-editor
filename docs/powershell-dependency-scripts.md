# PowerShell Dependency Scripts

This document lists the PowerShell scripts used to build, test, and distribute the LabVIEW Icon Editor. Each script is a dependency in the tooling chain and can be called directly or by other scripts.

Local entrypoints enforce short-path worktree usage by default. If a script fails because the repo is not under the worktree root, use `Tooling\New-CIWorktree.ps1` or `Tooling\Invoke-InWorktree.ps1`. Set `LVIE_SKIP_WORKTREE_ROOT_CHECK=1` or pass `-SkipWorktreeRootCheck` only when you intentionally want to bypass the guard.

Per-run artifacts are written under `$WORKTREE_ROOT\artifacts\<runid>` when guardrails are active. Use `-RunId` or `-ArtifactRoot` to override, and `-CleanRoom` to purge known output folders before and after a run. Artifact roots are disabled by default inside GitHub Actions unless `LVIE_ENABLE_ARTIFACT_ROOT=1` (or an explicit `-ArtifactRoot`/`-RunId` is provided).

## Table of Contents

- [AddTokenToLabVIEW.ps1](#addtokentolabviewps1)
- [ApplyVIPC.ps1](#applyvipcps1)
- [Build.ps1](#buildps1)
- [Build_lvlibp.ps1](#build_lvlibpps1)
- [build_vip.ps1](#build_vipps1)
- [Close_LabVIEW.ps1](#close_labviewps1)
- [Invoke-MissingIEFilesFromLVInstall.ps1](#invoke-missingiefilesfromlvinstallps1)
- [ModifyVIPBDisplayInfo.ps1](#modifyvipbdisplayinfops1)
- [Prepare_LabVIEW_source.ps1](#prepare_labview_sourceps1)
- [Rename-file.ps1](#rename-fileps1)
- [RestoreSetupLVSource.ps1](#restoresetuplvsourceps1)
- [Set_Development_Mode.ps1](#set_development_modeps1)
- [RevertDevelopmentMode.ps1](#revertdevelopmentmodeps1)
- [RunUnitTests.ps1](#rununittestsps1)
- [Run-CICompositeLocal.ps1](#run-cicompositelocalps1)
- [Invoke-InWorktree.ps1](#invoke-inworktreeps1)
- [WorktreeGuard.ps1](#worktreeguardps1)
- [Invoke-Preflight.ps1](#invoke-preflightps1)

---

## AddTokenToLabVIEW.ps1
Adds a custom `LocalHost.LibraryPaths` token to the LabVIEW INI file so LabVIEW can find project libraries during development or builds. This script depends on `Tooling/deployment/Create_LV_INI_Token.vi`, which is not present in this repository, so it is not used by the development-mode automation.

## ApplyVIPC.ps1
Applies a `.vipc` **VI Package Configuration** to a specific LabVIEW version and bitness using g-cli. The `.vipc` is applied via VIPM and ensures required LabVIEW dependencies (including the G-CLI VIPM package) are installed before building.

## Build.ps1
Top-level script that orchestrates the full build. Cleans previous outputs, builds packed libraries for 32-bit and 64-bit, updates metadata, and produces the final `.vip` package. Depends on many of the other scripts listed here.

## Build_lvlibp.ps1
Invokes the "Editor Packed Library" build specification and embeds version information and commit identifiers into the resulting `.lvlibp`.

## build_vip.ps1
Modifies a `.vipb` file and builds the final VI Package with g-cli, using version data and display information provided by `Build.ps1`.

## Close_LabVIEW.ps1
Gracefully shuts down a running LabVIEW instance using g-cli's `QuitLabVIEW` command. Called throughout the pipeline to ensure LabVIEW exits cleanly.

## Invoke-MissingIEFilesFromLVInstall.ps1
Runs `VerifyIEPaths.vi` via g-cli to validate the LabVIEW Icon API installation. The VI writes a status file to the repo root (default: `missing_IE_paths.txt`). An empty file indicates success; a comma-separated list of paths indicates missing files and should be treated as a failure. The script deletes any prior status file before running, waits for a new one (with timeout), and then deletes or archives it after reading. Use `-StatusFileArchiveDirectory` to preserve a copy. Set `-ConnectTimeoutMs`, `-ProcessTimeoutMs`, and `-StatusFileTimeoutMs` to control g-cli and status-file timing behavior.

## ModifyVIPBDisplayInfo.ps1
Updates the display information inside a `.vipb` file and merges version and branding metadata. Typically called by `Build.ps1` before packaging.

## Prepare_LabVIEW_source.ps1
Runs `PrepareIESource.vi` to package the LabVIEW Icon API, rename `lv_icon.lvlibp` to `lv_icon.ship`, and set the INI token for development. Closes LabVIEW after execution (even on failure). Called by `Set_Development_Mode.ps1`. `PrepareIESource.vi` reports error `-593450` when development mode could not be set; treat this error code as the only authoritative indicator and avoid adding other indicators or helpers. When this failure occurs, the VI error source string prints a comma-separated list of missing paths (if any). An empty list indicates no missing paths were reported. Use `-ConnectTimeoutMs` and `-ProcessTimeoutMs` to control g-cli connection and execution timeouts.

## Rename-file.ps1
Renames the built packed libraries to the expected `lv_icon_x86.lvlibp` or `lv_icon_x64.lvlibp` names.

## RestoreSetupLVSource.ps1
Runs `RestoreSetupLVSource.vi` to unzip the LabVIEW Icon API, restore `lv_icon.ship` to `lv_icon.lvlibp`, and remove the INI token. Closes LabVIEW after execution (even on failure). Used by `RevertDevelopmentMode.ps1`. `RestoreSetupLVSource.vi` reports error `-593451` when development mode could not be reverted; treat this error code as the only authoritative indicator and avoid adding other indicators or helpers. When this failure occurs, the VI error source string prints a comma-separated list of missing paths (if any). An empty list indicates no missing paths were reported. Use `-ConnectTimeoutMs` and `-ProcessTimeoutMs` to control g-cli connection and execution timeouts.

## Set_Development_Mode.ps1
Configures the repository for development by invoking `Prepare_LabVIEW_source.ps1` for both bitnesses. Accepts `-ConnectTimeoutMs` and `-ProcessTimeoutMs` to pass through to g-cli.

## RevertDevelopmentMode.ps1
Undoes development mode by invoking `RestoreSetupLVSource.ps1` for both bitnesses. Helpful when leaving development or before distributing a build. Accepts `-ConnectTimeoutMs` and `-ProcessTimeoutMs` to pass through to g-cli.

## RunUnitTests.ps1
Runs unit tests through g-cli and outputs a table of results. Requires an explicit `.lvproj` path via `-ProjectPath`. Ensure the LUnit dependency is installed for the selected bitness (apply `runner_dependencies.vipc` for both 32-bit and 64-bit). Used in CI workflows.

## Run-CICompositeLocal.ps1
Runs a local CI parity sequence based on `ci-composite.yml`. This script validates Verify IE Paths, applies VIPC dependencies, runs missing-in-project checks and unit tests for the LabVIEW version declared in `.lvversion` (defaulting to 2021/21.0), 32- and 64-bit, builds packed libraries, and produces the VI package using the 64-bit install of that version. The script always runs both 64-bit and 32-bit steps for the selected LabVIEW version, and most steps can be skipped via switches. Outputs are stored under `TestResults/ci-local`. Use `-ConnectTimeoutMs`, `-ProcessTimeoutMs`, and `-StatusFileTimeoutMs` to tune g-cli and status-file timing for your machine.

## Invoke-InWorktree.ps1
Creates a short-path worktree and runs a command or script from that path. Use this when you want to keep artifacts isolated without manually creating worktrees. Accepts either `-Command` or `-ScriptPath`/`-ScriptArguments` and will reuse the configured worktree root.

## WorktreeGuard.ps1
Shared helper used by local entrypoints to enforce that `RepoRoot` is under the configured worktree root. Supports `-SkipWorktreeRootCheck` and `LVIE_SKIP_WORKTREE_ROOT_CHECK=1` for explicit bypass scenarios.

## Invoke-Preflight.ps1
Shared preflight used by local entrypoints. Enforces worktree root usage, creates per-run artifact roots, logs run context, and supports `-AutoWorktree` and `-CleanRoom` options.

## Run-CICompositeLocal.ps1
Runs a local CI parity sequence based on `ci-composite.yml`. This script validates Verify IE Paths, applies VIPC dependencies, runs missing-in-project checks and unit tests for LabVIEW 2021 (32- and 64-bit), builds packed libraries, and produces the VI package using LabVIEW 2021 (64-bit). The script always runs both 64-bit and 32-bit steps for LabVIEW 2021, and most steps can be skipped via switches. Outputs are stored under `TestResults/ci-local`. Use `-ConnectTimeoutMs`, `-ProcessTimeoutMs`, and `-StatusFileTimeoutMs` to tune g-cli and status-file timing for your machine.

