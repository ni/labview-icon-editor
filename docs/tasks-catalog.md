# VS Code Tasks Catalog

Only one VS Code task is shipped for local builds. It wraps `scripts/ie.ps1 -Command build-worktree` and uses fixed defaults to build the addon and package it as a `.vip` (64-bit top-level VIP, both-bitness packed libraries); outputs land in `builds/VI Package/` (VIP artifact) and `resource/plugins/lv_icon.lvlibp` (packed libraries). If `vipm` is not on PATH, VIPC/VIPM steps are skipped, the lvlibp still builds, and a placeholder `builds/VI Package/vipm-skipped-placeholder.vip` is written. After adding VIPM to PATH, delete the placeholder `.vip` and rerun the task to create the real package.

| Task | Notes |
| --- | --- |
| Build LVAddon (VI Package) | Runs from **Terminal → Run Task…** or `Ctrl/Cmd+Shift+B`. Uses default version metadata `0.1.0.1` (`Major=0`, `Minor=1`, `Patch=0`, `Build=1`), `SupportedBitness=64`, `LvlibpBitness=both`. Adjust `.vscode/tasks.json` if you need different defaults. |
