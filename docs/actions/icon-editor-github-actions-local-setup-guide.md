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

> **Prerequisites**: See the main repository’s [README.md](https://github.com/ni/labview-icon-editor#) for required software and any additional environment details.

---

<a name="quickstart"></a>
## Quickstart

**For experienced users**, here is a brief overview:

1. **Install PowerShell & Git**  
   - [PowerShell Latest Release](https://github.com/PowerShell/PowerShell/releases/latest)  
   - [Git for Windows Latest Release](https://github.com/git-for-windows/git/releases/latest)
2. **Restart Windows**  
   - Ensures environment variables are properly set.
3. **Configure a Self-Hosted Runner**  
   - Go to your fork’s **Settings > Actions > Runners** and follow GitHub’s instructions.
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
   - **Repository Variable**:  
     Create the following repository variable (in **Settings > Secrets and variables > Actions**):  
     ```bach
     AGENTWORKINGFOLDER
     ```
     With the value:  
     ```bach
     C:\actions-runner\_work\labview-icon-editor\labview-icon-editor
     ```
5. **Enable Development Mode**  
   - Manually run the “Enable Runner Development Mode” workflow.
6. **Run Unit Tests**, then **Build VI Package**  
   - Use the “Run Unit Tests” workflow for validation.  
   - Use the “Build VI Package” workflow to produce the artifacts.
7. **Disable Development Mode**  
   - Revert your environment with the “Disable Runner Development Mode” workflow.

---

<a name="detailed-guide"></a>
## Detailed Guide

The following sections provide **step-by-step** instructions and additional context.

<a name="development-vs-testing"></a>
### 1. Development vs. Testing

#### Development Mode
- **Purpose**: Editing the Icon Editor source requires special tokens in `LabVIEW.ini` and changes to `vi.lib` for both 32-bit and 64-bit LabVIEW 2021.  
- **Manual Overhead**: Doing this repeatedly by hand is time-consuming, especially if you need to toggle between a “clean” and a “development” environment often.

#### Testing with VI Packages
- **Purpose**: VI Packages provide a reproducible, traceable way to distribute and test changes across different machines or developers.  
- **Benefit**: Each package build is tied to a specific commit or workflow run, making it easier to correlate reported issues with the exact code baseline.

**Example QA Flow**  
<img width="345" alt="Icon Editor QA Workflow" src="https://github.com/user-attachments/assets/9c279b4e-7899-4a00-a3fd-c3ba185130b2" />

A [GitHub action run](https://github.com/ni/labview-icon-editor/actions/runs/13741632917) can store the generated VI Package for easy download and review.

---

<a name="available-github-actions"></a>
### 2. Available GitHub Actions

Below are the primary workflows you can trigger from your fork. Confirm all prerequisites from the repository’s README are met before running them.

- **Build VI Package**  
  - Creates 32-bit and 64-bit **Packed Project Libraries** for LabVIEW 2021.  
  - Generates a **VI Package** artifact (~15 minutes).

- **Disable Runner Development Mode**  
  - Reverts changes made to `vi.lib` and `LabVIEW.ini` (32-bit & 64-bit).  
  - **Duration**: ~2 minutes.

- **Enable Runner Development Mode**  
  - Updates `vi.lib` and `LabVIEW.ini` to allow source editing.  
  - **Duration**: ~2 minutes.

- **Run Unit Tests**  
  - Executes the Icon Editor’s unit test suite.  
  - **Requires** development mode be enabled first (~5 minutes).

**Actions Menu Example**  
<img width="254" alt="Actions Menu" src="https://github.com/user-attachments/assets/1b17801b-d136-4507-9e76-7b430d26446c" />

---

<a name="setting-up-a-self-hosted-runner"></a>
### 3. Setting Up a Self-Hosted Runner

Follow these steps **exclusively on Windows** (latest version recommended):

1. **Install PowerShell (7.x+)**  
   [Download the MSI Installer](https://github.com/PowerShell/PowerShell/releases/latest)
2. **Install Git**  
   [Download Git for Windows](https://github.com/git-for-windows/git/releases/latest)
3. **Restart Your System**  
   Ensures newly installed software paths are recognized.
4. **Add a New Runner in GitHub**  
   - In your forked repo, go to **Settings > Actions > Runners**.  
   - Click **New self-hosted runner** and follow GitHub’s on-screen instructions.  
   - This typically involves downloading the runner app, configuring a directory, and registering it with your repository.
5. **Set Environment & Repository Variables**  
   - **In GlobalBuildEnv**:  

     ```bach
     ICON_BUILD_INFO
     ```

     ```bach
     {
       "major": 1,
       "minor": 0,
       "patch": 0,
       "buildCounter": 0
     }
     ```

   - **At the Repository Level**:  

     ```bach
     AGENTWORKINGFOLDER
     ```

     ```bach
     C:\actions-runner\_work\labview-icon-editor\labview-icon-editor
     ```

6. **Confirm LabVIEW 2021 SP1 and NI Package Manager**  
   - Ensure LabVIEW 2021 SP1 32-bit and 64-bit are installed.
   - Apply VIPC located on Tooling\deployment\Dependencies.vipc on 32 and 64 bit LabVIEW 2021 SP1  

---

<a name="running-the-actions-locally"></a>
### 4. Running the Actions Locally

Once the runner is configured:

1. **Enable Runner Development Mode**  
   - Go to **Actions** in your fork.  
   - Select **Enable Runner Development Mode** and click **Run workflow**.  
   - If it fails initially, run it again (initialization might require a second attempt).

2. **Run Unit Tests**  
   - With development mode enabled, select **Run Unit Tests**.  
   - Validates that your environment is correctly set up.

3. **Build VI Package**  
   - Then, select **Build VI Package**.  
   - Wait (~15 minutes) for it to compile both 32-bit/64-bit code and produce a VI Package artifact.

4. **Disable Runner Development Mode**  
   - Revert your environment by running **Disable Runner Development Mode**.  
   - This ensures a “clean” LabVIEW environment for testing the newly built VI Package.

Afterward, download the artifact from the Build VI Package run and install it via VI Package Manager, ensuring to run VI Package manager on with Admin rights.

---

<a name="example-developer-workflow"></a>
### 5. Example Developer Workflow

Here is an example of how you might **develop, test, package, and install** a change to the Icon Editor:

1. **Enable Development Mode**  
   - Run the “Enable Runner Development Mode” action to configure LabVIEW for direct source editing.
2. **Modify Icon Editor Source**  
   - For instance, change the UI background from gray to green.
3. **Run Unit Tests**  
   - Ensure your changes pass existing tests.
4. **Build VI Package**  
   - Produce a 32-bit/64-bit library and a VI Package artifact.
5. **Disable Development Mode**  
   - Restore a normal LabVIEW environment configuration.
6. **Install and Validate**  
   - Download the VI Package artifact from the workflow run.  
   - Open VI Package manager in admin mode
   - Install it locally.  
   - Launch LabVIEW to confirm the UI color change or other modifications.

**Video Demonstration**  

---

<a name="next-steps"></a>
## Next Steps

- **Review the Main [README.md](../README.md)** for additional environment prerequisites, LabVIEW setup steps, or other dependencies.  
- **Modify or Extend Workflows**: Feel free to adjust these `.yml` files for tasks such as linting or code coverage.  
- **Open a GitHub Issue**: If you encounter problems or have suggestions, please open an issue in the repository.

---
