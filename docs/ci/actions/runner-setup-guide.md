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
> - **LabVIEW 2021 SP1 (32-bit and 64-bit)** – and **LabVIEW 2023 (64-bit) for building the package**.
> - The relevant **VIPC** file is `runner_dependencies.vipc` at the repo root.
> - [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases/latest)
> - [Git for Windows](https://github.com/git-for-windows/git/releases/latest)

<a name="quickstart"></a>
## 2. Quickstart

**For experienced users**, a brief overview:

1. **Install Required Software**
   - Ensure **LabVIEW 2021 SP1 32-bit and 64-bit** are installed. If you plan to build the package, install **LabVIEW 2023 (64-bit)** as well.
   - [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases/latest)
   - [Git for Windows](https://github.com/git-for-windows/git/releases/latest)

2. **Apply the VIPC**
  - Apply `runner_dependencies.vipc` (repo root) with VIPM in **LabVIEW 2021 (32-bit)**; repeat for **LabVIEW 2021 (64-bit)**. If using **LabVIEW 2023 (64-bit)** for builds, apply the same VIPC there as well.
   - This is required on new runners because the workflow's `apply-deps` job in `.github/workflows/ci.yml` runs only when `.vipc` files change (`if: needs.changes.outputs.vipc == 'true'`). When no `.vipc` updates exist, dependencies aren't installed automatically, so apply the VIPC manually.

3. **Configure a Self-Hosted Runner**  
   - Go to **Settings → Actions → Runners** in your (forked) repo.  
   - Follow GitHub’s steps to add a Windows runner.

4. **Development Mode Toggle**  
   - (Optional) Toggle LabVIEW dev mode (`Set_Development_Mode.ps1` or `RevertDevelopmentMode.ps1`) via the **Development Mode Toggle** workflow.

5. **Run Tests**
   - Run the tests using the **CI Pipeline** workflow; its dedicated **test** job executes the unit tests.

6. **Build VI Package**
   - Invoke the **Build VI Package** job within the CI Pipeline workflow to produce a `.vip` using the version computed by the workflow's separate **version** job (see that job's output for the generated version). Publishing tags or GitHub releases requires a separate workflow.
   - **You can also** pass in **org/repository** info (e.g., `-CompanyName "MyOrg"` or `-AuthorName "myorg/myrepo"`) to brand the resulting package with your unique identifiers.

7. **Disable Dev Mode** (Optional)  
   - Revert environment once building/testing is done.


<a name="detailed-guide"></a>
## 3. Detailed Guide

<a name="development-vs-testing"></a>
### 1. Development vs. Testing

**Development Mode**  
- Temporarily reconfigures `labview.ini` and `vi.lib` so LabVIEW loads your Icon Editor source directly, it also removes `lv_icon.lvlibp`.  
- Enable/disable via the **Development Mode Toggle** workflow.

**Testing / Distributable Builds**  
- Usually done in a **normal** LabVIEW environment (Dev Mode disabled).  
- Ensures that the `.vip` artifact or tests reflect a standard environment.


<a name="available-github-actions"></a>
### 2. Available GitHub Actions

1. **Development Mode Toggle**  
   - `mode: enable` → calls `Set_Development_Mode.ps1`.  
   - `mode: disable` → calls `RevertDevelopmentMode.ps1`.  
   - Great for reconfiguring LabVIEW for local dev vs. distribution builds.

2. **CI Pipeline**
   - Includes a **test** job for unit tests, a **version** job that computes semantic versioning, and a **build-vip** job that packages the `.vip` using the version job's outputs.
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

1. **Install LabVIEW 2021 SP1 (32-bit and 64-bit)**  
   - Confirm both are present on your Windows machine.  
   - Apply `runner_dependencies.vipc` (repo root) to each if needed.

2. **Install PowerShell 7+ and Git**  
   - Reboot if newly installed so environment variables are recognized.

3. **Add a Self-Hosted Runner**  
   - **Settings → Actions → Runners** → **New self-hosted runner**  
   - Follow GitHub’s CLI instructions.

4. **Labels** (optional)
   - The workflow uses the `self-hosted-windows-lv` label. Its `runs-on` expression also references `self-hosted-linux-lv` for potential Linux jobs, though the default matrix runs only on Windows. Label your runner accordingly, and prepare a Linux runner with `self-hosted-linux-lv` if you expand the matrix.


<a name="running-the-actions-locally"></a>
### 4. Running the Actions Locally

With your runner online:

1. **Enable Dev Mode** (if needed)
   - **Actions → Development Mode Toggle**, set `mode: enable`.

2. **Run Tests via CI Pipeline**
   - Execute the workflow and review the **test** job logs to confirm all unit tests pass.

3. **Build VI Package**
   - Produces `.vip` using the version computed in the **version** job (review that job's output for version details). The workflow only uploads the artifact; creating tags or GitHub releases requires additional steps.
   - **Pass** your **org/repo** info (e.g. `-CompanyName "AcmeCorp"` / `-AuthorName "AcmeCorp/IconEditor"`) to embed in the final package.
   - Artifacts appear in the run summary under **Artifacts**.

4. **Disable Dev Mode** (if used)  
   - `mode: disable` reverts your LabVIEW environment.

5. **Review the `.vip`**
   - Download from **Artifacts**. Publishing to a GitHub release requires a separate workflow.


<a name="example-developer-workflow"></a>
### 5. Example Developer Workflow

1. **Enable Development Mode**: if you plan to actively modify the Icon Editor code inside LabVIEW.  
2. **Code & Test**: Make changes, run the **CI Pipeline** workflow (its **test** job runs unit tests) to confirm stability.
3. **Open a Pull Request**:  
   - Assign a version bump label if you want `major`, `minor`, or `patch`.  
   - The workflow checks this label upon merging.  
4. **Merge**:
   - The **CI Pipeline** workflow triggers, with the **version** job computing the version and the **Build VI Package** job using that version to package and upload the `.vip`.
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
