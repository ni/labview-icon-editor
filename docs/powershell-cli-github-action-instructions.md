# CI Workflow (Multi-Channel Release Support)

This guide explains how to automate build, test, and distribution steps for the **LabVIEW Icon Editor** using GitHub Actions—**with multiple pre-release channels** (Alpha, Beta, RC), optional hotfix branches, and a toggleable **Development Mode** feature. It is designed to align with **Gitflow** practices, allowing you to enforce a hands-off approach where merges flow naturally from `develop` → `release-alpha` → `release-beta` → `release-rc` → `main`, while also ensuring forks can reuse the same build scripts.

> **Note**: For **troubleshooting** and a more extensive **FAQ**, see the [TROUBLESHOOTING FAQ](ci/troubleshooting-faq.md). For more detailed runner setup instructions, see the [runner setup guide](ci/actions/runner-setup-guide.md)

---

## Table of Contents

1. [Introduction](#1-introduction)  
2. [Quickstart / Step-by-Step Procedure](#2-quickstart--step-by-step-procedure)  
3. [Getting Started & Configuration](#3-getting-started--configuration)  
   1. [Development Mode](#31-development-mode)  
   2. [Environment Variables](#32-environment-variables)  
   3. [Self-Hosted Runner Setup](#33-self-hosted-runner-setup)  
4. [Available CI Workflows](#4-available-ci-workflows)  
   1. [Development Mode Toggle](#41-development-mode-toggle)  
       - [Overview](#411-overview)  
       - [Usage](#412-usage)  
       - [Examples: Calling This Workflow](#413-examples-calling-this-workflow)  
       - [Customization](#414-customization)  
       - [Additional Resources](#415-additional-resources)  
   2. [Build VI Package](#42-build-vi-package)  
   3. [Run Unit Tests](#43-run-unit-tests)  
5. [Gitflow Branching & Versioning](#5-gitflow-branching--versioning)  
   1. [Branching Overview](#51-branching-overview)  
   2. [Multi-Channel Pre-Releases](#52-multi-channel-pre-releases)  
   3. [Hotfix Branches](#53-hotfix-branches)  
   4. [Version Bumps via Labels](#54-version-bumps-via-labels)  
   5. [Build Number](#55-build-number)  
6. [Branch Protection & Contributing](#6-branch-protection--contributing)  
7. [GPG Signing (Fork-Friendly)](#7-gpg-signing-fork-friendly)  
8. [External References](#8-external-references)

---

<a name="1-introduction"></a>
## 1. Introduction

Automating your LabVIEW Icon Editor builds and releases offers several benefits:

- **Gitflow alignment**: merges flow from feature → develop → (alpha/beta/rc) → main without manual toggles.  
- **Label-based semantic versioning** (`major`, `minor`, `patch`).  
- **Multiple pre-release channels** (Alpha/Beta/RC) via dedicated branch names.  
- **Commit-based build number** appended as `-build<commitCount>`.  
- **Hotfix branches** for urgent final patch releases.  
- **Fork-friendly GPG signing** toggles.  
- **Development Mode** toggle if you need LabVIEW to reference local source code directly for debugging.

This workflow ensures that all **forks** of the repository can sync the latest build scripts from upstream (e.g., NI) and follow the same rules. If you keep your fork up to date, you benefit from any bug fixes or improvements made in the original repo.

---

<a name="2-quickstart--step-by-step-procedure"></a>
## 2. Quickstart / Step-by-Step Procedure

1. **Set up `.github/workflows`**  
   Ensure the following workflows exist (or adapt names as needed):
   - `development-mode-toggle.yml` (Development Mode Toggle)  
   - `build-vi-package.yml` (Build VI Package)  
   - `run-unit-tests.yml` (Run Unit Tests)

2. **Configure Permissions**  
   - In **Settings → Actions → General**, set **Workflow permissions** to “Read and write permissions” so the workflow can create tags and releases.

3. **Check Environment Variables**  
   - Decide on `DRAFT_RELEASE`, `USE_AUTO_NOTES`, `ATTACH_ARTIFACTS_TO_RELEASE`, `DISABLE_GPG_ON_FORKS`, etc. (see [Environment Variables](#32-environment-variables)).

4. **Make a Pull Request & Label It**  
   - Use labels `major`, `minor`, or `patch` if you need a version bump.  
   - If no label is found, only the build number increments.

5. **Merge to the Appropriate Branch**  
   - In Gitflow, typical merges go from **feature** → **develop**, then eventually to:
     - **`release-alpha/*`** for early testing (`-alpha.<N>`),  
     - **`release-beta/*`** for later testing (`-beta.<N>`),  
     - **`release-rc/*`** for near-final (`-rc.<N>`),  
     - and finally **main** for a final release (no suffix).  
   - Alternatively, **`hotfix/*`** merges can go directly to **main** for quick patches.

6. **Check Outputs and Releases**  
   - The `.vip` file is generated and uploaded as a build artifact.  
   - If `ATTACH_ARTIFACTS_TO_RELEASE == true`, it’s attached to the GitHub Release (draft by default).

7. **Optionally Enable Development Mode**  
   - If you need LabVIEW to reference local source directly, run the **Development Mode Toggle** workflow (see [Development Mode](#31-development-mode)). Usually, you **disable** it for standard builds/tests.

8. **Publish or Finalize the Release**  
   - If your release is drafted, you can edit notes and publish manually. Otherwise, it’s published immediately when `DRAFT_RELEASE == false`.

For a visual reference, you may consult a **Gitflow diagram** that includes alpha/beta/rc branches as an extension of the typical `release/` branch. This helps illustrate how merges flow between `develop` and `main`.

---

<a name="3-getting-started--configuration"></a>
## 3. Getting Started & Configuration

<a name="31-development-mode"></a>
### 3.1 Development Mode

**Development Mode** configures LabVIEW for local debugging or specialized project setups. It often involves modifying `labview.ini` so LabVIEW references local source code. You can **enable** or **disable** it as needed:

- **Enable**:  
  - Run the **Development Mode Toggle** workflow with `mode=enable` (or manually call `Set_Development_Mode.ps1`).
- **Disable**:  
  - Run the workflow with `mode=disable` (or call `RevertDevelopmentMode.ps1`).

> **Important**: When Development Mode is **enabled**, you generally can’t test the final `.vip` install properly (since LabVIEW might be pointing to local source). Always **disable** dev mode before attempting a final install or distribution test.

<a name="32-environment-variables"></a>
### 3.2 Environment Variables

Below are **common** environment variables you might configure:

- **`DRAFT_RELEASE`** (default `true`):  
  - `true` → create a **draft** release (not published).  
  - `false` → publish immediately.
- **`USE_AUTO_NOTES`** (default `true`):  
  - `true` → auto-generate release notes.
- **`ATTACH_ARTIFACTS_TO_RELEASE`** (default `false`):  
  - `true` → attach the built `.vip` files to the release assets.
- **`DISABLE_GPG_ON_FORKS`** (default `false`):  
  - `true` → disable GPG signing if running on a fork.

<a name="33-self-hosted-runner-setup"></a>
### 3.3 Self-Hosted Runner Setup

For **detailed runner configuration**, see **`runner-setup-guide.md`**. Below is a short summary:

1. **Install Prerequisites**  
   - **LabVIEW 2021 SP1** (32-bit or 64-bit)  
   - **PowerShell 7+**  
   - **Git for Windows**  
2. **Add a Self-Hosted Runner**  
   - Go to **Settings → Actions → Runners**. Follow GitHub’s steps to register a Windows runner on your machine with LabVIEW installed.  
3. **Label Your Runner**  
   - For example, `self-hosted, iconeditor`. Ensure your workflow’s `runs-on` references these labels.

---

<a name="4-available-ci-workflows"></a>
## 4. Available CI Workflows

Below are the **three** key workflows. Each one is defined in its own `.yml` file.

<a name="41-development-mode-toggle"></a>
### 4.1 Development Mode Toggle

You’ll typically name the workflow file **`development-mode-toggle.yml`**. Its purpose is to **enable** or **disable** a “development mode” on a self-hosted runner that has LabVIEW installed.

<a name="411-overview"></a>
#### 4.1.1 Overview

**What Is “Development Mode”?**  
- A specialized state for LabVIEW-centric projects, where LabVIEW is configured to load code from local source paths (or apply certain debugging tokens in `labview.ini`).  
- This mode often prevents installing the final `.vip` for normal testing—so you’ll want to toggle it **off** once you finish coding or debugging.

**Purpose of This Workflow**  
- Lets collaborators quickly switch a self-hosted runner into/out of dev mode.  
- Often triggered **manually** (via `workflow_dispatch`) or by other workflows (via `workflow_call`).  
- Simplifies toggling environment state without manual steps each time.

<a name="412-usage"></a>
#### 4.1.2 Usage

1. **Trigger Manually**  
   - Go to the **Actions** tab, select the “Development Mode Toggle” workflow, click “Run workflow.”  
   - Choose `enable` or `disable` to run the corresponding PowerShell script (`Set_Development_Mode.ps1` or `RevertDevelopmentMode.ps1`).  
   - The workflow runs on your self-hosted runner (e.g., labeled `self-hosted, iconeditor`).

2. **Important Note for Testing**  
   - With dev mode **enabled**, LabVIEW references local code, so installing the `.vip` may fail or cause conflicts.  
   - After coding, **disable** dev mode before building or testing the final package.

3. **Trigger from Another Workflow**  
   - You can call this workflow using `workflow_call`. Pass the input parameter `mode` = `enable` or `disable`.  
   - The same runner used by the calling job is toggled accordingly.

<a name="413-examples-calling-this-workflow"></a>
#### 4.1.3 Examples: Calling This Workflow

**A) Call from Another Workflow in the Same Repository**  
```yaml
name: "My Other Workflow"
on:
  workflow_dispatch:

jobs:
  call-dev-mode:
    runs-on: [self-hosted, iconeditor]
    steps:
      - name: Invoke Dev Mode Toggle (enable)
        uses: ./.github/workflows/development-mode-toggle.yml
        with:
          mode: enable
```

**B) Call from Another Repository**  
```yaml
name: "Cross-Repo Dev Mode Toggle"
on:
  workflow_dispatch:

jobs:
  remote-dev-mode:
    runs-on: [self-hosted, iconeditor]
    steps:
      - name: Use remote Dev Mode Toggle
        uses: <owner>/<repo>/.github/workflows/development-mode-toggle.yml@main
        with:
          mode: disable
```

**C) Call from a Fork**  
```yaml
name: "Forked Dev Mode Example"
on:
  workflow_dispatch:

jobs:
  forked-workflow-call:
    runs-on: [self-hosted, iconeditor]
    steps:
      - name: Call Dev Mode Toggle from My Fork
        uses: <your-fork>/<repo>/.github/workflows/development-mode-toggle.yml@my-feature-branch
        with:
          mode: enable
```

<a name="414-customization"></a>
#### 4.1.4 Customization

All dev-mode logic resides in two PowerShell scripts:

- **`Set_Development_Mode.ps1`** – Called when mode is `enable`.  
- **`RevertDevelopmentMode.ps1`** – Called when mode is `disable`.

<a name="415-additional-resources"></a>
#### 4.1.5 Additional Resources

- Check your primary README or docs for LabVIEW setup details.  
- Official GitHub Docs on [Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows).

---

<a name="42-build-vi-package"></a>
### 4.2 Build VI Package

- **File Name**: `build-vi-package.yml`  
- **Purpose**: Builds the `.vip` artifact, determines the version based on PR labels and commit count, and optionally creates/releases the tag.  
- **Features**:  
  - **Label-based** version bump (`major`, `minor`, `patch`), or none if unlabeled.  
  - **Commit-based build number**: `vX.Y.Z-build<commitCount>` (plus optional pre-release suffix).  
  - **Multi-Channel** detection for `release-alpha/*`, `release-beta/*`, `release-rc/*`.  
  - **Fork-Friendly GPG**: Disabled if `DISABLE_GPG_ON_FORKS == true`.  
  - **Attach to Release** if `ATTACH_ARTIFACTS_TO_RELEASE == true`.
- **Events**: Typically triggered on:
  - Push or PR merge to `release-alpha/*`, `release-beta/*`, `release-rc/*`, `main`, and `hotfix/*`.  
  - Might also be triggered manually (`workflow_dispatch`) if needed.

<a name="43-run-unit-tests"></a>
### 4.3 Run Unit Tests

- **File Name**: `run-unit-tests.yml`  
- **Purpose**: Executes the Icon Editor’s unit tests (e.g., via `unit_tests.ps1`) in a **standard** LabVIEW environment (Dev Mode **disabled**).  
- **Usage**: Typically run on every pull request or push to validate code changes.
- **Events**: Often triggered on PRs or pushes to `develop`, `feature/*`, or any branch being tested.

---

<a name="5-gitflow-branching--versioning"></a>
## 5. Gitflow Branching & Versioning

<a name="51-branching-overview"></a>
### 5.1 Branching Overview

**Gitflow** typically involves:
- **`develop`**: main integration branch for ongoing development.  
- **`feature/*`**: branches off `develop` for individual features.  
- **`release/*`**: branched off `develop` when nearing release.  
- **`hotfix/*`**: branched off `main` for urgent fixes.  

In this repo, we extend the concept of `release/*` into **`release-alpha/*`, `release-beta/*`, and `release-rc/*`** to differentiate pre-release stages. Merges flow as:
- **feature** → **develop** → **release-alpha/X.Y** → **release-beta/X.Y** → **release-rc/X.Y** → **main**.

<a name="52-multi-channel-pre-releases"></a>
### 5.2 Multi-Channel Pre-Releases

Branches named:
- **`release-alpha/*`** → produces a version suffix `-alpha.<N>`.  
- **`release-beta/*`** → produces a version suffix `-beta.<N>`.  
- **`release-rc/*`** → produces a version suffix `-rc.<N>`.  

Merging into these branches (or pushing directly to them) triggers a **pre-release build**. After final testing in `release-rc/*`, merging into **main** yields a stable release without any suffix.

<a name="53-hotfix-branches"></a>
### 5.3 Hotfix Branches

- **`hotfix/*`** merges produce a **final** release (no `-rc`, `-alpha`, or `-beta`).  
- Typically, you merge hotfix branches directly into **main** and then back into **develop** to keep them in sync.

<a name="54-version-bumps-via-labels"></a>
### 5.4 Version Bumps via Labels

When you open a **Pull Request** into `develop`, `release-alpha/*`, or `release-beta/*` (or even `main`/`hotfix/*`):
- A label of `major`, `minor`, or `patch` increments that segment of the version (e.g., `1.2.3` → `2.0.0` if `major`, etc.).  
- If **no** label is present, the major/minor/patch remains the same (only the build number increments).

> **Note**: This means you can version-bump **incrementally** while merging into `develop` (to reflect that new features are in development), or you can wait until you merge to a pre-release branch. Each time the build runs, the resulting `.vip` has an updated version (with a new build number, plus any alpha/beta/rc suffix if applicable).

<a name="55-build-number"></a>
### 5.5 Build Number

- Determined by **`git rev-list --count HEAD`**.  
- Appended as `-build<commitCount>` in the final version string.  
- Always strictly the commit count—no overrides by default.

---

<a name="6-branch-protection--contributing"></a>
## 6. Branch Protection & Contributing

In order to **enforce** the Gitflow approach “hands-off”:
1. **Enable Branch Protection Rules**:  
   - For example, protect `main`, `release-alpha/*`, `release-beta/*`, and `release-rc/*` so that only approved Pull Requests can be merged, preventing direct pushes.  
   - Require checks (like “Build VI Package” or “Run Unit Tests”) to pass before merging.
2. **Refer to `CONTRIBUTING.md`**:  
   - Document your team’s policies on how merges flow from feature → develop → alpha/beta/rc → main.  
   - Outline any required approvals or code reviews.  

> **Only the original (upstream) repo** typically **enforces** these rules. Forks may choose to adopt them but are not forced to. However, if you submit a PR **upstream**, you’ll need to comply with the branch protections in place there.

---

<a name="7-gpg-signing-fork-friendly"></a>
## 7. GPG Signing (Fork-Friendly)

The workflows support **GPG signing** for tags and releases in the **main** repository. However, on forks you often lack the GPG key/passphrase. To avoid blocking prompts:

- **`DISABLE_GPG_ON_FORKS = true`** automatically **disables** signing if the workflow detects it’s running on a fork.  
- If you’re in the **main** repo and have GPG keys set up, signing remains **enabled**.

This ensures forks can build without requiring special key setup, while the main repository can maintain secure signing.

---

<a name="8-external-references"></a>
## 8. External References

- **Multi-Channel Logic**: See [docs/ci/actions/multichannel-release-workflow.md](docs/ci/actions/multichannel-release-workflow.md) for deeper details on alpha, beta, and RC release strategies.  
- **Runner Setup**: For an in-depth guide on configuring your environment, see **`runner-setup-guide.md`**.  
- **Troubleshooting & FAQ**: See **TROUBLESHOOTING_AND_FAQ.md** (or your chosen file name) for a detailed list of common issues, solutions, and frequently asked questions.  
- **Contributing**: For main-merge rules, code review guidelines, and other policies, see **`CONTRIBUTING.md`**.  
- **Gitflow Diagram**: [Atlassian Gitflow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) or any other standard resource to visualize the overall branching approach (extended with alpha/beta/rc branches).

---

