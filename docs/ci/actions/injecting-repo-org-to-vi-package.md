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
1. **Generating** a JSON object with fields like `"Company Name"` and `"Author Name (Person or Company)"` directly in the workflow using GitHub-provided variables (e.g., `${{ github.repository_owner }}` and `${{ github.event.repository.name }}`).
2. **Using** the `modify-vipb-display-info` action to merge this JSON into the `.vipb` (VI Package Builder) file.
3. **Building** the package with the `build-lvlibp` and `build-vip` actions from the composite CI workflow.

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

An abbreviated **GitHub Actions** example below mirrors the [`ci.yml`](../../../.github/workflows/ci.yml) workflow. A **`version`** job first computes the semantic version and outputs `MAJOR`, `MINOR`, `PATCH`, and `BUILD` for downstream steps. The **`build-ppl`** job uses a matrix to compile both 32- and 64-bit packed libraries, and the **`build-vip`** job injects the display metadata and creates the final `.vip` file. Referring to the jobs by name—rather than line numbers—helps avoid future drift. The snippet highlights key steps such as `compute-version`, `build-lvlibp`, `modify-vipb-display-info`, and `build-vip`:

```yaml
jobs:
  version:
    runs-on: self-hosted-windows-lv
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - id: compute-version
        uses: ./.github/actions/compute-version
    outputs:
      MAJOR: ${{ steps.compute-version.outputs.MAJOR }}
      MINOR: ${{ steps.compute-version.outputs.MINOR }}
      PATCH: ${{ steps.compute-version.outputs.PATCH }}
      BUILD: ${{ steps.compute-version.outputs.BUILD }}
  build-ppl:
    runs-on: self-hosted-windows-lv
    needs: version
    strategy:
      matrix:
        bitness: [32, 64]
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/build-lvlibp
        with:
          supported_bitness: ${{ matrix.bitness }}
          repository_path: ${{ github.workspace }}
          major: ${{ needs.version.outputs.MAJOR }}
          minor: ${{ needs.version.outputs.MINOR }}
          patch: ${{ needs.version.outputs.PATCH }}
          build: ${{ needs.version.outputs.BUILD }}
          commit: ${{ github.sha }}

  build-vip:
    runs-on: self-hosted-windows-lv
    needs: [build-ppl, version]
    steps:
      - uses: actions/checkout@v4
      - name: Generate display information JSON
        id: display-info
        shell: pwsh
        run: |
          $info = @{
            "Company Name" = "${{ github.repository_owner }}"
            "Author Name (Person or Company)" = "${{ github.event.repository.name }}"
          }
          "json=$($info | ConvertTo-Json -Depth 5 -Compress)" >> $Env:GITHUB_OUTPUT
      - uses: ./.github/actions/modify-vipb-display-info
        with:
          vipb_path: .github/actions/build-vip/NI Icon editor.vipb
          labview_minor_revision: 3
          repository_path: ${{ github.workspace }}
          supported_bitness: 64
          major: ${{ needs.version.outputs.MAJOR }}
          minor: ${{ needs.version.outputs.MINOR }}
          patch: ${{ needs.version.outputs.PATCH }}
          build: ${{ needs.version.outputs.BUILD }}
          commit: ${{ github.sha }}
          release_notes_file: ${{ github.workspace }}/Tooling/deployment/release_notes.md
          display_information_json: ${{ steps.display-info.outputs.json }}
      - uses: ./.github/actions/build-vip
        with:
          labview_minor_revision: 3
          repository_path: ${{ github.workspace }}
          vipb_path: .github/actions/build-vip/NI Icon editor.vipb
          supported_bitness: 64
          major: ${{ needs.version.outputs.MAJOR }}
          minor: ${{ needs.version.outputs.MINOR }}
          patch: ${{ needs.version.outputs.PATCH }}
          build: ${{ needs.version.outputs.BUILD }}
          commit: ${{ github.sha }}
          release_notes_file: ${{ github.workspace }}/Tooling/deployment/release_notes.md
          display_information_json: ${{ steps.display-info.outputs.json }}
```

> **Note:** `build-vip` runs outside the bitness matrix because the Icon Editor ships only a 64-bit VI Package; packaging the 32-bit output would duplicate artifacts. The LabVIEW major version is resolved automatically from the repo’s VIPB via `scripts/get-package-lv-version.ps1`, so no version override is needed.

**Key points**:
- **`${{ github.repository_owner }}`** is the **organization** (or user) that owns the repo.
- **`${{ github.event.repository.name }}`** is the repository name.
- The generated JSON now includes:
  - the semantic version components, company, product, and author names;
  - the repository URL (with a fallback to `https://github.com/<owner>/<repo>`);
  - descriptive text derived from the repository description when it exists, or a generated default when it does not;
  - the contents of the workflow-generated `Tooling/deployment/release_notes.md` file as the **Release Notes - Change Log** field.
- `modify-vipb-display-info` and `build-vip` consume this JSON to embed the metadata directly in the `.vip`.

---

## Overall CI/CD Flow

1. **Developer** pushes code to GitHub.  
2. **GitHub Actions** triggers the workflow.  
3. **Actions** check out the repo and run the build actions:
   1. `compute-version` determines the semantic version.
   2. `build-lvlibp` compiles the **32- and 64-bit** packed libraries.
   3. A PowerShell step generates JSON with `CompanyName` and `AuthorName` fields derived from GitHub variables.
   4. `modify-vipb-display-info` merges that JSON into the `.vipb` file.
   5. `build-vip` produces the final **64-bit LabVIEW 2023** Icon Editor `.vip` package.
4. **Actions** can then upload the resulting `.vip` as an artifact.

---

## Example Usage

### Legacy Local Command-Line

The previous build system used a `Build.ps1` script. For historical reference, you can still run it locally:

```powershell
\.github\actions\build\Build.ps1 `
  -RepositoryPath "C:\labview-icon-editor-fork" `
  -Major 2 -Minor 1 -Patch 0 -Build 5 `
  -Commit "abc12345" `
  -CompanyName "Acme Corporation" `
  -AuthorName "acme-corp/lv-icon-editor" `
  -Verbose
```

This legacy script produces a `.vip` file that, when inspected in VIPM or LabVIEW, shows **“Acme Corporation”** as the company and **“acme-corp/lv-icon-editor”** in the author field.

---

## Conclusion

**Injecting Repo and Organization** fields in the Icon Editor’s VI Package ensures:
- Each fork or organization can **uniquely** brand its builds.
- CI/CD with **GitHub Actions** automatically **populates** build metadata, removing manual steps.  
- You have a **clear**, **traceable** record of each build’s origin—particularly useful in multi-team or open-source projects.
