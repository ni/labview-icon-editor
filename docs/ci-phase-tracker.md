# CI Version Contract Phase Tracker

Date Created: 2026-02-04
Branch: experimental/447-test

## Phase A (Foundation)
- [x] Add Tooling/Assert-LabVIEWVersion.ps1 (parse .lvversion, enforce mismatch rules)
- [x] Call Assert-LabVIEWVersion.ps1 from Tooling/New-CIWorktreeForJob.ps1
- [x] Extend Tooling/Check-Runner.ps1 to verify installed LabVIEW year/minor
- [x] Enforce .lvversion in Tooling/Run-CICompositeLocal.ps1 (with explicit override switch)
- [x] Enforce .lvversion in Tooling/Run-CICompositeLocal-Auto.ps1 (with explicit override switch)
- [x] CI: add a version gate job that fails fast and exports version outputs

## Phase B (Runner and Workflow Hardening)
- [x] Standardize workflow inputs to use version outputs from the gate
- [x] Add clear failure messages for mismatch cases (CI + local)
- [x] Add guard to prevent accidental overrides of LABVIEW_VERSION_YEAR/MINOR
- [x] Add docs in README or Tooling/README for version contract

## Phase C (Observability + Portability)
- [x] Add summary output to GitHub Step Summary for version checks
- [x] Add unit tests or Pester tests for version parsing and mismatch behavior
- [x] Add a dry-run mode for local tooling to validate versions without running jobs
- [x] Document runner setup expectations and registry probe logic

## Phase D (Tooling Lint Hardening)
- [x] Add PSScriptAnalyzer job to CI and repo settings/baseline
- [x] Remove/rename unapproved verbs in Tooling scripts
- [x] Fix automatic variable assignments in tests/tooling
- [x] Eliminate remaining analyzer warnings (baseline at zero)
