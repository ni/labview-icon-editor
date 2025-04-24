# **Introduction**

This document is designed to help maintainers, contributors, and engineers automate the release process for LabVIEW-based projects—particularly the **Icon Editor**. By following this workflow, you can:

- Incorporate **label-based semantic versioning** to increment major, minor, or patch numbers automatically.
- Integrate a **commit-based build number** so each new commit naturally increases a “build” suffix (e.g., `-build42`).
- Seamlessly **build** a `.vip` file and **publish** it through GitHub Actions, optionally attaching it to a release.
- **Disable GPG signing** on forks, avoiding errors for contributors who lack the main repository’s signing keys.

> Whether you’re merging a pull request, pushing hotfixes directly, or working on release branches with RC tags, this workflow unifies your entire packaging and release pipeline under a single YAML definition.


# **Table of Contents**

1. [1. Overview and Purpose](#1-overview-and-purpose)
   - [1.1 What Problem Does This GitHub Action Solve?](#11-what-problem-does-this-github-action-solve)
   - [1.2 Why Was It Created & Primary Function](#12-why-was-it-created--primary-function)
   - [1.3 Intended Users](#13-intended-users)
   - [1.4 High-Level Benefits](#14-high-level-benefits)
2. [2. Environment & Requirements](#2-environment--requirements)
   - [2.1 Supported Windows OS Versions](#21-supported-windows-os-versions)
   - [2.2 Windows-Specific Prerequisites](#22-windows-specific-prerequisites)
   - [2.3 Additional Software & Tools](#23-additional-software--tools)
   - [2.4 Permissions & Credentials](#24-permissions--credentials)
   - [2.5 Hardware/Performance Considerations](#25-hardwareperformance-considerations)
3. [3. Action Configuration & Usage](#3-action-configuration--usage)
   - [3.1 How the Action Is Triggered](#31-how-the-action-is-triggered)
   - [3.2 Configurable Inputs / Parameters](#32-configurable-inputs--parameters)
   - [3.3 Customization & Fork Setup](#33-customization--fork-setup)
   - [3.4 Artifact Publication](#34-artifact-publication)
4. [4. Workflow Details](#4-workflow-details)
   - [4.1 Pipeline Overview](#41-pipeline-overview)
   - [4.2 Version or Tagging Steps](#42-version-or-tagging-steps)
   - [4.3 Pre-Release vs. Final Release](#43-pre-release-vs-final-release)



## 1. **Overview and Purpose**

### 1.1 What Problem Does This GitHub Action Solve?
The **Build VI Package** workflow provides a **consistent, automated release process** for LabVIEW-based projects like the Icon Editor. Instead of manually labeling versions, packaging `.vip` artifacts, and drafting releases, this workflow:

1. **Detects PR labels** (`major`, `minor`, `patch`) to decide version increments.  
2. Automatically **builds** a `.vip` file using a PowerShell script.  
3. Optionally **disables GPG signing** if the repo is a **fork**—avoiding errors from missing keys.  
4. **Pushes tags** and creates **GitHub Releases**, attaching the `.vip` artifact if desired.

It eliminates confusion around versioning, keeps everything in one pipeline, and ensures every commit or merge triggers a reproducible build.

### 1.2 Why Was It Created & Primary Function
- **Why**:  
  - Old manual processes for releasing LabVIEW add-ons involved manually bumping versions, creating `.vip` files, and drafting GitHub releases by hand. This was prone to mistakes.  
- **Primary Function**:  
  - Offer a single, fork-friendly script that compiles the `.vip`, increments the version, and publishes a release.  

### 1.3 Intended Users
- **Library Maintainers** needing reliable, standardized version increments.  
- **CI/CD Engineers** who want to embed LabVIEW packaging in a broader automation ecosystem.  
- **Fork Contributors** able to run the same workflow in their fork without GPG key issues.

### 1.4 High-Level Benefits
- **Label-Based Version Bumping**: Maintainers just add `major`, `minor`, or `patch` labels to the PR, no custom scripts needed.  
- **Commit-Based Build Number**: Every commit increments a “build” suffix, ensuring no collisions.  
- **Fork-Friendly**: If the repo name indicates it’s not the official one, GPG signing toggles off.  
- **Simplicity**: All steps—build, artifact upload, release creation—are in a single YAML file.



## 2. **Environment & Requirements**

### 2.1 Supported Windows OS Versions
- Typically tested on **Windows Server 2019** or **2022** for self-hosted runners.
- Any Windows environment hosting LabVIEW and `.NET` frameworks needed for your build scripts should suffice.

### 2.2 Windows-Specific Prerequisites
- **PowerShell 7+** recommended (since the script uses `pwsh`).  
- **LabVIEW** itself installed on the runner, including any **Application Builder** or modules required to build `.vip` files.  
- (Optional) Additional Windows components (like .NET or Visual Studio) if your pipeline references them.

### 2.3 Additional Software & Tools
- **Build Tools**: Some steps may call internal scripts (`Build.ps1`) that assume a certain LabVIEW version or environment.  
- **Chocolatey** or other package managers only if your script references them.  
- No `gh` CLI is strictly required—this workflow relies on `Invoke-RestMethod` for uploading release assets if needed.

### 2.4 Permissions & Credentials
- **contents: write**: The GITHUB_TOKEN must allow pushing tags and creating releases.  
- For **forks**, no special credentials are needed beyond GITHUB_TOKEN—if GPG is disabled, there’s no passphrase to worry about.

### 2.5 Hardware/Performance Considerations
- Building LabVIEW packages can be memory- and CPU-intensive. The runner should have enough resources for your largest builds (e.g., 4+ cores, 8GB+ RAM).  
- Disk space: Keep enough free space for intermediate build files. 
- If your build is slow or times out, consider caching or incremental builds.



## 3. **Action Configuration & Usage**

### 3.1 How the Action Is Triggered
- **push**: On branches `main`, `develop`, `release/*`, `hotfix/*`.  
- **pull_request**: For PRs into those branches, so you can detect version labels.  
- **workflow_dispatch**: Maintainers can manually run from the Actions tab if needed (e.g., for a hotfix you want to re-release).

### 3.2 Configurable Inputs / Parameters
- **Environment Variables**:
  - `DRAFT_RELEASE` (`true`/`false`): Are releases initially **draft**?  
  - `USE_AUTO_NOTES` (`true`/`false`): Use GitHub’s auto-generated release notes?  
  - `ATTACH_ARTIFACTS_TO_RELEASE` (`true`/`false`): Attach the `.vip` to the final release?  
  - `DISABLE_GPG_ON_FORKS` (`true`/`false`): If `true`, toggles off GPG signing for forks.  
- **PR Labels**: `major`, `minor`, `patch`, or none. If none, only the build number changes.

### 3.3 Customization & Fork Setup
- **Fork Setup**:
  1. **Copy** the workflow file (`.github/workflows/build-vi-package.yml`) into your fork.  
  2. **Update** any references to the official repo name (`ni/labview-icon-editor`) if your fork is named differently.  
  3. **Self-Hosted Runner**: Confirm your runner has the `iconeditor` label or update `runs-on` to match your runner’s labels.  
  4. **Write Permissions**: In fork settings → Actions → General, ensure “Workflow Permissions” = “Read and write.”  

- **Overriding Defaults**:
  - In your workflow’s `env:` block or job-level `env:`, you can set `DRAFT_RELEASE: false` if you want automatic publishing, or `ATTACH_ARTIFACTS_TO_RELEASE: true` to attach `.vip`.  
  - If you want GPG signing on your fork, set `DISABLE_GPG_ON_FORKS: false` (though you must provide keys).

### 3.4 Artifact Publication
- By default, the `.vip` is **uploaded** as an ephemeral artifact for that run.  
- If `ATTACH_ARTIFACTS_TO_RELEASE` is true, it’s also added to the GitHub Release under “Assets” so users can access it any time.



## 4. **Workflow Details**

### 4.1 Pipeline Overview

1. **Disable GPG Signing (if Fork)**  
   - If `DISABLE_GPG_ON_FORKS == true` and `github.repository` doesn’t match the official repo name, the workflow sets `commit.gpgsign=false` and `tag.gpgsign=false`.  
   - Purpose: Avoid passphrase prompts or errors for fork maintainers without GPG keys.

2. **Check Out & Full Clone**  
   - Uses `actions/checkout@v3` with `fetch-depth: 0` so we get the entire commit history (required for commit-based build number).

3. **Determine Bump Type**  
   - On PR events, scans the PR labels: `major`, `minor`, `patch`, or defaults to `none`.  
   - If `none`, no version increment beyond the build number.

4. **Commit-Based Build Number**  
   - We run `git rev-list --count HEAD`, storing the integer in `new_build_number`.  
   - This increments automatically with every commit, ensuring a unique build suffix like `-build37`.

5. **Compute Final Version**  
   - Merges the label-based bump with existing tags (if any).  
   - If on `release/*` branch, appends a `-rc.<N>` suffix.  
   - Always adds `-build<BUILD_NUMBER>` last, e.g. `v1.2.3-rc.5-build37`.

6. **Build the Icon Editor VI Package**  
   - Calls a script (`Build.ps1`) that actually compiles LabVIEW code and produces a `.vip` file in `builds/VI Package/`.

7. **Capture & Upload Artifacts**  
   - Finds the `.vip` in `builds/VI Package/`.  
   - Uploads it as an ephemeral artifact for the current Actions run.

8. **Tag & Push**  
   - If it’s not a pull request event, creates an annotated tag (e.g., `v1.2.3-build37`) and pushes it to the remote.  
   - Requires `contents: write` permission for the `GITHUB_TOKEN`.

9. **Create GitHub Release**  
   - If `DRAFT_RELEASE` is `true`, it’s a draft release. If `false`, publishes immediately.  
   - If `USE_AUTO_NOTES` is `true`, sets `generate_release_notes: true` for auto content.

10. **Attach `.vip` to the Release** (if `ATTACH_ARTIFACTS_TO_RELEASE == true`)  
   - Uploads the `.vip` to the release’s “Assets” so it’s accessible even after ephemeral artifacts expire.

11. **Re-Enable GPG** (if needed)  
   - If GPG was disabled, the Action restores the original commit/tag signing settings.

### 4.2 Version or Tagging Steps

- **`git describe --tags --abbrev=0`** or a custom pattern `v*.*.*-build*` might be used to find the last version tag.  
- If no prior tags, it defaults to `v0.0.0-build<commitCount>` (plus any suffix if `major/minor/patch` was used).

### 4.3 Pre-Release vs. Final Release

- **`release/*`** branches → Adds `-rc.<N>` suffix to indicate pre-release.  
- Merging back to `main` typically yields a final version with no `-rc`.  
- If `draft_release` is `true`, maintainers can manually convert a draft release to a final one after verifying assets or notes.



## 5. **Security & Permissions**

### 5.1 Secure Data Handling
1. **GITHUB_TOKEN**  
   - This workflow relies on GitHub’s ephemeral GITHUB_TOKEN, which needs enough scope to push tags and create releases (i.e., `contents: write`).
   - Make sure your repository’s settings under **Actions** → **General** → **Workflow permissions** is set to **Read and write permissions**.

2. **LabVIEW License & Keys**  
   - Your self-hosted runner must have a **validly licensed** copy of LabVIEW. If LabVIEW is not licensed or is missing required modules, the build might fail.
   - If you choose to sign `.vip` or other files, ensure the runner has access to the appropriate certificates or GPG keys (if not disabling GPG on forks).

3. **Fork Environments**  
   - If the repository is not the official `ni/labview-icon-editor`, and `DISABLE_GPG_ON_FORKS` is set to `true`, this workflow disables commit and tag signing.  
   - Without that toggle, a fork would often fail if it doesn’t have the correct signing keys available.

4. **No Long-Term Secrets**  
   - By default, no additional secrets are stored. The ephemeral GITHUB_TOKEN is enough for standard tagging and release tasks.

### 5.2 Permission Settings & Enforcement
- If you use **branch or tag protection rules**, configure them so that the GitHub Actions token can create tags.
- To allow auto-tagging on new versions:
  1. **Tag Creation** must not be blocked by your repo’s protection rules.
  2. For changes to the default branch (like `main`), ensure the Action can push if it’s set up with required status checks (or turn on “Allow GitHub Actions to bypass rules” in branch protections).

### 5.3 Fork & Pull Request Security
- For a public fork, limit your workflow’s scope if you worry about malicious PRs.  
- By default, secrets like `GITHUB_TOKEN` are available only in limited capacity on PRs from external repos.  
- GPG signing logic is automatically disabled for forks if you set `DISABLE_GPG_ON_FORKS` to `true`, preventing signing prompts or errors.



## 6. **Maintenance & Administration**

### 6.1 Keeping the Workflow Updated
1. **Actions Versions**  
   - This workflow references certain actions, like `actions/checkout@v3` or `actions/github-script@v6`. Keep an eye on updates or deprecations.
2. **Build.ps1**  
   - If your LabVIEW project evolves or you add steps, update the `Build.ps1` script accordingly.
3. **Windows Runner Updates**  
   - Ensure your self-hosted runner OS is patched and has any new LabVIEW versions if your project updates.

### 6.2 Runner Management
- **Labels**: The workflow uses `runs-on: [self-hosted, iconeditor]`. Confirm your runner has both `self-hosted` and `iconeditor` labels.
- **Resource Monitoring**: If the build is large or slow, upgrade the machine specs or add more runners to handle parallel tasks.

### 6.3 Adding New Features
- You can insert additional steps (e.g., unit tests, static analysis, doc generation) in the YAML. For instance, add a test step before building the `.vip`.
- To do advanced alpha/beta channels, replicate the `release/*` logic with your own branch pattern (e.g., `release-alpha/*` => `-alpha.<N>`).

### 6.4 Delegating Workflow Administration
- If multiple maintainers handle the Action:
  1. Document who can change the `.github/workflows/build-vi-package.yml` file.
  2. Decide if changes to the workflow require a PR review or certain status checks.



## 7. **Usage & Examples**

### 7.1 Pull Requests with Labels
- **Scenario**: You create a PR from a feature branch into `develop`.
- **Action**: Add a label like `major` or `minor`.
- **Result**: Upon merging, the workflow updates that version field (major/minor/patch) plus applies a commit-based build number, then tags & releases.

#### Example:
1. PR labeled `minor`:  
   - Previous version: `v1.2.3-build45`  
   - New version on merge: `v1.3.0-build46`  
   - If it’s `release/*`, might become `v1.3.0-rc.1-build46`.

### 7.2 Direct Push to Main or Develop
- **Scenario**: You quickly push a fix to `develop` without a PR label.
- **Action**: The workflow sees no label, so major/minor/patch remain unchanged. The build number increments automatically.
- **Result**: The new tag might go from `v1.2.3-build46` → `v1.2.3-build47`.

### 7.3 Working on a Release Branch
- **Scenario**: You branch off `release/1.2`.
- **Action**: The workflow appends `-rc.<N>` each time you commit to that release branch, e.g. `v1.2.0-rc.2-build50`.
- **Result**: Merging `release/1.2` back to `main` finalizes `v1.2.0-build51`.

### 7.4 Manually Triggering (workflow_dispatch)
- **Scenario**: A maintainer manually runs the workflow from the Actions tab (if enabled).
- **Action**: Provide any input parameters (if configured), or rely on defaults like `none` for version bump.
- **Result**: The script runs as if it were a push event, producing a tag & release if not a PR context.



## 8. **Testing & Verification**



### 8.1 Fork Testing
1. **Fork the Repo**: Copy `.github/workflows/build-vi-package.yml` to your fork.  
2. **Push Changes**: Create or modify a branch in your fork.  
3. **Open PR (optional)**: If you label it, watch the logs to see if the version increments properly.  
4. **Check the Release**: Ensure a `.vip` file is built, ephemeral artifact is uploaded, and if `ATTACH_ARTIFACTS_TO_RELEASE=true`, it’s attached to your fork’s release assets.

### 8.2 Main Repo Testing
1. Merge a labeled PR (e.g., `patch`) into `develop`.  
2. Observe the workflow’s console output: the version should increment patch by 1, and the build number increments from commit count.  
3. Confirm a new tag & release appear in your main repository’s release list.

### 8.3 LabVIEW-Specific QA
- If you have LabVIEW unit tests, integrate them by adding a step in the YAML:
  ```yaml
  - name: Run LabVIEW Tests
    shell: pwsh
    run: .\pipeline\scripts\TestLabVIEW.ps1
  ```
- Ensure they pass before building the `.vip`. If they fail, the script can exit with a non-zero code, stopping the release.

### 8.4 Checking GPG Toggle
- If your fork is named differently (e.g., `username/lv-icon-fork`), confirm `DISABLE_GPG_ON_FORKS=true` toggles off commit/tag signing. Look for a step titled “Possibly disable GPG signing on forks” in your logs.


## 9. **Troubleshooting**

### 9.1 Common Error Scenarios

1. **No .vip Found**  
   - Likely your `Build.ps1` didn’t place the artifact in `builds/VI Package/`.  
   - Check script logs or the step that locates `.vip`.

2. **Invalid URI** or “Hostname could not be parsed”  
   - The `upload_url` from `createRelease` might still contain `{?name,label}`. The workflow typically splits on `{`, but if that fails, ensure the code properly strips it out before appending `?name=<filename>`.

3. **Permission Errors Pushing Tag**  
   - The GITHUB_TOKEN needs `contents: write` permission.  
   - If your repo or organization uses tag protection, allow GitHub Actions to create tags.

4. **LabVIEW Licensing Failure**  
   - The self-hosted runner might not have a proper LabVIEW license or is missing required toolkits.  
   - Check LabVIEW logs or ensure you’ve got the correct environment on that machine.

### 9.2 Debugging Tips
- **Enable -Verbose** in the script calls, capturing detailed logs.  
- **Check Self-Hosted Runner Logs** on Windows in `%UserProfile%\.runner\` or wherever your runner is installed.  
- **Local Testing**: Try running the same powershell commands locally on a dev environment.

### 9.3 Where to Seek Help
- For general build or GPG issues, consult NI or LabVIEW community forums.  
- For GitHub Actions or workflow YAML syntax, check official GitHub Docs or open an issue on your repo.



## 10. **FAQ**

**Q:** *How do I force a “patch” bump if I push directly to develop?*  
**A:** You can edit the “Determine bump type” step to default to `patch` instead of `none` if no label is found.

**Q:** *What if I want a final release immediately, without draft mode?*  
**A:** Set `DRAFT_RELEASE: false`. Then your release is published the moment the workflow completes.

**Q:** *Can I skip attaching `.vip` to the release but keep ephemeral artifacts?*  
**A:** Yes, keep `ATTACH_ARTIFACTS_TO_RELEASE: false` while the ephemeral artifact upload remains by default.

**Q:** *Do I still need to manually publish the release if it’s a pre-release?*  
**A:** If `DRAFT_RELEASE` is true, you’ll need to “publish” it from draft. If it’s a `-rc` suffix, that’s just a naming convention, but you can finalize or remove that suffix in a subsequent version.

**Q:** How do I override build number or forcibly skip a release?  
**A:** By default, we rely on `git rev-list --count HEAD`. You can change it by passing a custom environment variable or skipping the tag steps.

**Q:** Does it support alpha/beta channels out of the box?  
**A:** You can parse more branch patterns (e.g. `release-alpha/*`) and set a suffix like `-alpha.<N>`. The logic is easily adapted in the “Compute version string” step.

**Q:** What about manual triggers?  
**A:** If `workflow_dispatch` is enabled, you can run it from the Actions tab, typically defaulting to the same logic (`none` for bump).

**Q:** Where do I see ephemeral artifacts?  
**A:** In the Actions run logs. Look for the “Artifacts” section. If you attach the `.vip` to the release, it’s permanent under “Assets” in the Release page.

## 11. **Conclusion**

By properly setting up environment variables, referencing your LabVIEW environment on a self-hosted runner, and using label-based version increments plus a commit-based build number, this GitHub Action automates your entire `.vip` build and release pipeline. Fork owners can disable GPG signing, and maintainers can easily control draft vs. published releases and whether the artifact is attached. Follow the troubleshooting steps if anything goes awry, and enjoy streamlined LabVIEW CI/CD!


