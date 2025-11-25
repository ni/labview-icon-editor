# VS Code Tasks Catalog

Generated from `scripts/tasks-coverage.json`. Run `python scripts/generate-tasks-coverage.py` to refresh.

New single entry point: `pwsh -File scripts/ie.ps1 <command>` mirrors the tasks below without passing nested script paths (e.g., `build-worktree`, `build-pipeline`, `build-lvlibp`, `build-vip`, `apply-vipc`, `dev-bind`, `dev-set`, `dev-revert`, `dev-force-clean`).

## Task List
- Dev Mode Bind (check + run) — Intent CLI plan+execute for dev-mode bind; default phrase `/devmode bind 2021 both force`
- Dev Mode Bind (force overwrite) — Intent CLI with Force to overwrite existing tokens (only when INI points elsewhere)
- Dev Mode (interactive bind/unbind) — Guided PowerShell helper with prompts
- Revert Dev Mode (LabVIEW) — Unbind/reset dev mode for the selected bitness
- Set Dev Mode (LabVIEW) — Prep dev mode for a chosen bitness
- Build/Package VIP (simulate) — `build_vip.ps1` simulate (64-bit)
- Build/Package VIP — `run-build-or-package.ps1` with selectable modes (VIP + lvlibp)
- Build pipeline (full simulate) — `run-build-or-package.ps1` end-to-end simulate (lvlibp both)
- Build (isolated worktree) - `scripts/worktree-build.ps1` (task uses fixed defaults). Worktree folder name uses the short hash of the ref (e.g., `lv-ie-worktree-<hash>`); if the hash cannot be resolved, it logs a message and falls back to a random suffix.
- Build release asset (VI Package x64) — `scripts/task-build-vip.ps1 -Bitness 64`
- Build release asset (VI Package x86) — `scripts/task-build-vip.ps1 -Bitness 32`
- Build release asset (VI Package 32 & 64 bits) — `scripts/task-build-vip.ps1 -Bitness both` (skip CI gate)
- Build PPL (simulate) — `scripts/run-build-lvlibp-task.ps1` simulate (64-bit)
- Build release asset (Packed Project Library, x64) — `scripts/run-build-lvlibp-task.ps1 -SupportedBitness 64`
- Build release asset (Packed Project Library, x86) — `scripts/run-build-lvlibp-task.ps1 -SupportedBitness 32`
- Analyze VI Package (Pester) — `analyze-vi-package/run-local.ps1` against `builds/VI Package/`
- Requirements — RequirementsSummarizer (`dotnet run tools/RequirementsSummarizer`) to emit summary/full/json/html
- Draft release — Checks CI gate, then triggers `draft-release.yml` using the latest CI run ID
- Test VIPM Docker — `Tooling/docker/vipm/test-vipm.ps1`
- VIPM Docker Smoke — `Tooling/docker/vipm/smoke-vipm.ps1` for a specified VIPC

## Coverage Matrix
Mark cells by setting coverage entries in `scripts/tasks-coverage.json` (e.g., `"pass"`).

| Task | 2020 win | 2020 linux | 2021 win | 2021 linux | 2022 win | 2022 linux | 2023 win | 2023 linux | 2024 win | 2024 linux | 2025 win | 2025 linux | 2026 win | 2026 linux |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Dev Mode Bind (check + run) | [ ] | [ ] | [x] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Dev Mode Bind (force overwrite) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Dev Mode (interactive bind/unbind) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Revert Dev Mode (LabVIEW) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Set Dev Mode (LabVIEW) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build/Package VIP (simulate) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build/Package VIP | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build pipeline (full simulate) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build (isolated worktree) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build release asset (VI Package x64) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build release asset (VI Package x86) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build release asset (VI Package 32 & 64 bits) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build PPL (simulate) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build release asset (Packed Project Library, x64) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Build release asset (Packed Project Library, x86) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Analyze VI Package (Pester) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Requirements | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Draft release | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| Test VIPM Docker | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |
| VIPM Docker Smoke | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |

_Test cases_: Dev-mode tasks map to `TC-DEV-BIND-WIN/LNX`; intent tasks map to `TC-DEV-INTENT-WIN/LNX`; others use their own IDs.
