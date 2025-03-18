# Local CI/CD Workflows

This document explains how to automate build, test, and distribution steps for the Icon Editor using GitHub Actions. It includes features such as **fork-friendly GPG signing** toggles, **automatic version bumping** (using labels), and the **release creation** process. Additionally, it shows how you can **brand** the resulting VI Package with **organization** and **repository** metadata for unique identification.

---

## Table of Contents

1. [Introduction](#1-introduction)  
2. [Quickstart](#2-quickstart)  
3. [Detailed Guide](#3-detailed-guide)  
   1. [Development vs. Testing](#31-development-vs-testing)  
   2. [Available CI Workflows](#32-available-ci-workflows)  
   3. [Setting Up a Self-Hosted Runner](#33-setting-up-a-self-hosted-runner)  
   4. [Running the Actions Locally](#34-running-the-actions-locally)  
   5. [Example Developer Workflow](#35-example-developer-workflow)

---

## 1. Introduction

Automating your Icon Editor builds and tests:
- Provides consistent steps for every commit or pull request
- Minimizes manual toggling of LabVIEW environment settings
- Stores build artifacts (VI Packages) in GitHub for easy download
- Automatically versions releases using **semantic version** logic
- Handles GPG signing in the main repo but **disables** it for forks (so fork owners aren’t blocked by passphrase prompts)
- **Allows you to brand** each VI Package build with your organization or repository name for unique identification

**Prerequisites**:  
- LabVIEW 2021 SP1  (32 and 64-bit)  
- PowerShell 7+  
- Git for Windows  

---

## 2. Quickstart

1. **Install PowerShell & Git**  
   Ensure your environment has the required tools before setting up the workflows.

2. **Configure a Self-Hosted Runner**  
   Under **Settings → Actions → Runners** in your GitHub repo or organization, add a runner with LabVIEW installed.

3. **Enable/Disable Development Mode**  
   You can toggle Development Mode either via the “Development Mode Toggle” workflow or manually.  
   - Development Mode modifies `labview.ini` to reference your local source code.

4. **Run Unit Tests**  
   Use the **Run Unit Tests** workflow to confirm your environment is valid.  
   - Typically run with Dev Mode **disabled** unless you’re testing dev features specifically.

5. **Build VI Package & Release**  
   - Produces `.vip` artifacts automatically, **including** optional metadata fields (`-CompanyName`, `-AuthorName`) that let you **brand** your package.  
   - Uses **label-based** version bumping (major/minor/patch) on pull requests.  
   - Creates tags and releases for direct pushes (unless it’s a PR).

6. **Disable Dev Mode** (optional)  
   Reverts your environment to normal LabVIEW settings, removing local overrides.

**Note**: Passing metadata fields like `-CompanyName` or `-AuthorName` to the build script helps incorporate your **organization** or **repo** name directly into the final VI Package. This makes your build easily distinguishable from other forks or variants.

---

## 3. Detailed Guide

### 3.1 Development vs. Testing

- **Development Mode**:  
  A specialized configuration where LabVIEW references local paths for the Icon Editor code. Useful for debugging or certain dev features.  
  - Enable via `Set_Development_Mode.ps1` or the **Development Mode Toggle** workflow.

- **Testing / Distributable Builds**:  
  Typically done in **normal** LabVIEW mode. If you forget to disable Dev Mode, tests or builds might rely on your local dev environment in unexpected ways.

---

### 3.2 Available CI Workflows

Below are the **key GitHub Actions** provided in this repository:

1. **[Development Mode Toggle](https://github.com/ni/labview-icon-editor/actions/workflows/development-mode-toggle.yml)**
   - Invokes `Set_Development_Mode.ps1` or `RevertDevelopmentMode.ps1`.  
   - Usually triggered via `workflow_dispatch` for manual toggling.

2. **[Build VI Package & Release](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)**  
   - **Automatically** versions your code based on PR labels (`major`, `minor`, `patch`) or defaults to `patch` for direct pushes.  
   - Uses a **build counter** to ensure each artifact is uniquely numbered (e.g., `v1.2.3-build4`).  
   - **Fork-Friendly**: Disables GPG signing if it detects a fork (so no passphrase is needed). In the **main repo** (`ni/labview-icon-editor`), signing remains active.  
   - Produces the `.vip` file via a PowerShell script (e.g., `Build.ps1`).  
   - **You can pass metadata** (e.g., `-CompanyName`, `-AuthorName`) to embed your organization or repository into the generated `.vip` for distinct branding.  
   - Uploads the `.vip` artifact to GitHub’s build artifacts.  
   - Creates a **GitHub Release** for direct pushes (not for PRs).

3. **[Run Unit Tests](https://github.com/ni/labview-icon-editor/actions/workflows/run-unit-tests.yml)**  
   - Executes `unit_tests.ps1` in `pipeline/scripts`.  
   - Usually expects Dev Mode **disabled** for consistent test results.  
   - Also triggered on pull requests for validation.

---

### 3.3 Setting Up a Self-Hosted Runner

1. **Install Prerequisites**:  
   - LabVIEW 2021 SP1  
   - PowerShell 7+  
   - Git for Windows

2. **Add Self-Hosted Runner**:  
   Go to **Settings → Actions → Runners** in your GitHub repository (or organization) and follow the steps to register a runner on your machine that has LabVIEW installed.

3. **Label the Runner** (optional):  
   - You may label it `self-hosted, iconeditor` (or adjust the workflow’s `runs-on` lines to match your chosen labels).  
   - This helps ensure the correct environment is used for building the Icon Editor.

---

### 3.4 Running the Actions Locally

Although GitHub Actions primarily runs on GitHub-hosted or self-hosted agents, you can **replicate** the general process locally:

1. **Enable Development Mode** (if necessary to do dev tasks):  
   - Run the “Development Mode Toggle” workflow with `enable` or manually call `Set_Development_Mode.ps1`.

2. **Run Unit Tests**:  
   - Confirm everything passes in your local environment.  
   - If you have custom or dev references, ensure Dev Mode is toggled appropriately.

3. **Build VI Package**:  
   - Manually invoke `Build.ps1` from `pipeline/scripts` to generate a `.vip`.  
   - Pass optional metadata fields (e.g., `-CompanyName`, `-AuthorName`) if you want your build to be **branded**.  
   - On GitHub Actions, the workflow will produce and upload the artifact automatically.

4. **Disable Dev Mode**:  
   - Revert to a normal LabVIEW environment so standard usage or testing can resume.

---

### 3.5 Example Developer Workflow

**Scenario**: You want to implement a new feature, test it, and produce a **uniquely branded** `.vip`.

1. **Enable Development Mode**:  
   - Either via the **Development Mode Toggle** workflow or `Set_Development_Mode.ps1`.

2. **Implement & Test**:  
   - Use the **Run Unit Tests** workflow (or local script) to verify your changes pass.  
   - Keep Dev Mode enabled if needed for debugging; disable if you want a “clean” environment.

3. **Open a Pull Request** and **Label** it:  
   - Assign `major`, `minor`, or `patch` to control the version bump.  
   - The CI will validate your code but *won’t* tag or release until merged.

4. **Merge the PR** into `develop` (or `main`):  
   - The **Build VI Package & Release** workflow automatically tags the commit (e.g., `v1.2.0-build7`) and uploads the `.vip`.  
   - **Inside** that `.vip`, the fields for **“Company Name”** and **“Author Name (Person or Company)”** can reflect your **organization** or **repo**, ensuring it’s easy to identify which fork or team produced the build.

5. **Disable Development Mode**:  
   - Switch LabVIEW back to normal mode.  
   - Optionally install the resulting `.vip` to confirm your new feature in a production-like environment.

---

## Final Notes

- **Artifact Storage**: The `.vip` file is accessible under the Actions run summary (click “Artifacts”).  
- **Forking**: If another user forks your repo, the new **fork** sees GPG signing disabled automatically, preventing passphrase errors.  
- **Version Enforcement**: Pull requests without a version label default to `patch`; you can enforce labeling with an optional “Label Enforcer” step if desired.  
- **Branding**: To highlight the **organization** or **repository** behind a particular build, simply pass `-CompanyName` and `-AuthorName` (or similar parameters) into the `Build.ps1` script. This metadata flows into the final **Display Information** of the Icon Editor’s VI Package.

By adopting these workflows—**Development Mode Toggle**, **Run Unit Tests**, and especially **Build VI Package & Release**—you can maintain a **streamlined, consistent** CI/CD process for the Icon Editor, while customizing the VI Package with your own **unique** or **fork-specific** branding.
