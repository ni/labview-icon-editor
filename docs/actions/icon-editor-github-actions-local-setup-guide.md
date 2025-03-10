# LabVIEW Icon Editor GitHub Actions (Local Setup Guide)

1. [Introduction](#introduction)  
2. [Quickstart](#quickstart)  
3. [Detailed Guide](#detailed-guide)  
   1. [Development vs. Testing](#development-vs-testing)  
   2. [Available GitHub Actions](#available-github-actions)  
   3. [Setting Up a Self-Hosted Runner](#setting-up-a-self-hosted-runner)  
   4. [Running the Actions Locally](#running-the-actions-locally)  
   5. [Example Developer Workflow](#example-developer-workflow)  
4. [Next Steps](#next-steps)

---

<a name="introduction"></a>
## Introduction

This document explains how to automate building, testing, and packaging the **LabVIEW Icon Editor** on **Windows** using **GitHub Actions**. By hosting these actions **locally** (i.e., on a self-hosted runner), you can:

- **Minimize manual tasks** such as editing `vi.lib` or toggling `LabVIEW.ini` settings.  
- **Run builds and tests** consistently across multiple developers or machines.  
- **Produce shareable VI Packages** that track and distribute changes for easier testing.

> **Prerequisites**: See the main repository’s [README.md](../README.md) for required software (LabVIEW 2021 SP1, VIPM, PowerShell, etc.) and any additional environment details.

---

<a name="quickstart"></a>
## Quickstart

**For experienced users**, here is a brief overview:

1. **Install PowerShell & Git**  
    - PowerShell (Latest): https://github.com/PowerShell/PowerShell/releases/latest  
    - Git for Windows (Latest): https://github.com/git-for-windows/git/releases/latest  
2. **Restart Windows**  
    Ensures environment variables are properly set.
3. **Configure a Self-Hosted Runner**  
4. **Add Required Variables**  
   - **GlobalBuildEnv Environment Variable**:  
     Create the following variable **in the GlobalBuildEnv environment**:  
     ```bach
     ICON_BUILD_INFO
     ```
     Use this JSON value:  
     ```bach
     {
       "major": 1,
       "minor": 0,
       "patch": 0,
       "buildCounter": 0
     }
     ```
    - Go to your fork’s **Settings > Actions > Runners** and follow GitHub’s instructions.
4. **Toggle Development Mode (Manual)**  
    - Use the **Development Mode Toggle** workflow, passing `mode: enable` or `mode: disable`.
5. **Run Unit Tests**, then **Build VI Package**  
    - Use the **Run Unit Tests** workflow to verify your changes.  
    - Use the **Build VI Package** workflow to produce artifacts (auto-increments `.github/buildCounter.txt`).
6. **Disable Dev Mode (When Done)**  
    - Revert your environment by calling the **Development Mode Toggle** workflow with `mode: disable`.

---

<a name="detailed-guide"></a>
## Detailed Guide

The following sections provide **step-by-step** instructions and additional context.

<a name="development-vs-testing"></a>
### 1. Development vs. Testing

#### Development Mode
- **Purpose**: Editing the Icon Editor source requires adjusting `labview.ini` and `vi.lib` for 32-bit/64-bit LabVIEW 2021.  
- **Automation**: Instead of having separate “Enable” and “Disable” workflows, you can call the **Development Mode Toggle** workflow with:
    ```
    mode: enable
    ```
  or:
    ```
    mode: disable
    ```

#### Testing with VI Packages
- **Purpose**: VI Packages provide a reproducible, traceable way to distribute and test changes across different machines or developers.  
- **Benefit**: Each package build is tied to a specific commit or workflow run, making it easier to correlate reported issues with the exact code baseline.  
- **Build Numbering**: The “Build VI Package” workflow automatically increments a build counter (`.github/buildCounter.txt`), appends it to the package version, and stores the final `.vip` artifact.

---

<a name="available-github-actions"></a>
### 2. Available GitHub Actions

Below are the primary workflows you can trigger from your fork. Make sure **LabVIEW 2021 SP1** is installed and your environment matches the repository’s prerequisites.

- **Development Mode Toggle**
    - Toggles LabVIEW into dev mode (`Set_Development_Mode.ps1`) or reverts it (`RevertDevelopmentMode.ps1`) based on the input:
        ```
        with:
          mode: enable   # or disable
        ```
    - **Duration**: ~1–2 minutes.

- **Build VI Package**
    - Creates a 32-bit and 64-bit library for LabVIEW 2021.  
    - Auto-increments the build revision in `.github/buildCounter.txt`.  
    - Produces a **VI Package** artifact (~15 minutes).

- **Run Unit Tests**
    - Executes the Icon Editor’s unit test suite in `unit_tests.ps1`.  
    - Expected to pass if dev mode is properly disabled, unless certain tests require dev mode for specialized checks.

*(References to environment variables like `ICON_BUILD_INFO` or `AGENTWORKINGFOLDER` are no longer required; the new workflows rely on `$env:GITHUB_WORKSPACE` for path resolution.)*

---

<a name="setting-up-a-self-hosted-runner"></a>
### 3. Setting Up a Self-Hosted Runner

Follow these steps **on Windows**:

1. **Install PowerShell (7.x+)**
    https://github.com/PowerShell/PowerShell/releases/latest

2. **Install Git**
    https://github.com/git-for-windows/git/releases/latest

3. **Restart Your System**
    Ensures newly installed software paths are recognized.

4. **Add a New Runner in GitHub**
    - In your forked repo, go to **Settings > Actions > Runners**.  
    - Click **New self-hosted runner** and follow GitHub’s on-screen instructions.

5. **Confirm LabVIEW 2021 SP1**
    - Must have 32-bit and 64-bit installed if both are needed for your scenario.  
    - Apply the VIPC from `Tooling\deployment\Dependencies.vipc` to both 32/64-bit LabVIEW 2021 SP1.

---

<a name="running-the-actions-locally"></a>
### 4. Running the Actions Locally

Once the runner is configured:

1. **Toggle Dev Mode (Enable)**
    - In **Actions**, select **Development Mode Toggle**, choose “Run workflow,” and set:
      ```
      mode: enable
      ```
    - This updates `labview.ini` and `vi.lib` for a dev environment.

2. **Run Unit Tests**
    - Validate your environment. Some tests might rely on dev mode being off; check logs to confirm expectations.

3. **Build VI Package**
    - Launch the **Build VI Package** workflow to compile 32-bit/64-bit code.  
    - A `.vip` file is generated (~15 minutes) and attached as an artifact.

4. **Toggle Dev Mode (Disable)**
    - Return to **Development Mode Toggle**, but set:
      ```
      mode: disable
      ```
    - Reverts your environment to a “clean” LabVIEW configuration.

Download the resulting `.vip` artifact from **Build VI Package** if you want to test it on another machine using VIPM.

---

<a name="example-developer-workflow"></a>
### 5. Example Developer Workflow

1. **Enable Dev Mode**
    mode: enable
2. **Make Changes**
    - Edit the Icon Editor’s source code as needed.
3. **Run Unit Tests**
    - Confirm test VIs pass as expected.
4. **Build VI Package**
    - Produces a versioned `.vip` artifact with an incremented build number.
5. **Disable Dev Mode**
    mode: disable
6. **Install & Validate**
    - Download the `.vip` artifact, install in VIPM, and check functionality outside of dev mode.

---

<a name="next-steps"></a>
## Next Steps

- **Review the Main [README.md](../README.md)** for environment prerequisites and disclaimers.
- **Extend Workflows**: Adjust YAML files for extra tasks (linting, coverage, etc.).
- **Submit Pull Requests**: If you improve the scripts (PowerShell or YAML), open a PR with evidence (workflow logs) that your changes work on your runner.
- **Troubleshooting**: [Manual Setup & Distribution docs](./ManualSetup.md).

---
