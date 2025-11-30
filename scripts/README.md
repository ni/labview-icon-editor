# Scripts (legacy delegates)

PowerShell scripts remain for compatibility, but the supported entrypoint is the Orchestration CLI:

```
dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- <subcommand> [options]
```

Subcommands cover apply-deps, restore-sources, labview-close, unit-tests, vi-analyzer, missing-check, and package-build. Prefer these over calling scripts directly; the scripts now emit a deprecation warning and act as thin delegates.

## Probe/build/cache helper (TOOL-010..016)
- CLIs are resolved via `scripts/common/resolve-repo-cli.ps1` in this order: worktree → source repo → cache → publish. Cache root is `%LOCALAPPDATA%\labview-icon-editor\tooling-cache/<CLI>/<version>/<rid>/publish/` (Windows) or `$HOME/.cache/labview-icon-editor/tooling-cache/<CLI>/<version>/<rid>/publish/` (POSIX).
- Provenance: run any CLI with `--print-provenance` to emit `path`, `tier`, `cacheKey`, and `rid`. The helper can enforce an `ExpectedCacheKey` to fail fast on mismatches.
- Cache maintenance: VS Code Task 18 “Tooling: Clear CLI cache entry” calls `scripts/clear-tooling-cache.ps1` for a specific `<CLI>/<version>/<rid>`; next helper run publishes on miss and repopulates.
- Validation: VS Code Task 19 “Tests: Probe helper smoke” runs `scripts/test/probe-helper-smoke.ps1` covering worktree/source/cache/publish tiers, cache clear/republish, cache-key mismatch handling, and provenance output.
- Tip: For legacy script delegates that still show raw `dotnet run` usage, prefer calling the CLI via the resolver (`pwsh scripts/common/resolve-repo-cli.ps1 -CliName <name> -RepoPath <path> -SourceRepoPath <path>`) to honor the probe/build/cache contract and provenance logging.
- Rollback: Tasks and callers should not rely on cache paths. If probe caching needs to be bypassed, adjust the helper to always select worktree/source (or add a bypass flag) while keeping task inputs/outputs unchanged; because tasks call CLIs by name/version, rollback does not affect task semantics.

Shared modules pattern (per `docs/adr/ADR-2025-011-repo-structure.md`):
- Keep orchestration/tooling at the repo root (`scripts/`, `Tooling/`, `configs/`, `docs/`).
- Put shared modules in `src/tools/` (e.g., `src/tools/*.psm1`, `src/tools/providers/*`) and expose thin loaders from `tools/` as needed (e.g., `tools/VendorTools.psm1`).
- Resolve paths from the repo root; do not move root orchestration into `src/`. Managed CLI preflights rely on these locations.
