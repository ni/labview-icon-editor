# VS Code Tasks Catalog

All tasks defined in `.vscode/tasks.json`, grouped by purpose.

## Dev Mode (user-facing)
- Dev Mode Bind (check + run) — Intent CLI (plan+execute) for dev-mode bind; safe default.
- Dev Mode Bind (force overwrite) — Intent CLI with Force to overwrite existing dev-mode tokens.
- Dev Mode (interactive bind/unbind) — Guided PowerShell helper for bind/unbind.
- Revert Dev Mode (LabVIEW) — Unbind/reset dev mode for the selected bitness.

## Dev Mode Utilities (supporting)
- Set Dev Mode (LabVIEW) — `.github/actions/set-development-mode/run-dev-mode.ps1` for selected bitness (prep before builds/tests if needed).

## Build & Package
- Build/Package VIP (simulate) — `build_vip.ps1` in simulate mode (64-bit).
- Build/Package VIP — `run-build-or-package.ps1` with selectable modes (VIP + lvlibp).
- Build pipeline (full simulate) — `run-build-or-package.ps1` end-to-end simulate (lvlibp both).
- Build (isolated worktree) — `scripts/worktree-build.ps1` with prompts for bitness/version/company/author.
- Build release asset (VI Package x64) — `scripts/task-build-vip.ps1 -Bitness 64`.
- Build release asset (VI Package x86) — `scripts/task-build-vip.ps1 -Bitness 32`.
- Build release asset (VI Package 32 & 64 bits) — `scripts/task-build-vip.ps1 -Bitness both` (skip CI gate).
- Build PPL (simulate) — `scripts/run-build-lvlibp-task.ps1` simulate (64-bit).
- Build release asset (Packed Project Library, x64) — `scripts/run-build-lvlibp-task.ps1 -SupportedBitness 64`.
- Build release asset (Packed Project Library, x86) — `scripts/run-build-lvlibp-task.ps1 -SupportedBitness 32`.

## Analyze & Requirements
- Analyze VI Package (Pester) — `analyze-vi-package/run-local.ps1` against `builds/VI Package/`.
- Requirements — RequirementsSummarizer (`dotnet run tools/RequirementsSummarizer`) to emit summary/full/json/html into `reports/`.

## Release Ops
- Draft release — checks CI gate, then triggers `draft-release.yml` using the latest CI run ID.

## Docker (VIPM)
- Test VIPM Docker — `Tooling/docker/vipm/test-vipm.ps1` with repo root.
- VIPM Docker Smoke — `Tooling/docker/vipm/smoke-vipm.ps1` for a specified VIPC.
