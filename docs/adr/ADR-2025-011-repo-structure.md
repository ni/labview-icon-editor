# ADR: Repository Layout and Tooling Placement

- **ID**: ADR-2025-011  
- **Status**: Accepted  
- **Date**: 2025-11-27

## Context
IntegrationEngine, x-cli, DevModeAgentCli, and PowerShell orchestration grew around a root-centric layout while shared modules (VendorTools/LabVIEWCLI/providers) live under `src/tools/`. Recent upstream imports cemented this split. Without a clear ADR, future moves risk path drift, brittle task/CI wiring, and preflight mismatches.

## Decision
- Keep orchestration/tooling at the repo root (`scripts/`, `Tooling/`, `configs/`, `docs/`); keep shared libraries/modules under `src/` (e.g., `src/tools/*`, provider specs). Do not relocate root build scripts/tooling into `src/`.
- Keep shared modules in `src/tools/*.psm1`; keep LabVIEWCLI/provider specs in `src/tools/providers/`; retain `tools/VendorTools.psm1` as a thin loader into `src/tools/VendorTools.psm1`.
- Anchor `src/` at the repo root; tasks/CI resolve paths from the root rather than moving assets into `src/`.
- Managed CLI preflights shall check for required modules/specs in these locations before running scripts.

## Consequences
- **+** Predictable paths for tasks/CI and future imports; less drift when adding tooling.
- **+** Clear separation between orchestration (root) and shared modules (`src/`).
- **-** Minor ongoing upkeep in preflights/docs when adding new shared modules.

## Follow-ups
- Add/maintain a short structure note in `docs/ci/log-stash-design.md` (or README) that points to this ADR and reinforces root-vs-src responsibilities.
- Keep future shared modules under `src/tools/` with thin loaders under `tools/` when necessary.
- Ensure tasks/CI resolve paths relative to the repo root instead of relocating assets into `src/`.

## Tasks
- [x] Add/refresh the structure pointer in `docs/ci/log-stash-design.md` referencing this ADR (owner: codex, done 2025-11-27).
- [x] Capture the shared-module pattern (`src/tools/` + optional `tools/` loaders) in scripting/orchestration docs for new contributors (owner: codex, done 2025-11-27; see `scripts/README.md`).
- [x] Re-audit VS Code tasks, CI jobs, and helper scripts to confirm they resolve paths from the repo root (owner: codex, done 2025-11-27; spot-checked `.vscode/tasks.json`, `scripts/build/Build.ps1`, `scripts/task-verify-apply-dependencies.ps1`, and `scripts/test/Test.ps1` for root-relative resolution).

> Traceability: aligns with VendorTools/LabVIEWCLI/provider imports and IntegrationEngine/x-cli task wiring.
