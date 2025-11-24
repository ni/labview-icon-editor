# VS Code Tasks Catalog

Tasks live in `.vscode/tasks.json`. Run via VS Code: Terminal -> Run Task.

## Task List
- Dev Mode Bind (check + run) — Intent CLI plan+execute (default phrase `/devmode bind 2021 both force`).
- Dev Mode Bind (force overwrite) — Intent CLI with Force for overwriting other-path tokens.
- Dev Mode (interactive bind/unbind) — Guided PowerShell helper with prompts.
- Revert Dev Mode (LabVIEW) — Unbind/reset dev mode for the selected bitness.
- Set Dev Mode (LabVIEW) — Prep dev mode for a chosen bitness.
- Build/Package VIP (simulate) — `build_vip.ps1` simulate (64-bit).
- Build/Package VIP — `run-build-or-package.ps1` with selectable modes (VIP + lvlibp).
- Build pipeline (full simulate) — `run-build-or-package.ps1` end-to-end simulate (lvlibp both).
- Build (isolated worktree) — `scripts/worktree-build.ps1` with prompts for bitness/version/company/author.
- Build release asset (VI Package x64/x86/both) — `scripts/task-build-vip.ps1` (Bitness 64/32/both).
- Build PPL (simulate) — `scripts/run-build-lvlibp-task.ps1` simulate (64-bit).
- Build release asset (Packed Project Library x64/x86) — `scripts/run-build-lvlibp-task.ps1` (SupportedBitness 64/32).
- Analyze VI Package (Pester) — `analyze-vi-package/run-local.ps1` against `builds/VI Package/`.
- Requirements — RequirementsSummarizer (`dotnet run tools/RequirementsSummarizer`) to emit summary/full/json/html.
- Draft release — CI gate check, then trigger `draft-release.yml` with latest CI run ID.
- Test VIPM Docker — `Tooling/docker/vipm/test-vipm.ps1`.
- VIPM Docker Smoke — `Tooling/docker/vipm/smoke-vipm.ps1` for a specified VIPC.

## Coverage Matrix (placeholder)
Mark `[x]` when validated for a given year/OS. Test cases: Dev-mode tasks map to `TC-DEV-BIND-WIN/LNX`; intent tasks map to `TC-DEV-INTENT-WIN/LNX`; others use their own IDs as needed.

| Task                               | 2020 win | 2020 linux | 2021 win | 2021 linux | 2022 win | 2022 linux | 2023 win | 2023 linux | 2024 win | 2024 linux | 2025 win | 2025 linux | 2026 win | 2026 linux |
|------------------------------------|----------|------------|----------|------------|----------|------------|----------|------------|----------|------------|----------|------------|----------|------------|
| Dev Mode Bind (check + run)        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Dev Mode Bind (force overwrite)    | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Dev Mode (interactive bind/unbind) | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Revert Dev Mode (LabVIEW)          | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Set Dev Mode (LabVIEW)             | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build/Package VIP (simulate)       | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build/Package VIP                  | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build pipeline (full simulate)     | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build (isolated worktree)          | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build release asset (VIP x64)      | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build release asset (VIP x86)      | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build release asset (VIP both)     | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build PPL (simulate)               | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build PPL asset (x64)              | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Build PPL asset (x86)              | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Analyze VI Package (Pester)        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Requirements summarizer            | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Draft release                      | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| Test VIPM Docker                   | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
| VIPM Docker Smoke                  | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        | [ ]      | [ ]        |
