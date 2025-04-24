# Powershell Command Line Interface Instructions

This document describes how to **build, test, and distribute** the **LabVIEW Icon Editor** VI Package using **PowerShell**. You can run these scripts locally on your development or self-hosted runner, or within **GitHub Actions**. By making this process open source, we enable community collaboration, easier troubleshooting, and a more transparent build pipeline for the Icon Editor that ships with LabVIEW.

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
- **Why PowerShell?**  
  - Simplifies applying VIPCs, building `.lvlibp`, and producing a `.vip` artifact.  
  - Lets you debug locally using the **exact same scripts** used in CI, ensuring consistent results between local and automated environments.

- **Prerequisites**:
  1. **LabVIEW 2021 SP1 (both 32-bit & 64-bit)**.
  2. **PowerShell 7+** and **Git**.
  3. **Apply** `tooling\deployment\runner_dependencies.vipc` to **both 32-bit & 64-bit LabVIEW**.

---

<a name="editing-guide-powershell"></a>
## 2. Editing Guide (PowerShell)

1. **Back Up** (highly recommended):  
   - `<LabVIEW>\resource\plugins\lv_icon.lvlibp`  
   - `<LabVIEW>\vi.lib\LabVIEW Icon API`

2. **Clone** the [Icon Editor](https://github.com/ni/labview-icon-editor.git) to your development location.

3. **Apply** dependencies:  
   - `Tooling\deployment\runner_dependencies.vipc` to **LabVIEW 2021 (32-bit) & LabVIEW 2021 (64-bit)**.

4. **Open** PowerShell (Admin), navigate to your working directory:
   ```
   pipeline\scripts
   ```

5. **Enable Dev Mode**:
   ```powershell
   .\Set_Development_Mode.ps1 -RelativePath "C:\labview-icon-editor"
   ```
   Removes the default `lv_icon.lvlibp` and points LabVIEW to your local Icon Editor code.

6. **Open** the project:
   ```
   lv_icon_editor.lvproj
   ```
   Edit the Icon Editor source as needed.

---

<a name="distribution-guide-vi-package-via-powershell"></a>
## 3. Distribution Guide (VI Package via PowerShell)

### Why & How for Branding the Package

When distributing your own fork or build of the Icon Editor, you may want to **uniquely brand** your `.vip` package with your **organization** and **repository** information (or any other metadata). This ensures:
- **Unique identification** if multiple organizations produce their own variants of the Editor.
- **Easier troubleshooting** by embedding your org/repo directly in the final VI Package metadata.

You can do so by passing metadata fields (like `-CompanyName` and `-AuthorName`) to the `Build.ps1` script. These are then injected into the final **DisplayInformationJSON** (see Section [How `Build.ps1` Works](#how-buildps1-works)).

### Steps to Build/Distribute

1. **Apply Dependencies** in VIPM:  
   - Set LabVIEW to **2021 (32-bit)**, apply `Tooling\deployment\runner_dependencies.vipc`.  
   - Repeat for **64-bit** if necessary.

2. **Disable LabVIEW Security Warnings** (to prevent popups from "run when opened" VIs):  
   - **Tools → Options → Security** → **Run VI Without Warnings**.

3. **Open** PowerShell (Admin), navigate to:
   ```
   pipeline\scripts
   ```

4. **Run** `Build.ps1` (with optional brand info):
   ```powershell
   .\Build.ps1 `
       -RelativePath "C:\labview-icon-editor" `
       -AbsolutePathScripts "C:\labview-icon-editor\pipeline\scripts" `
       -Major 1 -Minor 2 -Patch 3 -Build 45 `
       -Commit "my-commit-sha" `
       -LabVIEWMinorRevision 3 `
       -CompanyName "Acme Inc." `
       -AuthorName "acme-inc/lv-icon-editor" `
       -Verbose
   ```
   This generates a `.vip` in `builds\VI Package`. Your **organization** and **repo** details appear in the final package, helping brand your build uniquely.

5. **Revert Dev Mode (optional)**:
   ```powershell
   .\RevertDevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"
   ```

6. **Install** the `.vip` in VIPM (as Admin), validate your custom Icon Editor changes.

---

<a name="integrating-with-github-actions"></a>
## 4. Integrating with GitHub Actions

We provide **GitHub Actions** that wrap these same PowerShell scripts for building the Icon Editor. You can also pass **metadata** (e.g., repository or organization) directly via environment variables or YAML inputs:

```yaml
name: Build LabVIEW Icon Editor
on:
  push:
    branches: [ "main" ]

jobs:
  build:
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup PowerShell
        uses: actions/setup-powershell@v2

      - name: Build Script
        run: |
          pwsh .\Build.ps1 `
            -RelativePath "$env:GITHUB_WORKSPACE" `
            -AbsolutePathScripts "$env:GITHUB_WORKSPACE\pipeline\scripts" `
            -Major 1 -Minor 2 -Patch 3 -Build 45 `
            -Commit "${{ github.sha }}" `
            -LabVIEWMinorRevision 3 `
            -CompanyName "${{ github.repository_owner }}" `
            -AuthorName "${{ github.repository }}" `
            -Verbose
```

**Key Points**:
- `-CompanyName "${{ github.repository_owner }}"` ensures the package shows your org/user name.  
- `-AuthorName "${{ github.repository }}"` can embed the “repo” portion, e.g. `my-org/lv-icon-editor`.  
- The rest of the steps (applying VIPC, building the libraries) run identically to local usage, ensuring **consistency**.

---

<a name="how-buildps1-works"></a>
## 5. How `Build.ps1` Works

`Build.ps1` orchestrates the entire build:

1. **Clean**: Removes old `.lvlibp` files in `resource\plugins`.
2. **Apply VIPC**: For **32-bit** & **64-bit** LabVIEW, ensuring all dependencies are set.
3. **Build**: Invokes `Build_lvlibp.ps1` to produce `.lvlibp` files for both bitnesses, injecting version info (`-Major -Minor -Patch -Build`) and a `-Commit`.
4. **Rename**: Moves them to `lv_icon_x86.lvlibp` and `lv_icon_x64.lvlibp`.
5. **Construct DisplayInformationJSON**: 
   - Merges any metadata fields you pass in (e.g., **`-CompanyName`, `-AuthorName`**) so that the final `.vip` is **branded**.  
   - Also includes your version data in `"Package Version"`.
6. **Call `build_vip.ps1`**:
   - This script reads the JSON, modifies the `.vipb`, and builds the final **VI Package** with `g-cli`.  
   - The optional `-LabVIEWMinorRevision` param can override default minor version logic (e.g., 21.3).
7. **Close LabVIEW** (64-bit) after the build is done.

**Result**: A `.vip` file containing your version, commit, and brand/metadata in the Display Information fields.

---

<a name="local-vs-ci-usage"></a>
## 6. Local vs. CI Usage

1. **Local**:  
   - You can pass custom `-CompanyName` and `-AuthorName` directly on the PowerShell command line.  
   - For example, to brand the build “AcmeCorp” from “AcmeCorp/lv-icon-editor.”

2. **CI (GitHub Actions)**:  
   - Exactly the same script runs. The difference is that environment variables (like `${{ github.repository_owner }}`) feed into `-CompanyName`, etc.  
   - This way, each fork or org can produce a uniquely identified package.

---

<a name="example-developer-workflow"></a>
## 7. Example Developer Workflow

1. **Enable Dev Mode**  
   ```powershell
   .\Set_Development_Mode.ps1 -RelativePath "C:\labview-icon-editor"
   ```
2. **Develop & Test**  
   - You can open `lv_icon_editor.lvproj`, make changes, and run `Run_Unit_Tests.ps1`.
3. **Open PR**  
   - Mark your PR with semver changes (major/minor/patch).  
   - GitHub Actions picks it up, calls `Build.ps1`.
4. **Build**  
   - The resulting `.vip` is attached to releases or stored as an artifact, showing your **version** and **branding** (company/repo).
5. **Disable Dev Mode** (optional)  
   ```powershell
   .\RevertDevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"
   ```
6. **Install**  
   - Use VIPM to install the final `.vip` and confirm changes.

All scripts are fully open source—**collaborators** can debug or extend them locally with minimal friction. 

