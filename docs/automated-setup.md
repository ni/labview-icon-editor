# Automated Setup & Editing Instructions

This document describes how to **build, test, and distribute** the **LabVIEW Icon Editor** using **PowerShell**. You can run these scripts locally on your development or self-hosted runner, or within **GitHub Actions**. By making this process open source, we enable community collaboration, easier troubleshooting, and a more transparent build pipeline for the Icon Editor that ships with LabVIEW.
## Table of Contents

1. [Overview & Prerequisites](#overview--prerequisites)
2. [Editing Guide (PowerShell)](#editing-guide-powershell)
3. [Distribution Guide (VI Package via PowerShell)](#distribution-guide-vi-package-via-powershell)
4. [Integrating with GitHub Actions](#integrating-with-github-actions)
5. [How `Build.ps1` Works](#how-buildps1-works)
6. [Local vs. CI Usage](#local-vs-ci-usage)
7. [Example Developer Workflow](#example-developer-workflow)

---
<a name="overview--prerequisites"></a>
## 1. Overview & Prerequisites

- **Purpose**: Provide a **PowerShell-centric** approach to build, test, and package the Icon Editor—either locally or via GitHub Actions.
- **Why PowerShell?**: .
  - Simplifies applying VIPCs, building `.lvlibp`, and producing a `.vip` artifact.
  - Debug locally the same steps used in CI, ensuring consistent results.

- **Prerequisites**:
  1. **LabVIEW 2021 SP1 (both 32-bit & 64-bit)**.
  2. **PowerShell 7+** and **Git**.
  3. **Apply** `tooling\deployment\runner_dependencies.vipc ` **(to both 32-bit & 64-bit)**.
<a name="editing-guide-powershell"></a>
## 2. Editing Guide (PowerShell)

1. **Back Up** (highly recommended):
<LabVIEW>\resource\plugins\lv_icon.lvlibp <LabVIEW>\vi.lib\LabVIEW Icon API

2. **Clone** the [Icon Editor](https://github.com/ni/labview-icon-editor.git) to your development location:

3. **Apply** dependencies:
Tooling\deployment\runner_dependencies.vipc to **LabVIEW 2021 (32-bit) & LabVIEW 2021 (64-bit)**.

4. **Open** PowerShell (Admin):
Navigate to your working directory pipeline\scripts

5. **Enable Dev Mode**:
```powershell
.\Set_Development_Mode.ps1 -RelativePath "C:\labview-icon-editor"
```

    Removes the default lv_icon.lvlibp and points LabVIEW to your local Icon Editor code.

6. Open the project:
lv_icon_editor.lvproj
Edit the Icon Editor source as needed.

<a name="distribution-guide-vi-package-via-powershell"></a>
## 3. Distribution Guide (VI Package via PowerShell)

1. **Apply Dependencies** in VIPM:
   - Set LabVIEW to 2021 (32-bit), apply `Tooling\deployment\runner_dependencies.vipc`.
   - Repeat for 64-bit if necessary.

2. **Disable LabVIEW Security Warnings** *(to prevent popups from "run when opened" VIs)*:
   - **Tools → Options → Security** → **Run VI Without Warnings**.

3. **Open** PowerShell (Admin), go to:

    pipeline\scripts

4. **Run** `Build.ps1`:

```powershell
.\Build.ps1 `
    -RelativePath "C:\labview-icon-editor" `
    -AbsolutePathScripts "C:\labview-icon-editor\pipeline\scripts" `
    -Major 1 -Minor 2 -Patch 3 -Build 45 `
    -Commit "my-commit-sha" `
    -LabVIEWMinorRevision 3 `
    -Verbose
```

    Generates a .vip in builds\VI Package

5. **Revert Dev Mode (optional):**

.\RevertDevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"

6. **Install the .vip in VIPM (as Admin). Validate your custom Icon Editor changes.**

<a name="integrating-with-github-actions"></a>
## 4. Integrating with GitHub Actions

We provide **GitHub Actions** that wrap these same PowerShell scripts for building the Icon Editor:

- **Development Mode Toggle**: Uses `Set_Development_Mode.ps1` or `RevertDevelopmentMode.ps1`.
- **Run Unit Tests**: Calls `unit_tests.ps1`.
- **Build VI Package & Release**: Internally calls `Build.ps1` to produce a `.vip` and create a GitHub Release.

**Key Points**:
- The scripts you run locally are **exactly** what the GitHub Actions will call.  
- Makes debugging/troubleshooting simpler since you can mirror CI steps locally.  
- The build process is **open source**, letting contributors collaborate on the same scripts that ship the official LabVIEW Icon Editor.

<a name="how-buildps1-works"></a>
## 5. How `Build.ps1` Works

`Build.ps1` orchestrates the entire build:
1. **Cleans up** old `.lvlibp` in `resource\plugins`.
2. **Applies** VIPC for 32-bit & 64-bit LabVIEW.
3. **Builds** each bitness library, passing `-Major`, `-Minor`, `-Patch`, `-Build`, `-Commit`.
4. **Renames** results (`lv_icon_x86.lvlibp`, `lv_icon_x64.lvlibp`).
5. **Builds** the final `.vip` (64-bit) with `build_vip.ps1`.
   - The optional `-LabVIEWMinorRevision` param can override default minor version logic.
6. **Closes** LabVIEW sessions in between steps.

---

<a name="local-vs-ci-usage"></a>
## 6. Local vs. CI Usage

1. **Local**:
   - Enable dev mode → Edit code → Run `Build.ps1` or `Run_Unit_Tests.ps1` → Revert dev mode.
2. **CI (GitHub Actions)**:
   - Same scripts run automatically or on demand.
   - Pull requests can increment version (major/minor/patch) and produce `.vip`.

---

<a name="example-developer-workflow"></a>
## 7. Example Developer Workflow

1. **Enable Dev Mode**  
   - `Set_Development_Mode.ps1` or a “Development Mode Toggle” workflow run.
2. **Develop & Test**  
   - Locally or via “Run Unit Tests” to confirm changes.
3. **Open PR**  
   - Label (`major`, `minor`, `patch`) for semver bump.  
   - Actions use `Build.ps1` to produce `.vip` on merges.
4. **Merge**  
   - Creates a GitHub Release, attaches the `.vip`.
5. **Disable Dev Mode**  
   - Revert environment.  
6. **Install**  
   - Use VIPM to install the `.vip` and confirm final functionality.

    All scripts are fully open source—**collaborators** can debug or extend them locally with minimal friction.
