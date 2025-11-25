# LabVIEW Icon Editor

Open-source Icon Editor for LabVIEW, packaged as a `.vip`. This repo includes VS Code tasks that automate building the editor and packaging it with minimal inputs.

## Build with VS Code Tasks

Prerequisites
- Windows with LabVIEW 2021 SP1 (32-bit and/or 64-bit for the bitness you need)
- VIPM CLI (`vipm`) on PATH
- PowerShell 7+, Git with full history (for versioning)

Steps
1) In VS Code: Terminal → Run Task → **Build/Package VIP**.
2) Choose `buildMode`:
   - `vip+lvlibp`: full pipeline (build lvlibp(s), package 64-bit VIP). Set `lvlibpBitness=64` to skip 32-bit steps; use `32` to build/package 32-bit only.
   - `vip-single`: package an existing lvlibp for the chosen bitness.
3) Outputs:
   - VIP: `builds/VI Package/` (or under `builds/` if created there)
   - lvlibp (lvlibp-only task): `resource/plugins/lv_icon.lvlibp` (overwrites each run)

VIPM not available?
- If `vipm` is not on PATH, the build skips VIPC/VIPM steps, still builds the lvlibp, and writes a placeholder `builds/VI Package/vipm-skipped-placeholder.vip` so you know packaging was skipped.
- After installing or exposing VIPM to PATH, delete the placeholder `.vip` and rerun the **Build/Package VIP** task to create the real package.

Behavior & defaults
- Versioning: MAJOR/MINOR/PATCH from latest tag; BUILD from commit count; commit hash embedded.
- Metadata: Company = git remote owner; Author = `git config user.name` (fallback to owner).
- VIPB: auto-detected (first `*.vipb` in repo); override with `-VipbPath` if needed.

More details: see `docs/vscode-tasks.md`.

### Build LVAddon (VI Package)

Use **Terminal → Run Task → Build LVAddon (VI Package)** in VS Code to run the isolated worktree build (`ie.ps1 -Command buil
d-worktree`). The task defaults to **bitness=64** for the top-level package, **LvlibpBitness=both** to produce 32-bit and 64-
bit packed libraries, and **version inputs** `Major=0`, `Minor=1`, `Patch=0`, `Build=1` (plus the default Company/Author meta
data). You can adjust these arguments in `.vscode/tasks.json` or by editing the task invocation before running it.

## Docs quicklinks
- Build & tasks: `docs/vscode-tasks.md`
- CI overview: `docs/ci-workflows.md`
- VIPM Docker helper: `Tooling/docker/vipm/README.md`
- Dev mode toggle: `scripts/set-development-mode/run-dev-mode.ps1` and `scripts/revert-development-mode/run-dev-mode.ps1`
- Tests: `docs/testing/policy.md` (and `Test/` for Pester)

