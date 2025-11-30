# Provenance, probe order, and cache maintenance

- Probe order (helper): worktree → source repo → cache → publish. Cache roots:
  - Windows: `%LOCALAPPDATA%\labview-icon-editor\tooling-cache/<CLI>/<version>/<rid>/publish/`
  - POSIX: `$HOME/.cache/labview-icon-editor/tooling-cache/<CLI>/<version>/<rid>/publish/`
- Provenance: run any CLI with `--print-provenance` to emit `path`, `tier`, `cacheKey`, and `rid`. The helper also logs these fields on every resolution. Use `ExpectedCacheKey` (helper) to fail fast on mismatches. XCli provenance print is skipped in the smoke test due to its isolation guard.
- Clear cache: VS Code Task 18 “Tooling: Clear CLI cache entry” calls `scripts/clear-tooling-cache.ps1 -CliName <...> -Version <...> -Rid <...>`. After clearing, the next helper run publishes on miss and repopulates `<CLI>/<version>/<rid>/publish/`.
- Validation: VS Code Task 19 “Tests: Probe helper smoke” runs `scripts/test/probe-helper-smoke.ps1` across all CLIs (IntegrationEngineCli, OrchestrationCli, DevModeAgentCli, XCli) covering worktree/source/cache/publish tiers, cache clear/republish, cache-key mismatch handling, and provenance output. XCli provenance print is skipped due to its isolation guard.
- Rollback note: tasks and callers should treat probe/build/cache as an internal detail. If needed, the helper can be adjusted to bypass cache and run `dotnet run` against the source repo without changing task inputs or outputs, because tasks invoke CLIs via the helper/CLI name, not cache paths.
- Onboarding (new CLIs): checklist
  - Use the shared helper (`scripts/common/resolve-repo-cli.ps1`) for probe/build/cache; do not reimplement probe logic.
  - Expose `--print-provenance` with path/tier/cacheKey/rid; add the CLI to probe-helper-smoke coverage.
  - Add a Task/README note for invoking via the helper; avoid hard-coding cache paths in callers.
