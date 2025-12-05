# Automation Gap Review

## Overview
Recent documentation and ADRs highlight several automation areas that remain unimplemented or partially wired. The notes below consolidate the highest-impact gaps so we can prioritize fixes and unblock CI/reporting.

## Findings

### 1) Log stash plumbing is still design-only
- **Current state:** Design exists but helper scripts (`Write-LogStashEntry.ps1`, cleanup) and workflow wiring are absent; log paths remain ad-hoc and indices/retention are undefined.
- **Risk/impact:** CI artifacts cannot be traced cleanly to commits or runs, and build workspaces will keep growing without pruning.
- **Action slice (MVP):**
  - Add `Write-LogStashEntry.ps1` with a schema that captures commit, run ID, workflow/job name, artifact bundle location, and retention timestamp.
  - Wire logging into `Test.ps1` and `Build.ps1` with a single opt-in flag so we can stage gradually.
  - Add a cleanup helper that prunes log-stash indices/bundles past retention and call it from the same workflows.
  - Publish bundle zips in CI (per job) and point the log-stash records at those bundle paths for traceability.
  - Exit when logs show up in CI artifacts with consistent indices and the cleanup job deletes expired entries on schedule.

### 2) DevModeAgentCli not integrated into automation
- **Current state:** ADR-2025-009 follow-ups (unit tests, making the CLI the automation entry point, and schema/contract checks against `reports/dev-mode-bind.json`) remain open.
- **Risk/impact:** Automation still drives the PowerShell binder directly, so path/version guardrails are unenforced and intent parsing lacks regression coverage.
- **Action slice (MVP):**
  - Land the DevModeAgentCli unit test suite that covers intent parsing, path/version guardrails, and schema validation hooks.
  - Update automation playbooks to invoke DevModeAgentCli as the single entry point (replace direct binder calls) with a feature flag to roll out safely.
  - Add a schema check against `reports/dev-mode-bind.json` before execution, failing fast on drift.
  - Exit when CI runs through DevModeAgentCli by default and unit tests cover binder contract checks.

### 3) Ollama executor lacks end-to-end automated coverage
- **Current state:** ADR-2025-019 notes the absence of an automated executor suite, including integration tests, command vetting, mock server, timeout/turn-limit handling, error paths, and performance checks.
- **Risk/impact:** Changes can regress security vetting or conversation handling, and manual testing slows feedback.
- **Action slice (Phase 1):**
  - Build a lightweight mock Ollama server fixture and wire it into the executor tests.
  - Cover command vetting (allow/deny lists) with table-driven cases and assert on emitted audit logs.
  - Add timeout and turn-limit scenarios plus negative cases (bad model name, malformed responses) to guard error handling.
  - Provide an integration harness that CI can run without a real Ollama instance, and exit when those scenarios run green in CI.

## Next actions
- Scope and size the three gaps above for the next planning cycle; treat log stash MVP and DevModeAgentCli wiring as near-term because they unblock traceability and guardrails.
- Add CI tasks to exercise any new helpers (log-stash index updates, DevModeAgentCli tests, Ollama executor scenarios) so coverage stays enforced.
- Track completion of each action slice with explicit checkboxes (design, implementation, CI coverage) so the gaps close visibly and do not regress.
- Add owners and deadlines for each MVP so we can surface slippage early and replan.
