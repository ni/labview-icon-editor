# LabVIEW Icon Editor

This repository contains:

1. Source files for the **LabVIEW Icon Editor**  
2. Tools and guides for **manual** and **PowerShell**-based development  
3. Instructions for **local CI/CD** setups (with a focus on self-hosted runners, exemplified using GitHub Actions)

---

## Table of Contents

- [Part I: Icon Editor Setup & Distribution](#part-i-icon-editor-setup--distribution)
  - [1. Compatible LabVIEW Versions](#1-compatible-labview-versions)
  - [2. Editing Guide (Manual)](#2-editing-guide-manual)
  - [3. Editing Guide (PowerShell)](#3-editing-guide-powershell)
  - [4. Distribution Guide (Manual)](#4-distribution-guide-manual)
  - [5. Distribution Guide (VI Package via PowerShell)](#5-distribution-guide-vi-package-via-powershell)

- [Part II: Local CI/CD Setup (Example: GitHub Actions)](#part-ii-local-cicd-setup-example-github-actions)
  - [1. Introduction](#1-introduction)
  - [2. Quickstart](#2-quickstart)
  - [3. Detailed Guide](#3-detailed-guide)
    - [3.1 Development vs. Testing](#31-development-vs-testing)
    - [3.2 Available CI Workflows](#32-available-ci-workflows)
    - [3.3 Setting Up a Self-Hosted Runner](#33-setting-up-a-self-hosted-runner)
    - [3.4 Running the Actions Locally](#34-running-the-actions-locally)
    - [3.5 Example Developer Workflow](#35-example-developer-workflow)
- [Next Steps and Conclusion](#next-steps-and-conclusion)

---

## Part I: Icon Editor Setup & Distribution

### 1. Compatible LabVIEW Versions

- Source is saved in **LabVIEW 2021 SP1** format.
- Development can be done in **LabVIEW 2021** or **LabVIEW 2024**, as long as you preserve the **2021 file format**.

---

### 2. Editing Guide (Manual)

Because the Icon Editor is part of the LabVIEW development environment, **modifications** require changes to installed files.

1. **Clone** this repository to a development location, for example:  
   ```
   C:\dev\labview-icon-editor
   ```
2. **Run** `Tooling\Prepare LV to Use Icon Editor Source.vi`. It will:
   - Remove `<LabVIEW>\resource\plugins\lv_icon.lvlibp`
   - Remove `<LabVIEW>\vi.lib\LabVIEW Icon API`
   - Update `LocalHost.LibraryPaths` in your `labview.ini` to point to your local repo, e.g.:
     ```
     LocalHost.LibraryPaths="C:\labview-icon-editor"
     ```
3. **Open** `lv_icon_editor.lvproj` in LabVIEW.
4. **Locate** the top-level VI in **Project Explorer** at:
   ```
   My Computer » resource/plugins » lv_icon.lvlib » lv_icon.vi
   ```

---

### 3. Editing Guide (PowerShell)

Use the provided scripts to automate the same steps above, across both LabVIEW 32-bit and 64-bit.

> **Before proceeding**: Back up these files/folders from your LabVIEW installation:
> ```
> <LabVIEW>\resource\plugins\lv_icon.lvlibp
> <LabVIEW>\vi.lib\LabVIEW Icon API\*
> ```

1. **Clone** the repo into `C:\`, for example:
   ```
   C:\labview-icon-editor
   ```
   Then apply the dependencies in `Tooling\deployment\Dependencies.vipc` to **both** LabVIEW 2021 (32-bit and 64-bit).
2. **Open PowerShell** in **administrator mode** and navigate to the `pipeline\scripts` folder of your local repo.
3. **Run**:
   ```powershell
   .\Set_Development_Mode.ps1 -RelativePath "C:\labview-icon-editor"
   ```
   This script:
   - Deletes the shipping `lv_icon.lvlibp`
   - Removes the default LabVIEW Icon API
   - Updates `LocalHost.LibraryPaths` in `labview.ini` to point to your local repo
4. **Open** `lv_icon_editor.lvproj` in LabVIEW.
5. **Find** the top-level VI:
   ```
   My Computer » resource/plugins » lv_icon.lvlib » lv_icon.vi
   ```

---

### 4. Distribution Guide (Manual)

Follow these steps to **distribute** your custom icon editor to another machine:

1. **Build** the **Editor Packed Library** in your LabVIEW Project to produce:
   ```
   lv_icon.lvlibp
   ```
2. On the **target** machine:
   1. Rename the shipping icon editor:
      ```
      <LabVIEW>\resource\plugins\lv_icon.lvlibp
      ```
      to
      ```
      lv_icon.lvlibp.ship
      ```
   2. Archive (backup) the shipping Icon API folder:
      ```
      <LabVIEW>\vi.lib\LabVIEW Icon API
      ```
   3. **Copy** your custom files over:
      - `<LabVIEW>\resource\plugins\lv_icon.lvlibp`
      - `<LabVIEW>\vi.lib\LabVIEW Icon API\*`

---

### 5. Distribution Guide (VI Package via PowerShell)

This process uses **VI Package Manager** (VIPM) to build and install a package. First, confirm that the build tools work before editing the icon editor source:

1. **Apply Dependencies**  
   - In VIPM, select LabVIEW 2021 (32-bit) and apply `\Tooling\deployment\dependencies.vipc`.  
   - Switch to LabVIEW 2021 (64-bit) and apply the same VIPC again.
2. **Disable Security Warnings (Optional)**  
   - In LabVIEW 2021 (32-bit & 64-bit), go to **Tools » Options » Security** and enable **Run VI without warning** if you want to skip manual acknowledgment of “Run When Opened” VIs.
   
   <img width="607" alt="Security Option" src="https://github.com/user-attachments/assets/5a2429c6-aca6-412a-8998-1e19876548dd" />

3. **Open PowerShell** (Admin), navigate to:
   ```
   C:\labview-icon-editor\pipeline\scripts\
   ```
   
   <img width="617" alt="PowerShell scripts folder" src="https://github.com/user-attachments/assets/b55b323f-ed2d-4e62-8b04-110ef7929ad1" />

4. **Build** the VI Package:
   ```powershell
   .\Build.ps1 -RelativePath "C:\labview-icon-editor" -AbsolutePathScripts "C:\labview-icon-editor\pipeline\scripts"
   ```
   <img width="619" alt="Build script execution" src="https://github.com/user-attachments/assets/976df4de-b253-4046-8ca1-2469265fd487" />
   
   - Ensure **LabVIEW** and **VI Package Manager** are closed before running this.  
   - After ~15 minutes, a VI Package (`ni_icon_editor-x.x.x.x`) will appear under `builds\VI Package`.  
   - **Install** it in VIPM (run VIPM as admin).
5. **Edit** the source, then **re-run** the build script to produce a new VI Package whenever you want to test changes.
6. **Revert** the environment if needed:
   ```powershell
   .\RevertDevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"
   ```
   This removes `LocalHost.LibraryPaths` changes and restores the default Icon API.

---

## Part II: Local CI/CD Setup (Example: GitHub Actions)

This section covers automating build and test workflows on a **self-hosted runner**, using a CI system like GitHub Actions as an example.

### 1. Introduction

Automating the Icon Editor build, test, and distribution pipeline locally offers:

- **Consistent** build/test steps on every machine.  
- **Minimized manual overhead** for toggling LabVIEW environment settings.  
- **Easily shareable VI Packages** corresponding to each commit or workflow run.

> **Prerequisites**:  
> - Verify you have the required LabVIEW versions and dependencies installed (see [Part I](#part-i-icon-editor-setup--distribution)).  
> - Install [PowerShell (7.x+)](https://github.com/PowerShell/PowerShell/releases/latest) and [Git](https://github.com/git-for-windows/git/releases/latest).

---

### 2. Quickstart

Here is a brief overview for advanced users wanting to run CI-like workflows locally:

1. **Install** PowerShell & Git  
   - [PowerShell Releases](https://github.com/PowerShell/PowerShell/releases/latest)  
   - [Git for Windows Releases](https://github.com/git-for-windows/git/releases/latest)
2. **Restart** Windows to ensure environment variables are properly loaded.
3. **Configure** a Self-Hosted Runner (if using GitHub Actions) under **Settings > Actions > Runners**.
4. **Add Required Variables**:
   - **GlobalBuildEnv Environment Variable**:  
     ```bash
     ICON_BUILD_INFO
     ```
     With a JSON value, for example:
     ```bash
     {
       "major": 1,
       "minor": 0,
       "patch": 0,
       "buildCounter": 0
     }
     ```
   - **Repository Variable**:  
     ```bash
     AGENTWORKINGFOLDER
     ```
     Example value:
     ```bash
     C:\actions-runner\_work\labview-icon-editor\labview-icon-editor
     ```
5. **Enable Development Mode** (using a script or a CI workflow) to switch LabVIEW to “editor mode.”
6. **Run Unit Tests**, then **Build VI Package** to produce artifacts.
7. **Disable Development Mode** to revert to a clean environment.

---

### 3. Detailed Guide

#### 3.1 Development vs. Testing

- **Development Mode**  
  - Temporarily modifies `labview.ini` and `vi.lib` for LabVIEW 2021 (both 32-bit & 64-bit).  
  - Allows direct editing of the Icon Editor source.
  
- **Testing with VI Packages**  
  - VI Packages provide a consistent method to test and distribute changes.  
  - Each package correlates to a specific commit, simplifying version tracking.

**Illustration**  
<img width="345" alt="Icon Editor QA Workflow" src="https://github.com/user-attachments/assets/9c279b4e-7899-4a00-a3fd-c3ba185130b2" />

---

#### 3.2 Available CI Workflows

If you’re using a CI system like GitHub Actions, you might have these main workflows:

- **Build VI Package**  
  - Generates 32-bit and 64-bit builds, then packages them into a single VI Package artifact.
- **Enable Runner Development Mode**  
  - Configures LabVIEW for editing the source (updates `labview.ini` and `vi.lib`).
- **Disable Runner Development Mode**  
  - Reverts those modifications.
- **Run Unit Tests**  
  - Executes automated tests against the Icon Editor.

**Example Menu**  
<img width="254" alt="Actions Menu" src="https://github.com/user-attachments/assets/1b17801b-d136-4507-9e76-7b430d26446c" />

---

#### 3.3 Setting Up a Self-Hosted Runner

> **Note**: If you use a different CI system, configure a comparable build agent or runner.

1. **Install** [PowerShell (7.x+)](https://github.com/PowerShell/PowerShell/releases/latest) & [Git](https://github.com/git-for-windows/git/releases/latest).
2. **Restart** your system to ensure paths are recognized.
3. **In your repository** settings, add a new self-hosted runner:
   - **Settings > Actions > Runners**  
   - Follow the on-screen instructions (download, configure, and register the runner).
4. **Set Environment & Repository Variables** in your CI system (see the [Quickstart](#2-quickstart) for details).
5. **Confirm** LabVIEW 2021 SP1 (32-bit & 64-bit) is installed, and apply your VIPC dependencies.

---

#### 3.4 Running the Actions Locally

1. **Enable Development Mode** (e.g., run “Enable Runner Development Mode” in your CI or execute `Set_Development_Mode.ps1`).
2. **Run Unit Tests** to verify the environment is ready.
3. **Build VI Package** to generate artifacts for distribution (~15 minutes).
4. **Disable Development Mode** to restore a standard LabVIEW installation.

---

#### 3.5 Example Developer Workflow

1. **Enable Development Mode**  
   - Switch LabVIEW to “editor mode” so you can modify the Icon Editor source.
2. **Make Changes**  
   - For example, adjust a control or add new icon templates.
3. **Run Unit Tests**  
   - Validate that all test VIs pass with your changes.
4. **Build VI Package**  
   - Produces a single VI Package that can be downloaded and installed.
5. **Disable Development Mode**  
   - Revert `vi.lib` and `labview.ini` to normal.
6. **Install & Verify**  
   - Download the generated VI Package artifact.
   - Open VIPM in admin mode and install your custom package.
   - Launch LabVIEW to confirm the changes.

---

## Next Steps and Conclusion

- For **day-to-day editing**: Choose **manual** steps or **PowerShell** scripts from [Part I](#part-i-icon-editor-setup--distribution).  
- For **automated builds and tests**: Follow [Part II](#part-ii-local-cicd-setup-example-github-actions) to integrate with your CI system.  
- **Share your custom icon editor**: Distribute it manually or as a VI Package for easy collaboration.  
- **Restore your LabVIEW environment**: Run `RevertDevelopmentMode.ps1` or your “Disable Development Mode” workflow to maintain a clean environment after testing.

> If you encounter issues or need additional features, please open an Issue or Pull Request. Enjoy building and customizing your own **LabVIEW Icon Editor**!
