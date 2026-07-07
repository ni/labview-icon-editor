# **Updated Guide: Multi-Channel Release Workflow**

This revised guide focuses on the **release workflow**, specifically how we handle **multiple pre-release channels** (Alpha, Beta, RC) in addition to final versions.


## **Table of Contents**

1. [Overview & Purpose](#overview--purpose)  
2. [Requirements & Environment](#requirements--environment)
3. [Configuration & Branch Patterns](#configuration--branch-patterns)
   - [Issue-Status Gate](#issue-status-gate)
4. [Workflow Steps](#workflow-steps)
   - [Fetch & Determine Version](#fetch--determine-version)
   - [Build & Artifact Handling](#build--artifact-handling)
   - [Artifact Upload Only](#artifact-upload-only)
5. [Multiple Pre-Release Channels Explained](#multiple-pre-release-channels-explained)  
   - [Branch Name Conventions](#branch-name-conventions)  
   - [Alpha / Beta / RC Logic](#alpha--beta--rc-logic)  
   - [Final Release Flow](#final-release-flow)  
6. [Usage Examples](#usage-examples)  
7. [Troubleshooting & Tips](#troubleshooting--tips)  
8. [FAQ](#faq)  
9. [Conclusion](#conclusion)


<a name="overview--purpose"></a>
## **1. Overview & Purpose**

This **Multi-Channel Release Workflow** automates packaging LabVIEW `.vip` files for multiple pre-release channels. It uploads artifacts but does not create Git tags or GitHub releases. It:

- Uses **label-based** semantic version increments for major/minor/patch.
- Maintains a **commit-based build number**, so every new commit yields a unique suffix (`-buildNN`).
- Extends pre-release logic to **Alpha**, **Beta**, and **RC** channels, not just a single `release/*` for RC. The pre-release number uses the same commit count as the build number, so both values are identical.

By adopting these patterns, maintainers can run alpha, beta, and RC pipelines in parallel or sequentially, each channel generating distinct pre-release versions.


<a name="requirements--environment"></a>
## **2. Requirements & Environment**

1. **Windows Self-Hosted Runner**  
   - LabVIEW installed to build `.vip` files.  
   - PowerShell 7+ recommended.

2. **Repository Permissions**
   - The GitHub Actions token (`GITHUB_TOKEN`) needs `contents: read` to upload artifacts.
   - Creating tags or GitHub releases would require additional permissions and a separate workflow.

3. **Labels**
  - Pull requests may include at most one of `major`, `minor`, or `patch` to increment those fields. If none is provided, the workflow defaults to a patch bump. Multiple release labels cause the workflow to fail. See [`compute-version`](../../../.github/actions/compute-version/action.yml) for the label-handling logic.


<a name="configuration--branch-patterns"></a>
## **3. Configuration & Branch Patterns**

1. **Alpha**
   - Branch pattern: `release-alpha/*`.
   - Produces versions like `vX.Y.Z-alpha.<commitCount>-build<commitCount>`.
2. **Beta**
   - Branch pattern: `release-beta/*`.
   - Produces `vX.Y.Z-beta.<commitCount>-build<commitCount>`.
3. **RC**
  - Branch pattern: `release-rc/*`.
  - Produces `vX.Y.Z-rc.<commitCount>-build<commitCount>`.
4. **Other Branches**
  - `main`, `develop`, `hotfix/*` produce final releases with no alpha/beta/rc suffix.
  - No label => major/minor/patch remain unchanged; build increments only.

The accompanying GitHub Actions workflow (`ci-composite.yml`) lists `release-alpha/*`, `release-beta/*`, and `release-rc/*` in its trigger patterns so commits or pull requests to these branches automatically run this pipeline.

To enable these pre-release branches, ensure the workflow's `on.push.branches` and `on.pull_request.branches` sections include the patterns:

```yaml
on:
  push:
    branches:
      - main
      - develop
      - release-alpha/*
      - release-beta/*
      - release-rc/*
      - feature/*
      - hotfix/*
      - issue-*
  pull_request:
    branches:
      - main
      - develop
      - release-alpha/*
      - release-beta/*
      - release-rc/*
      - feature/*
      - hotfix/*
      - issue-*
```

Use whichever patterns best fit your project’s branching model. If you prefer subdirectories (`release/alpha/*` vs. `release-alpha/*`), adapt the snippet accordingly.


<a name="issue-status-gate"></a>
### **Issue-Status Gate**

The composite CI workflow only runs full jobs when the `issue-status` check succeeds. That job requires the source branch name to contain `issue-<number>` (for example, `release-alpha/issue-123` or `issue-456`) and the linked GitHub issue’s Status to be **In Progress**. Branches without this prefix—such as `release-alpha/2.0`—trigger the workflow but skip all subsequent jobs. See the `issue-status` job in [ci-composite.yml](../../../.github/workflows/ci-composite.yml) for details and its downstream gate.


<a name="workflow-steps"></a>
## **4. Workflow Steps**

Below is a **high-level** breakdown. In your `.github/workflows/ci-composite.yml`, these steps typically appear in order:

<a name="fetch--determine-version"></a>
### **Fetch & Determine Version**
1. **Check out** the repo with `fetch-depth: 0` to have full commit history.  
2. **Determine bump type** by reading PR labels (`major`, `minor`, `patch`, or `none`).  
3. **Build number** = total commits (`git rev-list --count HEAD`).  
4. **Compute final version**:  
   - Parse the last stable tag (or default to `v0.0.0`).  
   - Apply major/minor/patch if needed.  
   - If branch matches `release-alpha/*`, `release-beta/*`, or `release-rc/*`, append `-alpha.<commitCount>`, `-beta.<commitCount>`, or `-rc.<commitCount>`. The `<N>` value equals the commit count.
   - Finally append `-build<commitCount>`. Because both suffixes use the commit count, the pre-release number and build number are identical.

<a name="build--artifact-handling"></a>
### **Build & Artifact Handling**
- Uses the `build-lvlibp` and `build-vi-package` actions to compile code and produce the `.vip` package.

<a name="artifact-upload-only"></a>
### **Artifact Upload Only**
- Uploads the `.vip` as an ephemeral artifact with `actions/upload-artifact@v4`.
- The workflow does not create tags or GitHub releases; use a separate workflow if publishing is required.


<a name="multiple-pre-release-channels-explained"></a>
## **5. Multiple Pre-Release Channels Explained**

<a name="branch-name-conventions"></a>
### **5.1 Branch Name Conventions**
- **Alpha**: `release-alpha/1.0`, `release-alpha/mynewfeature`, etc.  
- **Beta**: `release-beta/2.0`, `release-beta/test`, etc.  
- **RC**: `release-rc/2.1`, `release-rc/final-stability`.

Any commit to these branches triggers an alpha/beta/rc suffix. Merging to `main` finalizes the version (suffix removed).

<a name="alpha--beta--rc-logic"></a>
### **5.2 Alpha / Beta / RC Logic**
1. We parse branch name for patterns like:
   ```powershell
   if ($branchName -like 'release-alpha/*') {
     $preSuffix = "alpha.$commitsCount"
   }
   elseif ($branchName -like 'release-beta/*') {
     $preSuffix = "beta.$commitsCount"
   }
   elseif ($branchName -like 'release-rc/*') {
     $preSuffix = "rc.$commitsCount"
   }
   else {
     $preSuffix = ""
   }
   ```
2. If `$preSuffix` is non-empty, `isPrerelease = true`.
3. Final version: `v<major>.<minor>.<patch>-<preSuffix>-build<commitCount>`. Since `<preSuffix>` incorporates `$commitsCount`, the pre-release number and build number are the same.

<a name="final-release-flow"></a>
### **5.3 Final Release Flow**
- If branch doesn’t match alpha/beta/rc patterns, `$preSuffix` is empty.  
- `isPrerelease = false`, resulting in a stable release, e.g. `v1.3.4-build50`.


<a name="usage-examples"></a>
## **6. Usage Examples**

1. **Alpha Channel Testing**
   - You want an early test for version 2.0: create `release-alpha/2.0`.
   - Each commit produces something like `v2.0.0-alpha.41-build41`.
   - Merging alpha → beta or main finalizes or transitions the channel.

2. **Beta Channel**
   - `release-beta/2.0`. Now each commit yields `v2.0.0-beta.45-build45`.
   - Merging back to `main` yields a stable `v2.0.0-build46`.

3. **RC Branch**
   - `release-rc/2.1`. The workflow sets `-rc.<commitCount>` so your testers see it’s near final, e.g. `v2.1.0-rc.50-build50`.
   - Merging to main ends the RC, resulting in `v2.1.0-buildXX`.

4. **No Pre-Release**  
   - If on `develop` or `main` directly, no suffix is appended, e.g. `v1.2.3-build22`.


<a name="troubleshooting--tips"></a>
## **7. Troubleshooting & Tips**

1. **Branch Name Misspellings**  
   - If you name `release-apha/*` (typo in “alpha”), the script won’t detect alpha. Ensure consistent naming.

2. **Overlapping Patterns**  
   - If your branch name inadvertently matches more than one pattern, the first `if` wins. Keep patterns distinct.

3. **Auto Notes**  
   - If `USE_AUTO_NOTES == true`, you get auto-generated release notes for alpha/beta/rc. Manually finalize them if you prefer.

4. **Final Merge**  
   - Typically, you merge alpha → beta → rc → main in sequence, each step dropping the old suffix for the new. If you do “hotfix” merges or skip channels, ensure you keep version consistency.

5. **Same Bump Type**
   - The label-based bump is orthogonal to alpha/beta/rc. If multiple release labels are applied, the workflow fails; with none, it defaults to a patch bump.


<a name="faq"></a>
## **8. FAQ**

**Q1**: *Can I have alpha, beta, rc all in one folder, like `release/alpha/*`, `release/beta/*`?*  
**A1**: Yes, just adapt the pattern checks, e.g. `$branchName -like 'release/alpha/*'`, `$branchName -like 'release/beta/*'`, etc.

**Q2**: *What if I want numeric channel IDs, e.g. `-alpha2` instead of `-alpha.2`?*  
**A2**: You can build `$preSuffix = "alpha$commitsCount"`—just remove the dot.

**Q3**: *Does GitHub auto-flag alpha or beta suffix releases as pre-release?*  
**A3**: Not automatically. We set `prerelease: true` if `$preSuffix` is non-empty. This ensures the release is marked pre-release in GitHub’s UI.

**Q4**: *How do I integrate these channels with tagging older versions or skipping certain channels?*  
**A4**: You can skip alpha or beta if you like, or go from `develop` → `release-alpha/*` → `release-rc/*` → `main`. The workflow logic is flexible.


<a name="conclusion"></a>
## **9. Conclusion**

By supporting **multiple pre-release channels** (Alpha, Beta, RC), this updated release workflow offers greater flexibility for iterative testing stages. Each branch pattern yields a distinct suffix (`-alpha.<commitCount>`, `-beta.<commitCount>`, or `-rc.<commitCount>`). Merging into a final branch (e.g., `main`) produces a stable release with no suffix, but still uses **commit-based** build numbering—so the pre-release number and build number are always identical. Combined with label-based major/minor/patch increments, you have a **robust**, **fork-friendly**, and **multi-stage** CI/CD pipeline for LabVIEW.
