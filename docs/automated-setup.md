
# Automated Setup and Editing Instructions

This document describes how to **build, test, and distribute** the **LabVIEW Icon Editor** using **PowerShell**. You can run these scripts locally on your development or self-hosted runner, or within **GitHub Actions**. By making this process open-source, we enable community collaboration, easier troubleshooting, and a more transparent build pipeline for the Icon Editor that ships with LabVIEW.

## Table of Contents

1. [Overview and Prerequisites](#overview-and-prerequisites)
2. [Editing Guide (PowerShell)](#editing-guide-powershell)  
3. [Distribution Guide (VI Package via PowerShell)](#distribution-guide-vi-package-via-powershell)  
4. [Integrating with GitHub Actions](#integrating-with-github-actions)  
5. [How `Build.ps1` Works](#how-buildps1-works)  
6. [Local vs. CI Usage](#local-vs-ci-usage)  
7. [Example Developer Workflow](#example-developer-workflow)

---

<a name="overview-and-prerequisites"></a>
## 1. Overview and Prerequisites

- **Purpose**: Provide a **PowerShell-centric** approach to build, test, and package the Icon Editor—either locally or via GitHub Actions.  
- **Why PowerShell?**:  
  - Simplifies applying VIPCs, building `.lvlibp`, and producing a `.vip` artifact.  
  - Debug locally the same steps used in CI, ensuring consistent results.

- **Prerequisites**:
  1. **LabVIEW 2021 (21.0), both 32-bit and 64-bit**.
  2. **PowerShell 7+** and **Git**.  
  3. **Apply** `.github\actions\apply-vipc\runner_dependencies.vipc` to **LabVIEW 2021 (21.0), 32-bit & 64-bit**—matching the `apply-deps` matrix in [`../.github/workflows/ci-composite.yml`](../.github/workflows/ci-composite.yml).

---

<a name="editing-guide-powershell"></a>
## 2. Editing Guide (PowerShell)

1. **Back Up** (highly recommended):  
   `<LabVIEW>\resource\plugins\lv_icon.lvlibp`  
   `<LabVIEW>\vi.lib\LabVIEW Icon API`

2. **Clone** the [Icon Editor](https://github.com/ni/labview-icon-editor.git) to your development location.

3. **Apply** dependencies:  
   `.github\actions\apply-vipc\runner_dependencies.vipc` to **LabVIEW 2021 (21.0), 32-bit & 64-bit**.

4. **Open** PowerShell (Admin):
   Navigate to `.github\actions\set-development-mode`

5. **Enable Dev Mode**:
   ```powershell
   .\Set_Development_Mode.ps1 -MinimumSupportedLVVersion 2021
   ```

   Removes the default `lv_icon.lvlibp` and points LabVIEW to your local Icon Editor code.

6. **Open** the project:
   `lv_icon_editor.lvproj`  
   Edit the Icon Editor source as needed.

---

<a name="distribution-guide-vi-package-via-powershell"></a>
## 3. Distribution Guide (VI Package via PowerShell)

1. **Apply Dependencies** in VIPM:
   - Set LabVIEW to 2021 (32-bit) and apply `.github\actions\apply-vipc\runner_dependencies.vipc`.
   - Repeat for **2021 (64-bit)** so both bitnesses are covered.

2. **Disable LabVIEW Security Warnings** *(to prevent popups from "run when opened" VIs)*:
   - **Tools → Options → Security** → **Run VI Without Warnings**.

3. **Open** PowerShell (Admin), go to:
   ```powershell
   cd .github\actions\build
   ```

4. **Run** `Build.ps1`:
   ```powershell
   .\Build.ps1 `
       -RepoRoot "C:\labview-icon-editor" `
       -Major 1 -Minor 2 -Patch 3 -Build 45 `
    -Commit "my-commit-sha" `
    -LabVIEWMinorRevision 0 `
    -Verbose
    ```
    This generates a `.vip` in `builds\VI Package`.

   *Branding tip:* Add optional metadata fields such as `-CompanyName` and `-AuthorName` to the command above to embed your organization or repository name in the package. These values appear in the final VI Package metadata, helping identify builds from different forks.

5. **Revert Dev Mode (optional)**:
   ```powershell
   ..\revert-development-mode\RevertDevelopmentMode.ps1 -MinimumSupportedLVVersion 2021
   ```

6. **Install** the `.vip` in VIPM (as Admin). Validate your custom Icon Editor changes.

---

<a name="integrating-with-github-actions"></a>
## 4. Integrating with GitHub Actions

We provide **GitHub Actions** that wrap these same PowerShell scripts for building the Icon Editor:

- **Development Mode Toggle**: Uses `Set_Development_Mode.ps1` or `RevertDevelopmentMode.ps1`.
- **Build VI Package**: Internally calls `Build.ps1` to produce a `.vip` artifact (and can draft a release if configured).

Unit tests run within the `test` job of the composite CI workflow defined in `.github/workflows/ci-composite.yml`.

### Injecting Organization/Repo for Unique Builds

In many workflows, you may want the **organization** or **repository** name **injected** into the VI Package to brand the build uniquely. For instance, if you have a GitHub Actions workflow, you can pass environment variables like `${{ github.repository_owner }}` (the org or user) and `${{ github.repository }}` (e.g. `myorg/myfork`) to `Build.ps1`. This is useful when:

- **Maintaining multiple forks** that each produce their own Icon Editor package.  
- **Distinguishing** who built the editor if multiple variants circulate internally.  

An example step in a GitHub Actions file might look like:

```yaml
- name: Build Icon Editor
  run: |
    pwsh .\.github\actions\build\Build.ps1 `
      -RepoRoot "$env:GITHUB_WORKSPACE" `
      -Major 1 -Minor 2 -Patch 0 -Build 10 `
      -Commit "${{ github.sha }}" `
      # You can pass metadata fields to brand the package:
      -CompanyName "${{ github.repository_owner }}" `
      -AuthorName "${{ github.event.repository.name }}" `
      -Verbose
```

Passing these metadata fields ensures the final `.vip` clearly identifies **which fork** built it, and under **which organization**.

**Key Points**:
- The scripts you run locally are **exactly** what the GitHub Actions will call.  
- Makes debugging/troubleshooting simpler since you can mirror CI steps locally.  
- The build process is **open-source**, letting contributors collaborate on the same scripts that ship the official LabVIEW Icon Editor.

---

<a name="how-buildps1-works"></a>
## 5. How `Build.ps1` Works

`Build.ps1` orchestrates the entire build pipeline for the Icon Editor:

1. **Cleans up** old `.lvlibp` files in `resource\plugins`.  
2. **Applies** VIPC for both 32-bit and 64-bit LabVIEW.  
3. **Builds** each bitness of the library (passing version info: `-Major`, `-Minor`, `-Patch`, `-Build`, `-Commit`).  
4. **Renames** results (`lv_icon_x86.lvlibp`, `lv_icon_x64.lvlibp`).  
5. **Constructs** JSON data (including optional fields for organization, repo name, etc.).  
6. **Builds** the final `.vip` (64-bit) with `build_vip.ps1`:
   - The **metadata** you pass (like `CompanyName` and `AuthorName`) gets placed into the **Display Information** section of the `.vipb` file to **brand** the package.  
   - The optional `-LabVIEWMinorRevision` parameter can override default minor version logic.

7. **Closes** LabVIEW sessions in between steps.

### Why Inject Repo/Org Fields?

- **Unique Identification**: If multiple teams or forks produce an Icon Editor build, the `.vip` can identify **who** built it.  
- **Traceability**: Makes it easy to see the GitHub org/repo of the build in VIPM or LabVIEW’s “About” screen.  
- **No Manual Edits**: The script automatically merges your provided fields, so you don’t have to manually edit JSON or `.vipb` each time.

---

<a name="local-vs-ci-usage"></a>
## 6. Local vs. CI Usage

1. **Local**:
   - Enable dev mode → Edit code → Run `Build.ps1` → (Optionally) revert dev mode.  
   - You can pass additional metadata arguments to brand your `.vip` locally, too.

2. **CI (GitHub Actions)**:
   - Same scripts run automatically or on demand.  
   - Pull requests can increment version (major/minor/patch) and produce `.vip`.  
   - Optionally inject the organization and repository name to **brand** each build.

---

<a name="example-developer-workflow"></a>
## 7. Example Developer Workflow

1. **Enable Dev Mode**
   - `Set_Development_Mode.ps1` or a “Development Mode Toggle” workflow run.
2. **Develop and Test**
   - Run tests locally or through the composite CI workflow's `test` job to confirm changes.
3. **Open PR**
   - Label (`major`, `minor`, `patch`) for semver bump.
   - Actions use `Build.ps1` to produce `.vip` on merges.
4. **Merge**
   - The [`.github/workflows/ci-composite.yml`](../.github/workflows/ci-composite.yml) workflow uploads the built `.vip` as an artifact in its "Upload VI Package" step.
   - It does not automatically create a GitHub Release; draft one manually and attach the artifact if desired.
5. **Disable Dev Mode**
   - Revert environment.
6. **Install**
   - Use VIPM to install the `.vip` and confirm final functionality.

All scripts are fully open-source—**collaborators** can debug or extend them locally with minimal friction. By passing organization/repo data in either local builds or GitHub Actions, you ensure your **unique** version of the Icon Editor is **clearly labeled** and **easily traced** to its source.

