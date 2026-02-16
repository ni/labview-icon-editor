# LabVIEW Container Parity Lane

This repository includes a hosted parity workflow at `.github/workflows/labview-parity.yml`.

## Purpose

- Shift baseline LabVIEWCLI parity checks to hosted runners (`ubuntu-latest`, `windows-latest`).
- Reduce pressure on the Windows self-hosted runner pool for early CI signal.
- Keep parity checks aligned with NI LabVIEW container guidance (`-Headless` with LabVIEWCLI).

## Current Scope

- Linux container image: `nationalinstruments/labview:<release>-linux`
- Windows container image: `nationalinstruments/labview:<release>-windows`
- Always-on operation: `LabVIEWCLI MassCompile` on `Test/Templates`
- Default exclusion: `Polymorphic Template.vi` is excluded from parity MassCompile via `CONTAINER_PARITY_EXCLUDE_FILES` because it is a known headless bad VI in container runs.

The workflow defaults to release tag `2026q1`, and supports override via `workflow_dispatch` input `lv_release`.

## Default Build-Spec Behavior

Build-spec parity is enabled by default and is a blocking check.

- Manual input: `run_build_spec` (`true` or `false`, default `true`).
- Gate behavior:
  - `pull_request`: Linux parity runs by default; Windows parity is intentionally skipped to keep PR feedback fast for collaborators.
  - `push` to `develop`: both Linux and Windows parity run, including `ExecuteBuildSpec`.
  - `workflow_dispatch`: both Linux and Windows parity run by default; set `run_build_spec=false` only when explicitly skipping build-spec diagnostics.
- Hard-fail policy: when build-spec is enabled (default), Linux and Windows lanes must both pass.

Build-spec environment contract used by container scripts:

- `CONTAINER_PARITY_BUILD_SPEC`
- `CONTAINER_PARITY_BUILD_SPEC_NAME`
- `CONTAINER_PARITY_TARGET_NAME`
- `CONTAINER_PARITY_BUILD_OUTPUT_RELATIVE_PATH`

Solo-mode CI contract:

- Container parity CI scripts do not perform selector set/unset orchestration.
- Container parity CI scripts do not toggle development mode automatically.
- Manual development-mode operations remain available only through the dedicated manual workflow.

Default build-spec settings:

- Build spec name: `Editor Packed Library`
- Target name: `My Computer`
- Output path: `resource/plugins/lv_icon.lvlibp`
- Source sync before build-spec: container scripts copy `resource/plugins` Icon Editor sources and `vi.lib/LabVIEW Icon API` from the mounted workspace into the container LabVIEW install so `<resource>`/`<vilib>` project references resolve in headless builds.
- Dev-mode install mutation: disabled by default in parity runs to avoid removing required source items during build.

## Artifacts and Logs

Build-spec outputs in this phase are diagnostic-only artifacts (not release inputs):

- `labview-container-editor-packed-library-windows`
- `labview-container-editor-packed-library-linux`

LabVIEWCLI operation logs are captured and uploaded per OS as diagnostics:

- `labview-container-logs-windows`
- `labview-container-logs-linux`

## How To Run

Manual run:

1. Open Actions and run **LabVIEW Parity**.
2. Optionally set `lv_release` (for example `2026q1`).
3. Leave `run_build_spec=true` (default) to keep packed-library parity enabled; set it to `false` only when intentionally bypassing build-spec execution.

PR run:

- Triggered automatically when parity workflow/script files, `.lvversion`, `lv_icon_editor.lvproj`, or `Test/Templates` change.
- PR runs execute the Linux container parity lane by default.
- Windows container parity runs on `push` to `develop` and on manual `workflow_dispatch`.
