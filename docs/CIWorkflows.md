# Local CI/CD Workflows

This document explains how to automate build, test, and distribution steps for the Icon Editor using a CI system like GitHub Actions.

## Table of Contents

- 1. Introduction
- 2. Quickstart
- 3. Detailed Guide
  - 3.1 Development vs. Testing
  - 3.2 Available CI Workflows
  - 3.3 Setting Up a Self-Hosted Runner
  - 3.4 Running the Actions Locally
  - 3.5 Example Developer Workflow

---

1. Introduction

Automating your Icon Editor builds and tests:
- Provides consistent steps for each commit
- Minimizes manual toggling of LabVIEW environment settings
- Stores build artifacts (VI Packages) in GitHub for easy download

Prerequisites: LabVIEW 2021 SP1, PowerShell 7+, Git for Windows

---

2. Quickstart

1. Install PowerShell & Git
2. Configure a self-hosted runner under GitHub Actions
3. Enable Dev Mode (via the “Development Mode Toggle” workflow or manually)
4. Run Unit Tests to ensure your environment is correct
5. Build VI Package to produce .vip artifacts
6. Disable Dev Mode to restore a clean LabVIEW environment

---

3. Detailed Guide

3.1 Development vs. Testing

- Development Mode:
  Temporarily reconfigures labview.ini and vi.lib to point to your local source code.
- Testing / Distributable Builds:
  Requires a normal LabVIEW environment; otherwise, some tests or build steps might fail.

---

3.2 Available CI Workflows

Below are the key GitHub Actions for this repository:

1. [Development Mode Toggle](actions/development-mode-toggle.md)
   - Toggles LabVIEW to dev mode (Set_Development_Mode.ps1) or reverts it (RevertDevelopmentMode.ps1).
   - Usually triggered via workflow_dispatch so a user can manually enable/disable.
2. [Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)
   - Calls Build_all.ps1 to produce .vip artifacts.
   - Uses a new build counter to increment version numbers automatically.
3. [Run Unit Tests](https://github.com/ni/labview-icon-editor/actions/workflows/run-unit-tests.yml)
   - Executes unit_tests.ps1 in pipeline/scripts.
   - Expects dev mode to be disabled if you want standard results.

---

3.3 Setting Up a Self-Hosted Runner

1. Install PowerShell 7+ and Git for Windows.
2. Add a self-hosted runner via Settings > Actions > Runners in GitHub.
3. Register the runner on a machine that has LabVIEW 2021 SP1 installed.
4. (Optional) Label your runner as self-hosted, iconeditor to match the workflows.

---

3.4 Running the Actions Locally

1. Enable Development Mode: Run the “Development Mode Toggle” workflow with mode = enable
2. Run Unit Tests: Verify everything passes with the custom environment
3. Build VI Package: Artifacts (the .vip file) will be uploaded automatically
4. Disable Development Mode: Revert to normal LabVIEW for any final checks or standard usage

---

3.5 Example Developer Workflow

1. Enable Development Mode to code changes
2. Test your changes via “Run Unit Tests”
3. Build VI Package for distribution
4. Disable Development Mode to restore a clean environment
5. Install or share your new .vip artifact for final validation
