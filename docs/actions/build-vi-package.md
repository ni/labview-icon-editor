# **Documentation: Build VI Package & Release Workflow (Fork-Friendly)**

This document describes a **complete guide** to setting up and using the “Build VI Package” GitHub Actions workflow in your repository—whether it's the original (`ni/labview-icon-editor`) or a **fork**. It explains each part of the workflow, including **how to configure it**, **why certain design choices were made**, and **what steps** you must follow to replicate this functionality on your own fork.

---

## **Table of Contents**

1. [Overview](#overview)  
2. [Why Use This Workflow?](#why-use-this-workflow)  
3. [Core Features](#core-features)  
   - [1. Automatic Versioning](#1-automatic-versioning)  
   - [2. GPG Signing Toggle](#2-gpg-signing-toggle)  
   - [3. Artifact Build & Release](#3-artifact-build--release)  
   - [4. Custom Branding Via Metadata](#4-custom-branding-via-metadata)  
4. [Setting Up in Your Fork](#setting-up-in-your-fork)  
   - [1. Copy the Workflow File](#1-copy-the-workflow-file)  
   - [2. Update the Repository Check](#2-update-the-repository-check)  
   - [3. Ensure Runner & Permissions](#3-ensure-runner--permissions)  
5. [Workflow Behavior](#workflow-behavior)  
   - [Events That Trigger It](#events-that-trigger-it)  
   - [Label-Based Semver Bumps](#label-based-semver-bumps)  
   - [Release Candidate Logic](#release-candidate-logic)  
6. [Usage Examples](#usage-examples)  
   - [Pull Requests with Labels](#pull-requests-with-labels)  
   - [Direct Push to Main or Develop](#direct-push-to-main-or-develop)  
   - [Working on a Release Branch](#working-on-a-release-branch)  
7. [Detailed Step Explanations](#detailed-step-explanations)  
   - [Disable GPG Signing (if Fork)](#disable-gpg-signing-if-fork)  
   - [Compute Version](#compute-version)  
   - [Create Tag & Push](#create-tag--push)  
   - [Build the Icon Editor VI Package](#build-the-icon-editor-vi-package)  
   - [Upload Artifact](#upload-artifact)  
   - [Create GitHub Release](#create-github-release)  
   - [Re-Enable GPG Signing](#re-enable-gpg-signing)  
8. [Testing & Verification](#testing--verification)  
   - [Fork Testing](#fork-testing)  
   - [Main Repo Testing](#main-repo-testing)  
   - [Pull Request Testing](#pull-request-testing)  
9. [Troubleshooting](#troubleshooting)  
10. [FAQ](#faq)  
11. [Conclusion](#conclusion)

---

## **1. Overview**

**Purpose**: This workflow provides a **consistent, automated release process** for LabVIEW Icon Editor packages, including:

- Automatic **Semantic Version** bumping (major/minor/patch).
- **Build** and **packaging** of the `.vip` artifact.
- **Tag creation** in Git with a `vX.Y.Z-buildN` format.
- **GitHub Release** creation, optionally as a pre-release if using a `release/*` branch.
- **Flexible metadata branding** of the final package (repo name, organization, etc.).

For **forks**, the workflow automatically **disables** GPG signing to avoid passphrase prompts.

---

## **2. Why Use This Workflow?**

1. **Standardizes versioning**: Eliminates confusion about version increments; labels guide the semver bump.  
2. **Fork-friendly**: Fork owners won’t be blocked by GPG passphrase issues.  
3. **Reduces manual overhead**: No more ad-hoc tagging, manual artifact uploads, or drafting releases.  
4. **Encourages best practices**: Integrates cleanly with GitHub’s PR and branching model.  
5. **Unique package branding**: Inject repository/organization names to differentiate builds (especially valuable in multi-team or open-source contexts).

---

## **3. Core Features**

### **1. Automatic Versioning**
- Pull request labels (`major`, `minor`, `patch`) decide how much to increment the version.
- Defaults to a `patch` bump if there’s no label or on direct pushes.

### **2. GPG Signing Toggle**
- If the repository name **is** `ni/labview-icon-editor`, signing stays enabled.
- If **not**, the workflow disables signing, preventing passphrase prompts that occur when no keys are available on the fork’s runner.
- Restores any prior Git config after the build completes.

### **3. Artifact Build & Release**
- Runs a PowerShell script (`Build.ps1`) to compile a `.vip` file.
- Uploads the `.vip` to GitHub as a build artifact.
- **Creates a release** in GitHub if it’s not a pull request, attaching the `.vip`.

### **4. Custom Branding Via Metadata**
- You can **pass metadata fields** (e.g., your **organization** or **repo name**) into the build script.  
- This branding data is injected into the final `.vip` package to uniquely identify **who** built it and **where** it originated.  
- Especially helpful if multiple forks or organizations produce their own builds and need a clear way to distinguish them.

---

## **4. Setting Up in Your Fork**

### **1. Copy the Workflow File**
- In your fork, create a new file:  
  `.github/workflows/build-vi-package.yml`
- Copy the entire workflow YAML from the main repo or from a PR that merges these changes.  
- Commit it to your fork’s branch (e.g., `develop`).

### **2. Update the Repository Check**
- Locate lines like:  
  ```yaml
  if: ${{ github.repository != 'ni/labview-icon-editor' }}
  ```
- If the original repo name is different (e.g., `myorg/lv-icon-editor`), adjust it accordingly.  
- This ensures the workflow **knows** when it’s on a fork vs. the original repo.

### **3. Ensure Runner & Permissions**
- **Self-Hosted Runner**:  
  - The file references `runs-on: [self-hosted, iconeditor]`. Verify that your runner has both labels.  
  - If not, change `runs-on` to match your runner’s labels.
- **Write Permissions**:  
  - In your fork’s **Settings** → **Actions** → **General**, check **Workflow Permissions** = “Read and Write.”  
  - This allows the GITHUB_TOKEN to push tags and create releases.

---

## **5. Workflow Behavior**

### **Events That Trigger It**
- `push` to `main`, `develop`, `release/*`, or `hotfix/*`.
- `pull_request` targeting those branches.
- `workflow_dispatch` (manual run) if enabled.

### **Label-Based Semver Bumps**
- On a pull request, the workflow inspects labels:
  - `major` → X+1.0.0  
  - `minor` → X.Y+1.0  
  - `patch` → X.Y.Z+1  
- If no label, it defaults to a patch bump.

### **Release Candidate Logic**
- For branches named `release/*`, the version gets an `-rc.N` suffix (e.g., `v1.2.0-rc.3-build10`).  
- The resulting GitHub release is marked as a **pre-release**.  
- Merging from `release/*` into `main` can finalize the version.

---

## **6. Usage Examples**

### **Pull Requests with Labels**
- Suppose you create a PR from `feature/my-new-feature` to `develop`.
- Assign the `minor` label to indicate a minor bump.
- Upon merging (or push), the version might go from `v1.2.3` to `v1.3.0` plus a build number.

### **Direct Push to Main or Develop**
- If you push directly (e.g., an urgent hotfix), the workflow defaults to patch bump if no label is set.
- It automatically tags and releases the new version: `v1.3.1-build42`, for example.

### **Working on a Release Branch**
- Branch name: `release/2.0`.
- The workflow appends `-rc.N` to the semver (`v2.0.0-rc.2-build17`) before finalizing.

---

## **7. Detailed Step Explanations**

### **Disable GPG Signing (if Fork)**
- **When**: Immediately at the start of the job if `github.repository != 'ni/labview-icon-editor'`.  
- **What**:  
    - Reads existing Git config for signing.  
    - Temporarily sets `commit.gpgsign` and `tag.gpgsign` to `false`.  
- **Why**: Avoid passphrase prompts or errors if the user doesn’t have the GPG keys.

### **Compute Version**
- Checks for labels or direct push to decide the bump type.  
- Scans existing tags matching `v*.*.*-build*` to determine the next build number.

### **Create Tag & Push**
- Only runs on non-PR events (e.g., push to `develop`).  
- Uses `git tag -a vX.Y.Z-buildN` and pushes it to `origin`.

### **Build the Icon Editor VI Package**
- Invokes `Build.ps1` to compile `.vip` output inside `builds/VI Package/`.  
- **Important**: You can pass your **GitHub repository** or **organization** as parameters (e.g., `-CompanyName`, `-AuthorName`) so the final `.vip` is **branded** with your fork’s identity.  
  - For example:
    ```yaml
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
- This way, the `.vip` package’s display fields clearly **indicate** who built it and from which repo.

### **Upload Artifact**
- Uses `actions/upload-artifact@v4` to store `.vip` in GitHub’s artifact section.
- You can download this artifact from the workflow summary page.

### **Create GitHub Release**
- Also only on non-PR events.  
- Publishes a release with the newly created tag; if `-rc` suffix is present, marks it as pre-release.

### **Re-Enable GPG Signing**
- If it was disabled, the workflow reads the original signing config and restores it, ensuring local dev settings remain unchanged.

---

## **8. Testing & Verification**

### **Fork Testing**
1. **Fork** the repo.  
2. **Push** to your fork’s `develop` branch.  
3. Confirm the new tag appears in your fork’s tags (like `v0.0.1-build1`), and GPG signing is not prompted.  
4. Check the run logs for any errors.  
5. **Inspect** the final `.vip` file in VIPM to see that “Company Name” or “Author Name (Person or Company)” has **your** repo/fork branding.

### **Main Repo Testing**
1. **Push** or **merge** a change in `ni/labview-icon-editor`.  
2. The job will detect it’s the original repo, keep signing enabled, and produce a signed tag.  
3. Verify the `.vip` artifact is uploaded and that a release is created.
4. Inspect the package metadata for `ni/labview-icon-editor` branding or other relevant fields.

### **Pull Request Testing**
- **Open** a PR from a feature branch to `develop`.  
- Assign `major`, `minor`, or `patch` label.  
- Observe that the workflow checks the label but does **not** create a tag or release until merged.  
- On merge, the final tag is pushed.

---

## **9. Troubleshooting**

- **“No runner matching labels”**: Update `runs-on` or set your self-hosted runner labels.  
- **“Permission denied when pushing tag”**: Go to Settings → Actions → General and set “Workflow permissions” to “Read and write.”  
- **Build script not found**: Make sure your repo has `pipeline/scripts/Build.ps1` in the correct path or update the workflow steps accordingly.  
- **Signing errors in the original repo**: Ensure the runner has the correct GPG keys and passphrase configured, or remove signing if you don’t need it.  
- **Branded fields not showing**: Double-check your parameters in the `Build.ps1` call (e.g., `-CompanyName`, `-AuthorName`) or ensure the script itself updates JSON properly.

---

## **10. FAQ**

**Q1**: *Can I rename the workflow file?*  
**A1**: Yes. Just keep it in `.github/workflows/`. The name inside `name:` in the YAML doesn’t affect functionality.

**Q2**: *Do I need the same runner labels (`iconeditor`)?*  
**A2**: Not necessarily. You can adjust `runs-on` to any environment that has LabVIEW/PowerShell 7 installed, or uses GitHub-hosted runners with minimal changes.

**Q3**: *What if I want to skip GPG signing in the main repo, too?*  
**A3**: Remove or comment out the logic checking `github.repository` and disable signing altogether.

**Q4**: *What if I want to force GPG signing on forks?*  
**A4**: You must provide them with the keys or passphrase. Generally not recommended for open-source forks.

**Q5**: *Why do I need to pass `-CompanyName` or `-AuthorName`?*  
**A5**: This ensures your `.vip` file is **branded** with your organization or repository. Helpful if you want to differentiate your fork’s output from the original.

---

## **11. Conclusion**

By setting up the **Build VI Package** workflow in your repository (or fork), you gain:

- **Automated versioning** with semantic increments.  
- A **straightforward** path to building and releasing `.vip` artifacts.  
- A **fork-friendly** process that avoids GPG key complexities.  
- **Optional branding** of the final package using your repository/organization metadata—making each build clearly identifiable.

Simply follow the **setup steps** and **usage examples** above to enable consistent, robust releases for your Icon Editor project. **Happy building!**
