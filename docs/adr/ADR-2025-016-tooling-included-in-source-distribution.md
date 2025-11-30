# ADR-2025-016: Bundle minimal tooling in Source Distribution for VS Code use

## Status
Proposed

## Context
- We want recipients of `source-distribution.zip` to be able to unzip, open in VS Code, and rerun SD→PPL tasks without cloning the original repo.
- Users are expected to have LabVIEW installed/licensed and g-cli available; we cannot redistribute NI binaries.
- Path-length issues have been a recurring problem; we now require short roots (`C:\t` for temp/log/extract, `C:\w` for worktrees) to keep LabVIEW paths short.

## Decision
- Ship a minimal, self-contained tooling bundle inside the Source Distribution so users can execute VS Code tasks directly from the extracted folder:
  - Include published, self-contained `OrchestrationCli` (win-x64) under `Tooling/bin/...`.
  - Include `scripts/`, `Tooling/` helpers needed by tasks, `.vscode/tasks.json` (wired to the bundled CLI), optional `.vscode/extensions.json`, and request/config files.
  - Preserve `seed.vipb`/project files so version/bitness derive from VIPB as in the main repo.
  - Document prerequisites (LabVIEW + g-cli installed), and require short roots `C:\t` and `C:\w` to exist and be writable; fail fast if absent/unwritable.
- Do **not** bundle LabVIEW, g-cli, or any NI redistributables; rely on locally installed/ licensed components.

## Consequences
- Pros: Users can regenerate Source Distribution and PPL from the artifact alone, with VS Code tasks wired to the bundled CLI; reduced setup friction and clearer reproducibility.
- Cons: Slightly larger zip; must refresh bundled CLI/tasks when tooling changes; hard requirement on short roots and local LabVIEW/g-cli installs.
- Risks: Path-length issues if extracted under deep paths; mitigated by short-root requirement and validation. Version drift between bundled CLI and installed LabVIEW/g-cli; mitigated by clear prerequisites and provenance logging.

## Implementation sketch
- Build/publish a self-contained `OrchestrationCli` (win-x64) during SD build and copy into the SD under `Tooling/bin/win-x64/`.
- Copy required `scripts/`, `Tooling/` modules, `.vscode/tasks.json`, `.vscode/extensions.json` (optional), and config/request files into the SD payload.
- Update tasks to call the bundled `OrchestrationCli` instead of `dotnet run`, with temp/worktree defaults `C:\t`/`C:\w`.
- Add a README in the SD root describing prerequisites, required short roots, and how to run tasks in VS Code.
- Add runtime validation: fail early if `C:\t`/`C:\w` are missing/unwritable; log detected LabVIEW/g-cli versions and VIPB-derived version/bitness. Sanitize log-stash paths to avoid invalid directories when logs/attachments are absolute.

## Testing
- Unzip `source-distribution.zip` to a short path, ensure `C:\t` and `C:\w` exist, open in VS Code, and run the SD→PPL task using the bundled CLI; expect success and logs in `C:\t\logs`.
*** End Patch
