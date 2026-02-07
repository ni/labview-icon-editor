# LabVIEW Container Parity Lane

This repository includes a hosted parity workflow at `.github/workflows/labview-container-parity.yml`.

## Purpose

- Shift baseline LabVIEWCLI parity checks to hosted runners (`ubuntu-latest`, `windows-latest`).
- Reduce pressure on the Windows self-hosted runner pool for early CI signal.
- Keep parity checks aligned with NI LabVIEW container guidance (`-Headless` with LabVIEWCLI).

## Current Scope

- Linux container image: `nationalinstruments/labview:<release>-linux`
- Windows container image: `nationalinstruments/labview:<release>-windows`
- Operation: `LabVIEWCLI MassCompile` on `Test/Templates`

The workflow defaults to release tag `2026q1`, and supports override via `workflow_dispatch` input `lv_release`.

## How To Run

Manual run:

1. Open Actions and run **LabVIEW Container Parity**.
2. Optionally set `lv_release` (for example `2026q1`).

PR run:

- Triggered automatically when parity workflow/script files, `.lvversion`, `lv_icon_editor.lvproj`, or `Test/Templates` change.

## Next Extension Candidates

- Add a Linux/Windows VI Analyzer parity step once a stable repo-owned `.viancfg` is available.
- Add a separate VIPM CLI lane on Linux for dependency-install parity, while keeping LabVIEWCLI as the primary execution surface.
