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
- **Attach** `.vip` artifacts to a new GitHub Release (unless it’s a pull request).  
- Seamlessly handle **fork** scenarios—**GPG signing** is enabled if `github.repository` is your main repo, disabled otherwise.

> **Prerequisites**:  
> - **LabVIEW 2021 SP1 (32-bit and 64-bit)** both required.  
> - The relevant **VIPC** file is now at `Tooling/deployment/runner_dependencies.vipc`.  
> - [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases/latest)  
> - [Git for Windows](https://github.com/git-for-windows/git/releases/latest)

<a name="quickstart"></a>
## 2. Quickstart

**For experienced users**, a brief overview:

1. **Install Required Software**  
   - Ensure both **LabVIEW 2021 SP1 32-bit and 64-bit** are installed.  
   - [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases/latest)  
   - [Git for Windows](https://github.com/git-for-windows/git/releases/latest)

2. **Apply the VIPC (optional)**  
   - If your environment needs certain dependencies, **apply** `Tooling/deployment/runner_dependencies.vipc` in both 32-bit and 64-bit LabVIEW 2021 SP1.

3. **Configure a Self-Hosted Runner**  
   - Go to **Settings → Actions → Runners** in your (forked) repo.  
   - Follow GitHub’s steps to add a Windows runner.

4. **Development Mode Toggle**  
   - (Optional) Toggle LabVIEW dev mode (`Set_Development_Mode.ps1` or `RevertDevelopmentMode.ps1`) via the **Development Mode Toggle** workflow.

5. **Run Unit Tests**  
   - Use the **Run Unit Tests** workflow to confirm environment health.

6. **Build VI Package**  
   - Invoke **Build VI Package & Release** to produce `.vip`, automatically version your code (labels vs. default patch), and optionally create a GitHub Release.

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

2. **Build VI Package & Release**  
   - **Label-based** semantic versioning (`major`, `minor`, `patch`). Defaults to `patch` if no label.  
   - **Counts existing tags** (`v*.*.*-build*`) to increment the global build number.  
   - **Fork-friendly** GPG: disabled for forks to avoid passphrase prompts.  
   - Publishes `.vip` as an artifact and optionally creates a GitHub Release if not a pull request.

3. **Run Unit Tests**  
   - Executes test scripts to validate your Icon Editor code in a stable environment.


<a name="setting-up-a-self-hosted-runner"></a>
### 3. Setting Up a Self-Hosted Runner

**Steps**:

1. **Install LabVIEW 2021 SP1 (32-bit and 64-bit)**  
   - Confirm both are present on your Windows machine.  
   - Apply `Tooling/deployment/runner_dependencies.vipc` to each if needed.

2. **Install PowerShell 7+ and Git**  
   - Reboot if newly installed so environment variables are recognized.

3. **Add a Self-Hosted Runner**  
   - **Settings → Actions → Runners** → **New self-hosted runner**  
   - Follow GitHub’s CLI instructions.

4. **Labels** (optional)  
   - If the workflow references `runs-on: [self-hosted, iconeditor]`, label your runner accordingly or update the YAML’s `runs-on` lines.


<a name="running-the-actions-locally"></a>
### 4. Running the Actions Locally

With your runner online:

1. **Enable Dev Mode** (if needed)  
   - **Actions → Development Mode Toggle**, set `mode: enable`.

2. **Run Unit Tests**  
   - Confirm everything passes in logs. Some tests might rely on dev mode; see the logs for details.

3. **Build VI Package & Release**  
   - Produces `.vip`, bumps the version, and can create a Git tag + GitHub Release (if not a PR).  
   - Artifacts appear in the run summary under **Artifacts**.

4. **Disable Dev Mode** (if used)  
   - `mode: disable` reverts your LabVIEW environment.

5. **Review the `.vip`**  
   - Download from **Artifacts** or check your Release page if a release was created.


<a name="example-developer-workflow"></a>
### 5. Example Developer Workflow

1. **Enable Development Mode**: if you plan to actively modify the Icon Editor code inside LabVIEW.  
2. **Code & Test**: Make changes, run **Run Unit Tests** to confirm stability.  
3. **Open a Pull Request**:  
   - Assign a version bump label if you want `major`, `minor`, or `patch`.  
   - The workflow checks this label upon merging.  
4. **Merge**:  
   - **Build VI Package & Release** triggers, incrementing version and uploading `.vip`.  
5. **Disable Dev Mode**: Return to a normal LabVIEW environment.  
6. **Install & Verify**: Download the `.vip` artifact for final validations.


## 4. Next Steps

- **Check the Main Repo’s [README.md](../README.md)**: for environment disclaimers, additional tips, or project-specific instructions.  
- **Extend the Workflows**: You can add custom steps for linting, coverage, or multi-version LabVIEW tests.  
- **Submit Pull Requests**: If you refine scripts or fix issues, open a PR with logs showing your updated workflow runs.  
- **Troubleshoot**: If manual environment edits are needed, consult `ManualSetup.md` or the original documentation for advanced configuration steps.


**Happy Building!** By integrating these workflows, you’ll maintain a **robust, automated CI/CD** pipeline for the LabVIEW Icon Editor—complete with **semantic versioning**, **build artifact uploads**, and **GPG-signing** or **GPG-free** mode for forks.
