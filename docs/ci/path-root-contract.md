# Cross-OS Path Root Contract

## Summary
This repository uses a canonical root contract that is shared across host and container jobs.

- Canonical root: `LVIE_REPO_ROOT`
- Canonical project path: `LVIE_PROJECT_PATH`
- Canonical project-relative path: `LVIE_PROJECT_RELATIVE_PATH`

Legacy aliases remain supported for compatibility.

## Canonical Variables
- `LVIE_REPO_ROOT`
  - Absolute path to the repository root in the current runtime.
- `LVIE_PROJECT_RELATIVE_PATH`
  - Project path relative to `LVIE_REPO_ROOT`.
  - Default: `lv_icon_editor.lvproj`.
- `LVIE_PROJECT_PATH`
  - Absolute project path.
  - When not explicitly set, it is derived from `LVIE_REPO_ROOT` + `LVIE_PROJECT_RELATIVE_PATH`.

## Compatibility Aliases
- `REPO_ROOT` aliases `LVIE_REPO_ROOT` for host-oriented jobs.
- `WORKSPACE_ROOT` aliases `LVIE_REPO_ROOT` for container-oriented jobs.
- `PROJECT_PATH` aliases `LVIE_PROJECT_PATH`.

## Resolution Precedence
1. Canonical `LVIE_*` variable.
2. Legacy alias.
3. Script default.

Project path resolution follows:
1. `LVIE_PROJECT_PATH`
2. `PROJECT_PATH`
3. `LVIE_REPO_ROOT` + `LVIE_PROJECT_RELATIVE_PATH` (or default `lv_icon_editor.lvproj`)

## Cross-OS Examples
- Linux container
  - `LVIE_REPO_ROOT=/workspace`
  - `LVIE_PROJECT_RELATIVE_PATH=lv_icon_editor.lvproj`
  - `LVIE_PROJECT_PATH=/workspace/lv_icon_editor.lvproj`
- Windows container
  - `LVIE_REPO_ROOT=C:\workspace`
  - `LVIE_PROJECT_RELATIVE_PATH=lv_icon_editor.lvproj`
  - `LVIE_PROJECT_PATH=C:\workspace\lv_icon_editor.lvproj`
- Self-hosted worktree job
  - `LVIE_REPO_ROOT=C:\actions-runner\_work\lvie\w\ci-<jobhash>-<bitness>-<runid>-<attempt>`
  - `LVIE_PROJECT_PATH=<LVIE_REPO_ROOT>\lv_icon_editor.lvproj`

## Notes
- `LVIE_WORKTREE_ROOT` is independent from this contract.
  - It controls where worktrees are created, not the active repo root.
- `Tooling/support/PathContract.ps1` is imported by `Tooling/container-parity/runlabview-windows.ps1` during Windows container parity runs via `powershell`.
  - Keep `Tooling/support/PathContract.ps1` compatible with Windows PowerShell 5.1 (do not add `#Requires -Version` at file scope).
  - If this contract is violated, Windows parity commonly fails with `ScriptRequiresUnmatchedPSVersion` before `MassCompile`/`ExecuteBuildSpec` begin.
- New scripts should resolve from canonical variables first and keep aliases for one full release cycle.
