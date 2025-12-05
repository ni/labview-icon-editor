# ADR: Centralized Log Stash for Build/Test Workflows

- **ID**: ADR-2025-010  
- **Status**: Accepted  
- **Date**: 2025-11-27

## Context
Build, test, and binder scripts emit logs under `builds/logs/` with ad-hoc names and no structured index. `test-stash` tracks results but only stores a relative log path; build/VIP/devmode flows lack consistent metadata. CI artifacts otherwise guess paths, reruns are hard to correlate to commits, and there is no retention policy or discoverability for troubleshooting, audits, or DoD evidence.

## Options
- **A — Status quo**: keep per-script log names in `builds/logs/` and rely on ad-hoc references.  
  - **+** No work. **-** Poor discoverability, no index, brittle CI uploads, no retention.  
- **B — Minimal index**: add a flat log index file that lists current `builds/logs/*.log` without bundling or retention.  
  - **+** Lightweight. **-** Still ad-hoc layout, no attachments, weak CI artifact mapping, no cleanup.  
- **C — Commit-keyed log stash**: introduce `builds/log-stash/<commit>/<category>/<timestamp>-<label>/` bundles with manifests, optional bundle zips, and cleanup; wrap producers with a shared helper.  
  - **+** Structured, traceable, easy CI upload, supports attachments/retention, backward compatible with `builds/logs`. **-** Requires wiring scripts and adding cleanup logic.

## Decision
Choose **C**. We shall adopt a commit-keyed log stash (`builds/log-stash/`) with per-bundle manifests, optional bundle zips, and a shared helper to standardize log capture across build, test, VIPM, devmode, and analyzer flows. Layout, manifest schema, retention knobs, and integration points are defined in `docs/ci/log-stash-design.md`. Existing paths under `builds/logs/` remain as the source; the stash copies them to structured bundles and maintains an index for CI and troubleshooting.

## Consequences
- **+** Consistent, traceable logs per commit/job with metadata (bitness, LV version, producer, status).  
- **+** CI artifact uploads become predictable (bundle zips) and reports can deep-link via the index.  
- **+** Retention/cleanup prevents unbounded growth on runners and local worktrees.  
- **-** Initial wiring effort across scripts and workflows; helper should stay in sync with new producers.  
- **-** Extra file I/O to copy logs into bundles (mitigated by optional compression/cleanup).

## Follow-ups
- [ ] Implement log-stash helper + cleanup scripts per `docs/ci/log-stash-design.md` (owner: automation).  
- [ ] Wire `scripts/test/Test.ps1`, `scripts/build/Build.ps1`, VIPM install/uninstall, and devmode binder to emit bundles and update existing manifests with stash links.  
- [ ] Add CI artifact steps to upload bundle zips and reference the index in status/completion reports.

> Traceability: `docs/ci/log-stash-design.md`; DoD/log evidence expectations in `docs/dod.md` and test plan `docs/testing/test-plan.md`.
