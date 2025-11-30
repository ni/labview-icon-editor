# ADR-2025-013 — Common probe/build/cache strategy for repo CLIs

**Status:** Accepted  
**Date:** 2025-11-28  
**Last updated:** 2025-11-28  
**Owners:** Tooling  
**Stakeholders:** Tooling, CI, DevEx, Integration teams  
**Related ADRs:** ADR-2025-009 (DevModeAgentCli), ADR-2025-005 (IntegrationEngineCli), ADR-2025-012 (x-cli), ADR-2025-011 (repo layout)

## Change history
- 2025-11-28: Initial proposal.

## Context
We have several .NET CLIs in the repo (DevModeAgentCli, OrchestrationCli, x-cli, IntegrationEngineCli). These CLIs are used by local developer workflows, CI/CD jobs, and automated integration / regression tests.

Current tasks sometimes depend on the source repo path for `dotnet run`, which breaks when:

- using isolated worktrees that do not contain the tooling projects,
- running on ephemeral CI agents that only have published artifacts,
- the CLI binaries have been cleaned or were never built on the current machine.

This leads to brittle scripts that encode the source layout, non-reproducible test environments, and inconsistent behavior across branches, worktrees, and machines.

We need a consistent, resilient way to locate and run these CLIs across worktrees, branches, platforms, and machines without hard-coding the source repo path.

### Non-goals
- Defining the full CLI UX or command surface.
- Replacing existing language-agnostic tooling runners; this ADR only standardizes how repo CLIs are discovered, built, cached, and invoked.

## Decision
Adopt a shared probe/build/cache pattern for all repo CLIs.

### 1) Probe order per CLI

Probe in this order for each CLI binary:

1. **Active repo/worktree**

   - Look for the project at `<repo>/Tooling/dotnet/<CLI>/<CLI>.csproj`.
   - If present, prefer `dotnet run --project ...` so that local changes are honored.
   - If the project fails to build or run, log the failure and fall back to the next tier instead of silently succeeding.

2. **Source repo fallback**

   - If the active worktree does not contain the tooling project, probe the configured "source repo" root (for example, a canonical clone path or a path provided via configuration).
   - Use `dotnet run --project ...` from this source repo when available.

3. **Cached publish**

   - Probe for a previously published binary in:
     - Windows: `%LOCALAPPDATA%\labview-icon-editor\tooling-cache\<CLI>\<version>\<rid>\publish\`
     - POSIX: `$HOME/.cache/labview-icon-editor/tooling-cache/<CLI>/<version>/<rid>/publish/`
   - `<rid>` is the runtime identifier (e.g. `win-x64`, `linux-x64`, `osx-x64`). The combination `<CLI>/<version>/<rid>` is treated as the cache key.
   - If found, run the published binary from this location.

4. **Build-and-cache**

   - If none of the previous probes succeed, build and cache once from the "best available" repo (active worktree when possible, otherwise the configured source repo).
   - Publish with `dotnet publish -c Release -r <rid>` (or an equivalent cross-platform setting) and stash the output into the cache path above under `<CLI>/<version>/<rid>/publish/`.
   - After publishing, run the binary from the cache.
   - Emit structured logs indicating that a cache miss occurred and that a publish was performed.

2) **Versioning key**
   - Use the CLI git commit SHA (or semver tag when available) as `<version>` in the cache path to avoid mixing binaries across branches/commits.
   - Include both the runtime identifier (`<rid>`) and target framework as part of the cache key so we do not mix incompatible binaries across platforms or runtimes.
   - When a caller requests a specific version, fail fast if the resolved CLI provenance does not match the requested `<CLI>/<version>/<rid>`.

3) **Scope**
   - Apply this pattern to: DevModeAgentCli, OrchestrationCli, x-cli, IntegrationEngineCli (and future repo CLIs).
   - New CLIs added to the repo must opt into this probe/build/cache helper as part of their initial adoption checklist.

4) **Tasks/flows**
   - Tasks invoking these CLIs must use the probe order above and must not assume the source repo contains the tooling or that the CLI is available on `PATH`.
   - Tasks should treat the probe/build/cache behavior as a stable contract and rely only on:
     - the CLI name,
     - the requested `<version>` (or "current branch head" when implicit),
     - and the resolved provenance in logs.

### 5) Observability, testing, and rollback

   - Each CLI should expose a `--print-provenance` (or similar) option that prints:
     - the resolved physical path,
     - the cache key (`<CLI>/<version>/<rid>`),
     - the probe tier that supplied the binary (worktree, source repo, cache),
     - and the git commit SHA / semver reported by the binary itself.
   - Add automated tests that cover, at minimum:
     - worktree with tooling present,
     - worktree without tooling but with source repo available,
     - cache-only execution on each supported `<rid>`,
     - mismatch between requested and resolved version.
- Provide a `clear-tooling-cache` task (or documented manual steps) so that users and CI can explicitly invalidate caches when needed.
- If this ADR is rolled back, restore the prior behavior (direct `dotnet run` against the source repo) and update tasks to ignore the cache paths.

## Consequences
- **Pros:** Worktree self-sufficiency; fewer path mismatches; reusable cached binaries across runs; stable behavior across branches/commits; clearer provenance for CI and testing; per-platform cache keys aligned with configuration management.
- **Cons:** First run per version and runtime may pay a publish cost; more cache entries to manage across RIDs/TFMs; explicit cache invalidation required when CLI version or runtime changes; slightly more complex probe logic to implement and test.

## Rollout notes
- Implement probe/build/cache helpers once and reuse across tasks.
- Prefer `dotnet run` when the project exists in the active repo/worktree to honor local changes.
- Only use the cached publish when sources are absent or unavailable.
- Include clear logging of which probe tier was used, which cache key was resolved, and where the binary was sourced from.
- Document the helper API so that future CLIs can adopt it without re-implementing probe logic.
- Provide a task for cache maintenance: VS Code task “Tooling: Clear CLI cache entry” runs `scripts/clear-tooling-cache.ps1 -CliName <...> -Version <...> -Rid <...>`; after clearing, the next helper run will publish on miss and repopulate `<CLI>/<version>/<rid>/publish/`. Use this for TOOL-016 scenarios and cache corruption recovery.
- CLI provenance: `--print-provenance` on DevModeAgentCli/OrchestrationCli/IntegrationEngineCli emits path, tier, cacheKey, and rid. When invoked via the helper, tier and cacheKey reflect the resolved provenance. Helper enforces expected cache key when provided to catch mismatch (TOOL-012/013).
- Rollback: tasks/workflows call CLIs via the helper; cache layout is internal. To bypass caching (if ADR is rolled back), run the helper in a mode that prefers worktree/source without cache, keeping the same task inputs/outputs.
