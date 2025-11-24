# VS Code task shortlist

Curated workspace tasks for the local workflows we actually reach for. The headless/defaulted and release/draft helpers were removed to keep the palette small; use the underlying scripts in `.github/actions` or `scripts/` when you need automation.

- **Analyze VI Package (Pester)** – runs the analyzer (`.github/actions/analyze-vi-package/run-local.ps1`) against a `.vip` artifact; prompts for the artifact path and minimum LabVIEW version.
- **Build/Package VIP** – choose artifact type via `buildMode` input:
  - `vip+lvlibp`: runs `.github/actions/build/Build.ps1` (apply VIPC, build lvlibp(s), package VIP).
  - `vip-single`: runs `scripts/build-vip-single-arch.ps1` to package a single-arch VIP using an existing lvlibp.
  - SemVer is **auto-derived from the latest git tag (vMAJOR.MINOR.PATCH)**; build number = commit count; Company = git remote owner; Author = `git config user.name` (fallback to owner); VIPB is auto-discovered (first `*.vipb`).
- **Build lvlibp (LabVIEW)** – builds the packed library with the resolved package version and selected bitness.
- **Set Dev Mode (LabVIEW)** / **Revert Dev Mode (LabVIEW)** – toggles development mode for the chosen LabVIEW bitness.

Run from `Terminal -> Run Task…` in VS Code (or `Ctrl/Cmd+Shift+B`), then pick the task.

## What each task does

- **Analyze VI Package (Pester)**  
  - Runs `.github/actions/analyze-vi-package/run-local.ps1` against the provided `.vip` path.  
  - Uses the `minLv` input to set the minimum LabVIEW version for the analyzer.

- **Build/Package VIP**  
  - Input `buildMode=full`: executes `.github/actions/build/Build.ps1`, which:  
    - Applies VIPC, builds lvlibp for the requested bitness (32+64 by default; set `lvlibpBitness=64` to skip 32-bit), updates display info, then packages the VIP.  
    - Auto-semver from latest tag; build number = commit count; commit hash from HEAD.  
    - Metadata defaults: Company = git remote owner; Author = `git config user.name` (fallback to owner). VIPB is auto-discovered (first `*.vipb`); override with `-VipbPath` if needed.  
    - If you only have LabVIEW 32-bit, set `lvlibpBitness=32` and the task will build/package 32-bit only.  
  - Input `buildMode=package-only`: executes `scripts/build-vip-single-arch.ps1`, which:  
    - Uses the auto-discovered VIPB, prunes the other arch, and packages a single-arch VIP.  
    - Assumes the target lvlibp already exists (use the lvlibp build task first).  
    - Same auto-semver/build/metadata defaults as above.

- **Build lvlibp (LabVIEW)**  
  - Resolves the package LabVIEW version via `scripts/get-package-lv-version.ps1`.  
  - Calls `.github/actions/build-lvlibp/Build_lvlibp.ps1` to create the packed library for the selected bitness.

- **Set Dev Mode / Revert Dev Mode (LabVIEW)**  
  - Calls the respective `run-dev-mode.ps1` wrappers to toggle development mode for the chosen bitness.  
  - No packaging or builds occur; this only changes LabVIEW’s dev-mode state.
