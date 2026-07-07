# Runner Setup Guide

This document explains how to locally set up and run the **LabVIEW Icon Editor** workflows on a **self-hosted runner** using **GitHub Actions**.

## Table of Contents

1. [Introduction](#introduction)  
2. [Quickstart](#quickstart)  
3. [Detailed Guide](#detailed-guide)  
   1. [Development vs. Testing](#development-vs-testing)  
   2. [Available GitHub Actions](#available-github-actions)  
   3. [Setting Up a Self-Hosted Runner](#setting-up-a-self-hosted-runner)  
   4. [Running the Actions Locally](#running-the-actions-locally)  
   5. [Example Developer Workflow](#example-developer-workflow)  
4. [Next Steps](#next-steps)

<a name="introduction"></a>
## 1. Introduction

This document details how to automate **building**, **testing**, and **packaging** the **LabVIEW Icon Editor** on **Windows** using **GitHub Actions** on a **self-hosted runner**. By employing these workflows, you can:

- **Eliminate** manual tasks like editing `vi.lib` or toggling `labview.ini`.  
- **Run** consistent builds and tests across different machines or developers.  
- **Automatically version** your Icon Editor code via **semantic labeling** (major/minor/patch) plus a global build counter.
- **Upload** the `.vip` artifact for download; the workflow does **not** create tags or GitHub releases.

Additionally, **you can pass metadata fields** (like **organization** or **repository name**) to the **build script**. These fields are embedded into the **VI Package** display information, effectively **branding** the Icon Editor package with a unique identifier. This is especially useful when multiple forks or organizations produce their own versions of the Icon Editor—ensuring each `.vip` is clearly labeled with the correct “author” or “company.”

> **Prerequisites**:
> - **LabVIEW 2021 (21.0), 32-bit and 64-bit**.
> - The relevant **VIPC** file is now at `.github/actions/apply-vipc/runner_dependencies.vipc`.
> - [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases/latest)
> - [Git for Windows](https://github.com/git-for-windows/git/releases/latest)

<a name="quickstart"></a>
## 2. Quickstart

**For experienced users**, a brief overview:

1. **Install Required Software**
   - Ensure **LabVIEW 2021 (21.0) 32-bit and 64-bit** are installed.
   - [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases/latest)
   - [Git for Windows](https://github.com/git-for-windows/git/releases/latest)

2. **Apply the VIPC**
  - Apply `.github/actions/apply-vipc/runner_dependencies.vipc` with VIPM in **LabVIEW 2021 (21.0) 32-bit**; repeat for **LabVIEW 2021 (21.0) 64-bit**.
   - This is required on new runners because the workflow's `apply-deps` job in `.github/workflows/ci-composite.yml` runs only when `.vipc` files change (`if: needs.changes.outputs.vipc == 'true'`). When no `.vipc` updates exist, dependencies aren't installed automatically, so apply the VIPC manually.

3. **Configure a Self-Hosted Runner**  
   - Go to **Settings → Actions → Runners** in your (forked) repo.  
   - Follow GitHub’s steps to add a Windows runner.

4. **Development Mode Toggle**  
   - (Optional) Toggle LabVIEW dev mode (`Set_Development_Mode.ps1` or `RevertDevelopmentMode.ps1`) via the **Development Mode Toggle** workflow.

5. **Run Tests**
   - Run the tests using the **CI Pipeline (Composite)** workflow; its dedicated **test** job executes the unit tests.

6. **Build VI Package**
   - Invoke the **Build VI Package** job within the CI Pipeline (Composite) workflow to produce a `.vip` using the version computed by the workflow's separate **version** job (see that job's output for the generated version). Publishing tags or GitHub releases requires a separate workflow.
   - **You can also** pass in **org/repository** info (e.g., `-CompanyName "MyOrg"` or `-AuthorName "myorg/myrepo"`) to brand the resulting package with your unique identifiers.

7. **Disable Dev Mode** (Optional)  
   - Revert environment once building/testing is done.


<a name="detailed-guide"></a>
## 3. Detailed Guide

<a name="development-vs-testing"></a>
### 1. Development vs. Testing

**Development Mode**  
- Temporarily reconfigures `labview.ini` and `vi.lib` so LabVIEW loads your Icon Editor source directly, renaming `lv_icon.lvlibp` to `lv_icon.ship` and packaging the LabVIEW Icon API.  
- Enable/disable via the **Development Mode Toggle** workflow.

**Testing / Distributable Builds**  
- Usually done in a **normal** LabVIEW environment (Dev Mode disabled).  
- Ensures that the `.vip` artifact or tests reflect a standard environment.


<a name="available-github-actions"></a>
### 2. Available GitHub Actions

1. **Development Mode Toggle**  
   - `mode: enable` → calls `Set_Development_Mode.ps1`.  
   - `mode: disable` → calls `RevertDevelopmentMode.ps1`.  
   - `labview_version` (default `2021`, only `2021` is supported).
   - Great for reconfiguring LabVIEW for local dev vs. distribution builds.

2. **CI Pipeline (Composite)**
   - Includes a **test** job for unit tests, a **version** job that computes semantic versioning, and a **build-vi-package** job that packages the `.vip` using the version job's outputs.
   - **Label-based** semantic versioning (`major`, `minor`, `patch`). Defaults to `patch` if no label.
   - **Derives build number from total commit count** (`git rev-list --count HEAD`).
   - **Fork-friendly**: runs on forks without requiring signing keys.
   - Publishes `.vip` as an artifact; creating Git tags or GitHub releases requires a separate workflow.
   - **Branding the Package**:
     - You can **pass** metadata parameters like `-CompanyName` and `-AuthorName` into the build script. These map to fields in the **VI Package** (e.g., “Company Name,” “Author Name (Person or Company)”).
     - This means each package can show the **organization** and **repository** that produced it, providing a **unique ID** if you have multiple forks or parallel versions.


<a name="setting-up-a-self-hosted-runner"></a>
### 3. Setting Up a Self-Hosted Runner

**Steps**:

1. **Install LabVIEW 2021 (21.0), 32-bit and 64-bit**  
   - Confirm both are present on your Windows machine.  
   - Apply `.github/actions/apply-vipc/runner_dependencies.vipc` to each if needed.
   - **Version contract**: CI treats `.lvversion` as the single source of truth. The runner sanity step validates that the installed LabVIEW version matches `.lvversion` and fails fast if it does not.
   - **Registry probe logic** (Windows): the runner sanity check looks for installs in:
     - `C:\Program Files\National Instruments\LabVIEW <Year>` (64-bit)
     - `C:\Program Files (x86)\National Instruments\LabVIEW <Year>` (32-bit)
     - Registry keys:
       - `HKLM:\SOFTWARE\National Instruments\LabVIEW <Year>`
       - `HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW <Year>`
     - It checks `Path`, `InstallDir`, or `InstallPath` values for a valid install root.
   - If you install to a custom path, ensure the registry keys above are present so the runner can locate LabVIEW.
   - **Runner ACL preflight (no-LabVIEW dev mode)**:
     - When `LVIE_FORCE_NO_LABVIEW_DEVMODE=1` is set, runner sanity also checks write access to:
       - `vi.lib`
       - `vi.lib\LabVIEW Icon API` (if present)
       - `resource\plugins`
       - `LabVIEW.ini`
     - If the runner service account cannot write to these paths, dev-mode enable/revert will fail on that bitness.
     - You can override the check with `LVIE_RUNNER_ACL_CHECK=0` (not recommended).
     - You can enable auto-fix with `LVIE_RUNNER_ACL_AUTOFIX=1` to grant **Modify** permissions to the current runner identity.
     - Auto-fix requires elevated rights on the runner machine; otherwise pre-grant access manually (for example with `icacls`).

2. **Install PowerShell 7+ and Git**  
   - Reboot if newly installed so environment variables are recognized.

3. **Add a Self-Hosted Runner**  
   - **Settings → Actions → Runners** → **New self-hosted runner**  
   - Follow GitHub’s CLI instructions.

4. **Labels** (optional)
   - The workflow uses the `self-hosted-windows-lv` label by default (or `LVIE_RUNNER_LABEL` if set). Its `runs-on` expression also references `self-hosted-linux-lv` for potential Linux jobs, though the default matrix runs only on Windows. Label your runner accordingly, and prepare a Linux runner with `self-hosted-linux-lv` if you expand the matrix.

5. **Runner diagnostics cleanup (recommended)**
   - Some runner failures can occur before checkout if old diagnostics logs accumulate under the runner's `_diag\pages` folder.
   - Use the job-started hook to clean that folder before each job.
   - Copy the scripts from the repo to the runner:
     - `.github\scripts\cleanup-runner-diag-pages.ps1`
     - `.github\scripts\runner-job-started-clean-diag.ps1`
   - Place them under `<runner-root>\scripts\` and set the hook in `<runner-root>\.env`:
     - `ACTIONS_RUNNER_HOOK_JOB_STARTED=C:\path\to\runner\scripts\runner-job-started-clean-diag.ps1`
   - Restart the runner service after updating `.env`.
   - Optional: set `RUNNER_DIAG_RETENTION_DAYS=7` in `.env` if you want to keep recent logs.
   - The cleanup skips any diagnostics file that is still in use, so the job does not fail.

6. **Standardize worktree root under the runner directory (recommended)**
   - Use a short path under the runner root to avoid Windows path-length issues.
   - Recommended path: `<runner-root>\_work\lvie\w` (for example `C:\actions-runner\_work\lvie\w`).
   - Runner contract helper (run from repo root):
     - `pwsh -NoProfile -File .\Tooling\Setup-Runner.ps1 -RunnerRoot C:\actions-runner -Scope Machine`
   - This writes `<runner-root>\_work\lvie\runner-contract.json` and sets `LVIE_WORKTREE_ROOT`, `LVIE_ARTIFACT_ROOT`, `LVIE_LOCK_ROOT`, and `LVIE_LOG_ROOT`.
   - Restart the runner service after setting Machine/User environment variables.

7. **Stateless runner bootstrap (no service restart)**
   - Workflows call the `runner-bootstrap` action, which runs `Tooling/Initialize-Runner.ps1` at job start to refresh the runner contract and export `LVIE_*` variables into the job environment.
   - This avoids relying on Machine/User environment variables and does not require restarting the runner service.


<a name="running-the-actions-locally"></a>
### 4. Running the Actions Locally

With your runner online:

1. **Enable Dev Mode** (if needed)
   - **Actions → Development Mode Toggle**, set `mode: enable`.
   - `labview_version` is fixed to `2021` if provided.

2. **Run Tests via CI Pipeline (Composite)**
   - Execute the workflow and review the **test** job logs to confirm all unit tests pass.

3. **Build VI Package**
   - Produces `.vip` using the version computed in the **version** job (review that job's output for version details). The workflow only uploads the artifact; creating tags or GitHub releases requires additional steps.
   - **Pass** your **org/repo** info (e.g. `-CompanyName "AcmeCorp"` / `-AuthorName "AcmeCorp/IconEditor"`) to embed in the final package.
   - Artifacts appear in the run summary under **Artifacts**.

4. **Disable Dev Mode** (if used)  
   - `mode: disable` reverts your LabVIEW environment.
   - Keep `labview_version` set to `2021` if you include it.

5. **Review the `.vip`**
   - Download from **Artifacts**. Publishing to a GitHub release requires a separate workflow.

#### Worktree naming (CI)
CI jobs run from short-path worktrees to avoid Windows path limits. Each job creates:
- `ci-<jobhash>-<bitness>-<runid>-<attempt>`
- `jobhash` = first 8 chars of SHA1(`GITHUB_JOB`) to keep job names unique.
- Some workflows insert an extra variant token (e.g. LabVIEW version) between `<jobhash>` and `<bitness>`.
- Example: `C:\dev\ci-D170BDEE-64-21534416929-1`

The workflow exports:
- `REPO_ROOT` → worktree path (authoritative for scripts)
- `PROJECT_PATH` → `$REPO_ROOT\lv_icon_editor.lvproj`
- `LABVIEW_VERSION_YEAR` / `LABVIEW_MINOR_REVISION` → derived from `.lvversion` (e.g., `21.0` → `2021` and minor `0`)

CI treats `.lvversion` in `REPO_ROOT` as the canonical LabVIEW version for the run.

#### Run CI for a specific commit (workflow_dispatch)
If you need deterministic runs for a specific commit, use the helper script:
```
pwsh -NoProfile -File .\Tooling\Run-CICompositeForCommit.ps1 -Sha <commit>
```

Notes:
- The script creates a temporary `ci-run/<shortsha>` branch and dispatches the workflow on it.
- Use `-CleanupRemote` to delete the temporary branch after dispatch.


<a name="example-developer-workflow"></a>
### 5. Example Developer Workflow

1. **Enable Development Mode**: if you plan to actively modify the Icon Editor code inside LabVIEW.  
2. **Code & Test**: Make changes, run the **CI Pipeline (Composite)** workflow (its **test** job runs unit tests) to confirm stability.
3. **Open a Pull Request**:  
   - Assign a version bump label if you want `major`, `minor`, or `patch`.  
   - The workflow checks this label upon merging.  
4. **Merge**:
   - The **CI Pipeline (Composite)** workflow triggers, with the **version** job computing the version and the **Build VI Package** job using that version to package and upload the `.vip`.
   - **Metadata** (such as company/repo) is already integrated into the final `.vip`, so each build is easily identified.
5. **Disable Dev Mode**: Return to a normal LabVIEW environment.  
6. **Install & Verify**: Download the `.vip` artifact for final validations.

---

## 4. Next Steps

- **Check the Main Repo’s [README.md](../README.md)**: for environment disclaimers, additional tips, or project-specific instructions.  
- **Extend the Workflows**: You can add custom steps for linting, coverage, or multi-version LabVIEW tests.  
- **Submit Pull Requests**: If you refine scripts or fix issues, open a PR with logs showing your updated workflow runs.  
- **Troubleshoot**: If manual environment edits are needed, consult `ManualSetup.md` or the original documentation for advanced configuration steps.  

**Happy Building!** By integrating these workflows, you’ll maintain a **robust, automated CI/CD** pipeline for the LabVIEW Icon Editor—complete with **semantic versioning**, **build artifact uploads**, and **metadata branding** (company/repo).
