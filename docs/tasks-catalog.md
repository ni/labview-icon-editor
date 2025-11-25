# VS Code Tasks Catalog

Only one VS Code task is shipped for local builds. It wraps `scripts/ie.ps1 -Command build-worktree` and uses fixed defaults to build the addon and package it as a `.vip` (64-bit top-level VIP, both-bitness packed libraries). VIPM is expected to be available; when it is missing the build emits `builds/VI Package/vipm-skipped-placeholder.vip` and the task completes so you can rerun it once VIPM is installed.

| Task | Notes |
| --- | --- |
| Build LVAddon (VI Package) | Runs from **Terminal → Run Task…** or `Ctrl/Cmd+Shift+B`. Uses default version metadata `0.1.0.1`, `SupportedBitness=64`, `LvlibpBitness=both`. Adjust `.vscode/tasks.json` if you need different defaults. |
