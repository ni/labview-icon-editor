# LabVIEW Icon Editor

Open-source Icon Editor for LabVIEW, packaged as a `.vip`. This repo includes a VS Code task that automates building the editor and packaging it with minimal inputs.

## Build with VS Code Tasks

Prerequisites
- Windows with LabVIEW 2021 SP1 (32-bit and/or 64-bit for the bitness you need)
- VIPM CLI (`vipm`) on PATH
- PowerShell 7+, Git with full history (for versioning)

### Build LVAddon (VI Package)

Use **Terminal → Run Task → Build LVAddon (VI Package)** in VS Code to run the isolated worktree build (`scripts/ie.ps1 -Command build-worktree`) and package the icon editor; outputs land in `builds/VI Package/` (VIP artifact) and `resource/plugins/lv_icon.lvlibp` (overwritten for each bitness built).

VIPM not available?
- If `vipm` is not on PATH, the build skips VIPC/VIPM steps, still builds the lvlibp, and writes a placeholder `builds/VI Package/vipm-skipped-placeholder.vip` so you know packaging was skipped.
- After installing or exposing VIPM to PATH, delete the placeholder `.vip` and rerun the **Build LVAddon (VI Package)** task to create the real package.

More details: see `docs/vscode-tasks.md`.


## Docs quicklinks
- Build & tasks: `docs/vscode-tasks.md`
- CI overview: `docs/ci-workflows.md`
- VIPM Docker helper: `Tooling/docker/vipm/README.md`
- Dev mode toggle: `scripts/set-development-mode/run-dev-mode.ps1` and `scripts/revert-development-mode/run-dev-mode.ps1`
- Tests: `docs/testing/policy.md` (and `Test/` for Pester)

