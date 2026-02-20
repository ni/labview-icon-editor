# LabVIEW Container Parity Lane

This repository includes a hosted parity workflow at `.github/workflows/labview-parity.yml`.

## Purpose

- Shift baseline LabVIEWCLI parity checks to hosted runners (`ubuntu-latest`, `windows-latest`).
- Reduce pressure on the Windows self-hosted runner pool for early CI signal.
- Keep parity checks aligned with NI LabVIEW container guidance (`-Headless` with LabVIEWCLI).
- Keep fork ergonomics high by always providing container parity signal even when no self-hosted runner is available.

## Current Scope

- Linux container image: `nationalinstruments/labview:<release>-linux`
- Windows container image: `nationalinstruments/labview:<release>-windows`
- VI Analyzer Linux-container responsibilities are merged into `Parity (Linux Container <.lvcontainer>)`.
- Always-on operation: `LabVIEWCLI MassCompile` on `Test/Templates`
- Default exclusion: `Polymorphic Template.vi` is excluded from parity MassCompile via `CONTAINER_PARITY_EXCLUDE_FILES` because it is a known headless bad VI in container runs.

Release and tag sources:
- `.lvcontainer` is canonical for container lanes.
- `lv_release` can override container release token (`YYYYqN`) for dispatch/call scenarios.
- `lv_release_self_hosted` can override shared self-hosted release token (`YYYYqN`) for both self-hosted bitness lanes.

## Default Build-Spec Behavior

Build-spec parity is mandatory and is a blocking check.

- Container lanes:
  - `Parity (Linux Container <.lvcontainer>)`
  - `Parity (Windows Container <resolved windows tag>)`
  `Parity (Linux Container <.lvcontainer>)` also owns the Linux VI Analyzer responsibilities.
  These lanes always run in every parity mode.

- Self-hosted lanes:
  - `Parity (Self-Hosted Windows LabVIEW 64-bit)`
  - `Parity (Self-Hosted Windows LabVIEW 32-bit)`
  These lanes are controlled by parity mode, compatibility toggles, and capacity detection.

- Mode defaults:
  - `pull_request` -> `auto`
  - `push` to `develop` -> `full`
  - `workflow_dispatch` / `workflow_call` -> `auto`

- Supported `parity_mode` values:
  - `auto`: run self-hosted only when an online runner exists.
  - `containers-only`: force container-only execution.
  - `full`: require self-hosted availability; fail policy gate when unavailable.

- Compatibility toggles kept:
  - `run_self_hosted` (legacy, applies to both lanes)
  - `run_self_hosted_64`
  - `run_self_hosted_32`

- Hard-fail policy: Linux and Windows lanes always execute build-spec parity and must pass.

Self-hosted capacity and full-mode enforcement:
- `Resolve self-hosted capacity` checks whether `${{ vars.LVIE_RUNNER_LABEL || 'self-hosted-windows-lv' }}` has an online runner.
- `Self-hosted policy gate` fails only when `parity_mode=full` and requested self-hosted lanes are unavailable.
- Effective self-hosted lane toggles are exported as:
  - `run_self_hosted_64_effective`
  - `run_self_hosted_32_effective`
  This avoids dead-queueing when no runner is online.

Build-spec environment contract used by container scripts:

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

VI Analyzer artifacts from parity (emitted by `Parity (Linux Container <.lvcontainer>)`):
- `vi-analyzer-linux-logs-parity`
- `vi-analyzer-reports-parity`
- `vi-analyzer-status-parity`

Workflow summary:
- `Parity Summary` writes mode, self-hosted capacity, effective lane toggles, and lane results to the job summary.

## How To Run

Manual run:

1. Open Actions and run **LabVIEW Parity**.
2. Optionally set `parity_mode` (`auto`, `containers-only`, `full`).
3. Optionally set `lv_release` (for example `2026q1`).
4. Optional self-hosted controls:
   - `run_self_hosted_64` (`true` by default)
   - `run_self_hosted_32` (`true` by default)
   - `lv_release_self_hosted` (optional shared self-hosted release override)
5. Build-spec parity is always executed (no skip toggle).

PR run:

- Triggered automatically when parity workflow/script files, `.lvversion`, `lv_icon_editor.lvproj`, or `Test/Templates` change.
- PR runs default to `parity_mode=auto`:
  - container lanes always run (`Parity (Linux Container <.lvcontainer>)` includes Linux VI Analyzer responsibilities)
  - self-hosted lanes run only if a matching runner is online

## Local Deterministic Preflight

Use the local helper before marking parity diagnostics PRs ready:

```powershell
pwsh -NoProfile -File .\Tooling\Invoke-LinuxContainerPreflight.ps1 -RepoRoot .
```

Dry-run command plan only:

```powershell
pwsh -NoProfile -File .\Tooling\Invoke-LinuxContainerPreflight.ps1 -RepoRoot . -DryRun
```

Behavior contract:
- Resolves `.lvcontainer` via `Get-LabVIEWContainerReleaseInfo`.
- Uses resolved `ReleaseTag` for `runner-cli parity context --lv-release <releaseTag>`.
- Uses resolved `LinuxImage` for Docker image inspect/pull and Linux parity execution, including merged VI Analyzer responsibilities.
- Fails fast when `.lvcontainer` resolves to a non-linux tag.

Outputs:
- Parity context: `builds/status/local-preflight-parity-context-<sha>.json`
- Summary: `builds/status/local-linux-preflight-summary-<sha>.json`

## Self-Hosted Port-Contract Remediation

Self-hosted Windows parity validates `LabVIEW.ini` against `Tooling/labviewcli-port-contract.json`.
If a runner drifts from contract values, parity intentionally fails fast.

Deterministic runner remediation steps:

1. Read expected ports from contract:

```powershell
Get-Content .\Tooling\labviewcli-port-contract.json
```

1. Inspect installed LabVIEW ini state for each bitness:

```powershell
Get-Content "C:\Program Files\National Instruments\LabVIEW 2020\LabVIEW.ini" |
  Select-String -Pattern 'server.tcp.enabled|server.tcp.port'

Get-Content "C:\Program Files (x86)\National Instruments\LabVIEW 2020\LabVIEW.ini" |
  Select-String -Pattern 'server.tcp.enabled|server.tcp.port'
```

1. Align each runner to contract values (`server.tcp.enabled=True`, `server.tcp.port=<contract-port>`), then rerun parity.

Reference contract defaults currently used in this repo:
- `2020/64 -> 3366`
- `2020/32 -> 3365`
- `2026/64 -> 3363`
- `2026/32 -> 3364`
