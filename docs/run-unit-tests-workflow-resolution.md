# Run Unit Tests (x64) Workflow Recovery Plan

This plan distills the findings from **Resolving the __Run Unit Tests (x64)__ Workflow Failure.docx** into actionable, iterative tasks for future contributors. Execute the tasks in order; stop and capture findings if any checkpoint fails.

## Phase 0 — Baseline and Evidence Capture
- [ ] Reproduce the current CI failure locally by invoking the composite action on Windows runner (or self-hosted equivalent) to confirm the missing `get-package-lv-version.ps1` execution path and capture logs.
- [ ] Archive the existing `Run Unit Tests (x64)` job logs from CI for reference and diffing after fixes.

## Phase 1 — Decide the Source of Truth for LabVIEW Version
- [ ] Review the `resolve-labview-version` job output and artifacts in the CI workflow to confirm it already produces a validated LabVIEW version from the `.vipb` file.
- [ ] Choose a single version-resolution path:
  - **Option A (preferred):** Reuse the version resolved in `resolve-labview-version` by passing it as an input/environment variable into the `Run Unit Tests` action.
  - **Option B:** Keep Windows-side resolution but ensure the script path and invocation are correct.
- [ ] Document the chosen approach in the action README (or inline comments) to prevent reintroduction of duplicate resolution logic.

## Phase 2 — Fix Script Invocation (if Option B is chosen)
- [ ] Update `.github/actions/run-unit-tests/action.yml` to call `scripts/get-package-lv-version.ps1` using a workspace-absolute path (e.g., `$env:GITHUB_WORKSPACE\\scripts\\get-package-lv-version.ps1`) to avoid relative-path failures on Windows.
- [ ] Verify that `scripts/get-package-lv-version.ps1` is present in the repository and executable on Windows runners.
- [ ] Add a preflight step in the action to fail fast with a clear error if the script is missing or returns a non-zero exit code.

## Phase 3 — Simplify by Reusing Resolved Version (if Option A is chosen)
- [ ] Update the composite action to accept a `labview_version` input (or read an env var) and pass it directly to `RunUnitTests.ps1`, removing the PowerShell call that recomputes the version.
- [ ] Adjust the calling workflow to supply the resolved version from `resolve-labview-version` as the input/env var.
- [ ] Ensure the action fails clearly if the version input is absent, to prevent silent regressions.

## Phase 4 — Complete/Remove Partial Feature Code
- [x] Removed the unused `scripts/resolve-lv-version.ps1` helper to eliminate dead references and duplication.
- [x] Confirmed there is a single LabVIEW version-resolution path: `scripts/get-package-lv-version.ps1` called by the `resolve-labview-version` job and passed through to downstream actions.

## Phase 5 — Validation
- [ ] Run the updated workflow on Windows and Linux runners to confirm the `Run Unit Tests (x64)` job succeeds and `Package_LabVIEW_Version` is populated.
- [ ] Check that the workflow still detects multiple or missing `.lvproj` files correctly (the existing `RunUnitTests.ps1` safeguards should remain intact).
- [ ] Capture before/after logs showing the resolved version value and the successful invocation of `RunUnitTests.ps1`.

## Phase 6 — Hardening and Documentation
- [ ] Add regression tests or lint checks (if available) to ensure the version-resolution path remains valid (e.g., unit tests for path construction in action scripts).
- [x] Update contributor-facing docs to explain how the LabVIEW version is resolved and passed through CI, including any new inputs or environment variables.
- [ ] Consider adding telemetry/logging within the action to report the resolved version and script path for easier future debugging.

### Current LabVIEW version flow (contributor reference)
1. **Resolve once**: The `resolve-labview-version` job runs `scripts/get-package-lv-version.ps1` to read the VIPB and normalize the minimum supported version. It gates against `MIN_LABVIEW_POLICY` and publishes the value as `needs.resolve-labview-version.outputs.minimum_supported_lv_version`.
2. **Propagate everywhere**: Jobs that depend on the version (VIPC application, missing-in-project checks, x64/x86 unit tests, packed library builds) set `LABVIEW_VERSION` to that output and pass the same value into any action input named `labview_version`.
3. **Fail fast if missing**: The `run-unit-tests` composite action and `RunUnitTests.ps1` consume the provided version and throw if the workflow omits it, preventing silent fallbacks to in-action resolution.

## Exit Criteria
- The `Run Unit Tests (x64)` job completes successfully in CI with a correctly resolved `Package_LabVIEW_Version`.
- Only one LabVIEW version-resolution strategy is active and documented.
- New CI logs confirm the script invocation/path is correct and no longer fails on Windows runners.
