# Cache Scope Contract

This skill splits cache invalidation into two scopes:

## Pipeline-start scope
- `builds/status`
- `builds/vi-analyzer`
- `TestResults`
- `obj`, `bin` (repo-local)
- CI worktree scratch directories under `LVIE_WORKTREE_ROOT` matching `ci-*`
- Optional .NET/NuGet local caches via CLI commands

## Not directly deletable from job runtime
- `actions/cache` backend entries.
- Invalidate those by rotating cache keys (for example `cache-epoch`).

## Safety rules
- Only remove directories under repo root, worktree root, or explicit allow-listed temp roots.
- Never recurse-delete arbitrary paths from environment variables without root validation.
