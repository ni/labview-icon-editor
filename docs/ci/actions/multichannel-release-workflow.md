# **Updated Guide: Multi-Channel Release Workflow**

This revised guide focuses on the **release workflow**, specifically how we handle **multiple pre-release channels** (Alpha, Beta, RC) in addition to final versions.


## **Table of Contents**

1. [Overview & Purpose](#overview--purpose)  
2. [Requirements & Environment](#requirements--environment)  
3. [Configuration & Branch Patterns](#configuration--branch-patterns)  
4. [Workflow Steps](#workflow-steps)  
   - [Disable GPG on Forks](#disable-gpg-on-forks)  
   - [Fetch & Determine Version](#fetch--determine-version)  
   - [Build & Artifact Handling](#build--artifact-handling)  
   - [Tag & Release Creation](#tag--release-creation)  
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

This **Multi-Channel Release Workflow** automates the packaging and releasing of LabVIEW `.vip` files. It:

- Uses **label-based** semantic version increments for major/minor/patch.
- Maintains a **commit-based build number**, so every new commit yields a unique suffix (`-buildNN`).
- Extends pre-release logic to **Alpha**, **Beta**, and **RC** channels, not just a single `release/*` for RC.
- Optionally **disables GPG** signing if the repository is a fork.

By adopting these patterns, maintainers can run alpha, beta, and RC pipelines in parallel or sequentially, each channel generating distinct pre-release versions.


<a name="requirements--environment"></a>
## **2. Requirements & Environment**

1. **Windows Self-Hosted Runner**  
   - LabVIEW installed to build `.vip` files.  
   - PowerShell 7+ recommended.

2. **Repository Permissions**  
   - The GitHub Actions token (`GITHUB_TOKEN`) needs `contents: write` to push tags & create releases.  
   - If you have branch protection on tags, allow actions to create them.

3. **Labels**  
   - Pull requests must use `major`, `minor`, or `patch` to increment those fields. If no label, only the build number increments.

4. **Fork Considerations**  
   - If `DISABLE_GPG_ON_FORKS == true`, the workflow sets `commit.gpgsign` and `tag.gpgsign` to `false` for forks (i.e., if the `github.repository` is not your official name).


<a name="configuration--branch-patterns"></a>
## **3. Configuration & Branch Patterns**

1. **Alpha**  
   - Branch pattern: `release-alpha/*`.  
   - Produces versions like `vX.Y.Z-alpha.<N>-build<commitCount>`.  
2. **Beta**  
   - Branch pattern: `release-beta/*`.  
   - Produces `vX.Y.Z-beta.<N>-build<commitCount>`.  
3. **RC**  
   - Branch pattern: `release-rc/*`.  
   - Produces `vX.Y.Z-rc.<N>-build<commitCount>`.  
4. **Other Branches**  
   - `main`, `develop`, `hotfix/*` produce final releases with no alpha/beta/rc suffix.  
   - No label => major/minor/patch remain unchanged; build increments only.

Use whichever patterns best fit your project’s branching model. If you prefer subdirectories (`release/alpha/*` vs. `release-alpha/*`), adapt the snippet accordingly.


<a name="workflow-steps"></a>
## **4. Workflow Steps**

Below is a **high-level** breakdown. In your `.github/workflows/build-vi-package.yml`, these steps typically appear in order:

<a name="disable-gpg-on-forks"></a>
### **Disable GPG on Forks**
- If `DISABLE_GPG_ON_FORKS == true` and the repo name doesn’t match your official repository, sets:
  ```powershell
  git config --global commit.gpgsign false
  git config --global tag.gpgsign false
  ```
- Captures the old values to restore them later.

<a name="fetch--determine-version"></a>
### **Fetch & Determine Version**
1. **Check out** the repo with `fetch-depth: 0` to have full commit history.  
2. **Determine bump type** by reading PR labels (`major`, `minor`, `patch`, or `none`).  
3. **Build number** = total commits (`git rev-list --count HEAD`).  
4. **Compute final version**:  
   - Parse the last stable tag (or default to `v0.0.0`).  
   - Apply major/minor/patch if needed.  
   - If branch matches `release-alpha/*`, `release-beta/*`, or `release-rc/*`, append `-alpha.<N>`, `-beta.<N>`, or `-rc.<N>`.  
   - Finally append `-build<commitCount>`.

<a name="build--artifact-handling"></a>
### **Build & Artifact Handling**
- Calls a `Build.ps1` script that compiles LabVIEW code and outputs `.vip` to `builds/VI Package/*.vip`.
- Uploads the `.vip` as an ephemeral artifact with `actions/upload-artifact@v4`.

<a name="tag--release-creation"></a>
### **Tag & Release Creation**
- If event is *not* `pull_request`, we:
  1. Create an annotated tag → `vX.Y.Z-etc.`
  2. Push the tag to origin.
  3. Create a GitHub release. If the version is alpha/beta/rc, set `prerelease: true`.  
  4. If `ATTACH_ARTIFACTS_TO_RELEASE == true`, attach the `.vip` to the release using `Invoke-RestMethod`.


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
3. Final version: `v<major>.<minor>.<patch>-<preSuffix>-build<commitCount>`.

<a name="final-release-flow"></a>
### **5.3 Final Release Flow**
- If branch doesn’t match alpha/beta/rc patterns, `$preSuffix` is empty.  
- `isPrerelease = false`, resulting in a stable release, e.g. `v1.3.4-build50`.


<a name="usage-examples"></a>
## **6. Usage Examples**

1. **Alpha Channel Testing**  
   - You want an early test for version 2.0: create `release-alpha/2.0`.  
   - Each commit produces something like `v2.0.0-alpha.2-build41`.  
   - Merging alpha → beta or main finalizes or transitions the channel.

2. **Beta Channel**  
   - `release-beta/2.0`. Now each commit yields `v2.0.0-beta.3-build45`.  
   - Merging back to `main` yields a stable `v2.0.0-build46`.

3. **RC Branch**  
   - `release-rc/2.1`. The workflow sets `-rc.<N>` so your testers see it’s near final.  
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
   - The label-based bump is orthogonal to alpha/beta/rc. If no label is set, major/minor/patch remain the same, but you might still produce `-alpha.<N>-buildXX`.


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

By supporting **multiple pre-release channels** (Alpha, Beta, RC), this updated release workflow offers greater flexibility for iterative testing stages. Each branch pattern yields a distinct suffix (`-alpha.<N>`, `-beta.<N>`, or `-rc.<N>`). Merging into a final branch (e.g., `main`) produces a stable release with no suffix, but still uses **commit-based** build numbering. Combined with label-based major/minor/patch increments, you have a **robust**, **fork-friendly**, and **multi-stage** CI/CD pipeline for LabVIEW. 
