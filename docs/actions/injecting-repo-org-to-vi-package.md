# Injecting Repo Name and Organization into the LabVIEW VI Package

This document explains how we leverage **PowerShell** scripts and **GitHub Actions** to insert **repository** and **organization** metadata into the LabVIEW Icon Editor’s VI Package, ensuring each build is **unique** and **traceable**.

---

## Table of Contents
1. [Overview](#overview)
2. [Why Inject Repo/Org Fields?](#why-inject-repoorg-fields)
3. [GitHub Actions and PowerShell](#github-actions-and-powershell)
4. [Overall CI/CD Flow](#overall-cicd-flow)
5. [Example Usage](#example-usage)
6. [Conclusion](#conclusion)

---

## Overview

In a multi-fork or multi-organization environment, **injecting the repository name and organization** into the VI Package:
- Creates distinct **branding** or “ownership” for each fork.
- Lets end users quickly see **which** organization built the Icon Editor.
- Maintains **consistent** versioning and naming conventions across builds.

We achieve this by:
1. **Constructing** a JSON object in `Build.ps1` that sets fields like:
   - `"Company Name"`  
   - `"Author Name (Person or Company)"`
2. **Calling** `build_vip.ps1`, which **parses** the JSON and **updates** the `.vipb` (VI Package Builder) file.
3. **Using** GitHub Actions environment variables (like `${{ github.repository_owner }}`) to pass the org name, and `${{ github.repository }}` for the repository name.

---

## Why Inject Repo/Org Fields?

1. **Unique Identification**  
   - If multiple teams produce their own version of the Icon Editor, each package can show **where** it came from.  
   - Avoids confusion when you have multiple `.vip` files with similar names.

2. **Traceability**  
   - When debugging or updating an installed package, you can see **which** organization or Git repo built it, ensuring faster troubleshooting.

3. **Automated Metadata**  
   - No manual editing: The build scripts automatically **pull** the organization and repo name from GitHub Actions, so the package metadata is always up-to-date.

---

## GitHub Actions and PowerShell

A typical **GitHub Actions** workflow might have steps like:

```yaml
name: Build LabVIEW Icon Editor
on:
  push:
    branches: [ "main" ]

jobs:
  build:
    runs-on: windows-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@v3

      - name: Setup PowerShell
        uses: actions/setup-powershell@v2

      - name: Run PowerShell Build
        run: |
          pwsh .\Build.ps1 `
            -RelativePath "$env:GITHUB_WORKSPACE" `
            -AbsolutePathScripts "$env:GITHUB_WORKSPACE\pipeline\scripts" `
            -Major 1 -Minor 0 -Patch 0 -Build 42 `
            -Commit "${{ github.sha }}" `
            -CompanyName "${{ github.repository_owner }}" `
            -AuthorName "${{ github.repository }}" `
            -Verbose
```

**Key points**:
- **`${{ github.repository_owner }}`** is the **organization** (or user) that owns the repo.
- **`${{ github.repository }}`** is the “orgName/repoName” string (e.g. `AcmeCorp/lv-icon-editor`).
- These parameters feed into the final **JSON** that `build_vip.ps1` uses to update the VI Package.

---

## Overall CI/CD Flow

1. **Developer** pushes code to GitHub.  
2. **GitHub Actions** triggers the workflow.  
3. **Actions** checks out the repo and runs `Build.ps1`:
   1. Cleans old artifacts.  
   2. Applies VIPC (32-bit and 64-bit).  
   3. Builds the 32-bit and 64-bit libraries.  
   4. Constructs JSON containing `CompanyName` and `AuthorName` fields, derived from GitHub Action variables.  
   5. Passes that JSON to `build_vip.ps1`.  
   6. `build_vip.ps1` injects these fields and version info into the `.vipb` file.  
   7. Generates the **Icon Editor** `.vip` package.  
4. **Actions** can then publish or attach the final `.vip` as an artifact.

---

## Example Usage

### Local Command-Line

You can also run this locally. For example, if you wanted to embed some custom organization and repo data manually:

```powershell
.\Build.ps1 `
  -RelativePath "C:\labview-icon-editor-fork" `
  -AbsolutePathScripts "C:\labview-icon-editor-fork\pipeline\scripts" `
  -Major 2 -Minor 1 -Patch 0 -Build 5 `
  -Commit "abc12345" `
  -CompanyName "Acme Corporation" `
  -AuthorName "acme-corp/lv-icon-editor" `
  -Verbose
```

This produces a `.vip` file that, when inspected in VIPM or LabVIEW, shows **“Acme Corporation”** as the company and **“acme-corp/lv-icon-editor”** in the author field.

---

## Conclusion

**Injecting Repo and Organization** fields in the Icon Editor’s VI Package ensures:
- Each fork or organization can **uniquely** brand its builds.
- CI/CD with **GitHub Actions** automatically **populates** build metadata, removing manual steps.  
- You have a **clear**, **traceable** record of each build’s origin—particularly useful in multi-team or open-source projects.
