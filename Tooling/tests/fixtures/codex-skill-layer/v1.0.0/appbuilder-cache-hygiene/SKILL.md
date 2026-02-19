# AppBuilder Cache Hygiene (v1.0.0)

Use this skill when each build job must clear AppBuilder caches before compiling artifacts.

## Intent
- Re-clear AppBuilder cache immediately before each build lane.
- Keep behavior deterministic across 32-bit and 64-bit LabVIEW lanes.
- Emit per-job cleanup evidence.

## Use This Skill When
- Build jobs show stale compile/package behavior.
- Build output diverges between reruns without source changes.
- You need strict cache hygiene before `build-ppl`, `build-vip`, or parity build lanes.

## Workflow
1. Keep a pipeline-start cache clear (from `pipeline-cache-hygiene`) for global cleanup.
2. In each build job, add a pre-build step that runs `scripts/Clear-AppBuilderCache.ps1`.
3. Pass the active LabVIEW version and bitness into the script.
4. Upload the resulting JSON summary on failure for diagnostics.

## Notes
- This skill is intentionally per-build-job, not once per workflow.
- If cache locations differ by runner image, provide explicit paths via `-CachePath`.
