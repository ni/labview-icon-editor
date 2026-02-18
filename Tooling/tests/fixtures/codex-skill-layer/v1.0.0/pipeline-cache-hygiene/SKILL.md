# Pipeline Cache Hygiene (v1.0.0)

Use this skill when the goal is to start every CI workflow from a deterministic cache state.

## Intent
- Clear pipeline-local caches at the start of each workflow.
- Keep deletion scoped to known, allow-listed cache paths.
- Record a machine-readable summary for diagnostics.

## Use This Skill When
- A workflow must not reuse stale local cache state.
- CI flakes are caused by leftover build outputs or tool caches.
- You need repeatable "cold start" behavior before any build/test job runs.

## Workflow
1. Add a first-stage cache-hygiene job in each workflow.
2. Run `scripts/Clear-PipelineCaches.ps1` from that job.
3. Upload the JSON summary when cleanup fails.
4. Pass a monotonically increasing cache epoch in external cache keys when you need to invalidate `actions/cache` entries.

## Notes
- This clears local filesystem caches only.
- GitHub-hosted cache entries are not deleted in-place; rotate cache keys to force misses.
- Keep the script step before dependency restore and before any LabVIEW/g-cli job.
