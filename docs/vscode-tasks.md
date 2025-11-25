# VS Code task shortlist

Only one VS Code task is provided for local builds. Run it from **Terminal → Run Task…** (or `Ctrl/Cmd+Shift+B`) and pick **Build LVAddon (VI Package)**.

## Build LVAddon (VI Package)
- Runs `scripts/ie.ps1 -Command build-worktree` from the repo root using the default arguments in `.vscode/tasks.json`:
  - `SupportedBitness=64` for the top-level package and `LvlibpBitness=both` to emit 32-bit and 64-bit packed libraries.
  - `Major=0`, `Minor=1`, `Patch=0`, `Build=1` (override in the task definition or by editing the invocation before running it).
  - `CompanyName` and `AuthorName` default to the values baked into the task.
- Outputs:
  - VIP artifact: `builds/VI Package/` (top-level package for the selected bitness)
  - Packed libraries: `resource/plugins/lv_icon.lvlibp` (overwritten per build for each bitness produced)
- VIPM not available?
  - If `vipm` is not on PATH, VIPC/VIPM steps are skipped, the lvlibp still builds, and a placeholder `builds/VI Package/vipm-skipped-placeholder.vip` is written.
  - After adding VIPM to PATH, delete the placeholder `.vip` and rerun the task to create the real package.

## Analyze VI Packages (CLI)
The VS Code task was removed; invoke the analyzer directly:

```pwsh
pwsh -NoProfile -File scripts/analyze-vi-package/run-workflow-local.ps1 -VipArtifactPath "<vip or dir>" -MinLabVIEW "21.0"
```

Provide a real `.vip` (placeholders like `vipm-skipped-placeholder.vip` are skipped). `scripts/analyze-vi-package/VIPReader.psm1` auto-loads as part of the workflow.
