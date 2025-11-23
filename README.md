# LabVIEW Icon Editor

Open-source Icon Editor for LabVIEW, packaged as a `.vip`. This repo includes VS Code tasks that automate building the editor and packaging it with minimal inputs.

## Build with VS Code Tasks

Prerequisites
- Windows with LabVIEW 2021 SP1 (32-bit and/or 64-bit for the bitness you need)
- VIPM with `g-cli` on PATH
- PowerShell 7+, Git with full history (for versioning)

Steps
1) In VS Code: Terminal → Run Task → **Build/Package VIP**.
2) Choose `buildMode`:
   - `vip+lvlibp`: full pipeline (build lvlibp(s), package 64-bit VIP). Set `lvlibpBitness=64` to skip 32-bit steps; use `32` to build/package 32-bit only.
   - `vip-single`: package an existing lvlibp for the chosen bitness.
3) Outputs:
   - VIP: `builds/VI Package/` (or under `builds/` if created there)
   - lvlibp (lvlibp-only task): `resource/plugins/lv_icon.lvlibp` (overwrites each run)

Behavior & defaults
- Versioning: MAJOR/MINOR/PATCH from latest tag; BUILD from commit count; commit hash embedded.
- Metadata: Company = git remote owner; Author = `git config user.name` (fallback to owner).
- VIPB: auto-detected (first `*.vipb` in repo); override with `-VipbPath` if needed.

More details: see `docs/vscode-tasks.md`.

## Docs quicklinks
- Build & tasks: `docs/vscode-tasks.md`
- CI overview: `docs/ci-workflows.md`
- Dev mode toggle: `.github/actions/set-development-mode/run-dev-mode.ps1` and `.github/actions/revert-development-mode/run-dev-mode.ps1`
- Tests: `docs/testing/policy.md` (and `Test/` for Pester)
