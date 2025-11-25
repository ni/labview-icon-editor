# **Introduction**

This document is designed to help maintainers, contributors, and engineers automate the build and packaging process for LabVIEW-based projects—particularly the **Icon Editor**. By following this workflow, you can:

- Incorporate **label-based semantic versioning** to increment major, minor, or patch numbers automatically.
- Integrate a **commit-based build number** so each new commit naturally increases a “build” suffix (e.g., `-build42`).
- Seamlessly **build** a `.vip` file and **upload** it as an artifact through GitHub Actions. If you want to publish a release, run a separate workflow to create it.

> Whether you’re merging a pull request, pushing hotfixes directly, or working on release branches with RC tags, this workflow unifies your packaging pipeline under a single YAML definition. Release creation must be handled separately.


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
The **Build VI Package** workflow provides a **consistent, automated build process** for LabVIEW-based projects like the Icon Editor. Instead of manually labeling versions, packaging `.vip` artifacts, and drafting releases, this workflow:

1. **Detects PR labels** (`major`, `minor`, `patch`) to decide version increments.  
2. Automatically **builds** a `.vip` file using a PowerShell script.
3. **Uploads artifacts** for the build; creating tags or GitHub Releases must be handled separately if desired.

It eliminates confusion around versioning, keeps everything in one pipeline, and ensures every commit or merge triggers a reproducible build.

### 1.2 Why Was It Created & Primary Function
- **Why**:  
  - Old manual processes for releasing LabVIEW add-ons involved manually bumping versions, creating `.vip` files, and drafting GitHub releases by hand. This was prone to mistakes.  
- **Primary Function**:
  - Offer a single, fork-friendly script that compiles the `.vip`, increments the version, and uploads the resulting artifact. Release publishing can be managed with another workflow.

### 1.3 Intended Users
- **Library Maintainers** needing reliable, standardized version increments.  
- **CI/CD Engineers** who want to embed LabVIEW packaging in a broader automation ecosystem.  

### 1.4 High-Level Benefits
- **Label-Based Version Bumping**: Maintainers just add `major`, `minor`, or `patch` labels to the PR, no custom scripts needed.  
- **Commit-Based Build Number**: Every commit increments a “build” suffix, ensuring no collisions.  
- **Fork-Friendly**: The workflow runs in forks without requiring extra credentials.
- **Simplicity**: Build and artifact upload steps are combined in a single YAML file; release creation can be added separately.



## 2. **Environment & Requirements**

### 2.1 Supported Windows OS Versions
- Typically tested on **Windows Server 2019** or **2022** for self-hosted runners.
- Any Windows environment hosting LabVIEW and `.NET` frameworks needed for your build scripts should suffice.

### 2.2 Windows-Specific Prerequisites
- **PowerShell 7+** recommended (since the script uses `pwsh`).  
- **LabVIEW** itself installed on the runner, including any **Application Builder** or modules required to build `.vip` files.  
- (Optional) Additional Windows components (like .NET or Visual Studio) if your pipeline references them.

### 2.3 Additional Software & Tools
- **Build Tools**: The composite workflow uses the `build-lvlibp` and `build-vip` GitHub actions to compile libraries and create the `.vip` package.
- **Chocolatey** or other package managers only if your script references them.
- The workflow interacts with GitHub using built-in actions; no `gh` CLI is required.

### 2.4 Permissions & Credentials
- **contents: read**: The GITHUB_TOKEN needs read access to download and upload artifacts.
- For **forks**, no special credentials are required beyond the default token.

### 2.5 Hardware/Performance Considerations
- Building LabVIEW packages can be memory- and CPU-intensive. The runner should have enough resources for your largest builds (e.g., 4+ cores, 8GB+ RAM).  
- Disk space: Keep enough free space for intermediate build files. 
- If your build is slow or times out, consider caching or incremental builds.



## 3. **Action Configuration & Usage**

### 3.1 How the Action Is Triggered
The `build-vip` directory defines a **composite action**. It does not listen for events on its own; instead, the CI workflow in [`ci.yml`](../../../.github/workflows/ci.yml) invokes it.
That workflow runs on `push`, `pull_request`, and `workflow_dispatch` events. The `issue-status` and `changes` jobs run on GitHub-hosted `ubuntu-latest`. Subsequent jobs that require LabVIEW—`apply-deps`, `version`, `test`, `build-ppl`, and `build-vip`—execute on a self-hosted Windows runner (`self-hosted-windows-lv`). Only Windows-specific jobs (e.g., `test`, `build-ppl`, `build-vip`) require the self-hosted runner. Linux support is considered a future or custom expansion: you would need to extend the matrix and provide a corresponding runner label (for example, `self-hosted-linux-lv`). Pushes are limited to `main`, `develop`, `release-alpha/*`, `release-beta/*`, `release-rc/*`, `feature/*`, `hotfix/*`, and `issue-*` branches, and pull requests must target one of those branches. However, `build-vip` executes only if the `issue-status` job allows the pipeline to continue: the source branch name must contain `issue-<number>` (for example, `issue-123` or `feature/issue-123`) and the linked issue's Status must be **In Progress**. For pull requests, the `issue-status` gate evaluates the PR’s head branch before running the `version` and `build-ppl` jobs, which depend on this gate.

### 3.2 Configurable Inputs / Parameters
`ci.yml` calls this action and provides all required inputs automatically. When invoking
`build-vip` from another workflow, supply the following parameters
(see [action.yml](../../../scripts/build-vip/action.yml) for details):

| Input | Description |
| --- | --- |
| `supported_bitness` | `32` or `64`; selects the VI Package bitness. |
| `labview_minor_revision` | LabVIEW minor revision (defaults to `3`). |
| `repository_path` | Workspace root path. |
| `vipb_path` | Path to the VIPB file (relative to the workspace). Leave blank to auto-discover a single `.vipb` under `repository_path`. |
| `major` | Major version component. |
| `minor` | Minor version component. |
| `patch` | Patch version component. |
| `build` | Build number. |
| `commit` | Commit identifier. |
| `release_notes_file` | Path to release notes file. |
| `display_information_json` | DisplayInformation JSON string. |
| `fail_on_multiple_vips` | If `true`, fail when more than one `.vip` is found post-build. |

The action reads the LabVIEW major version from the repository’s VIPB via `scripts/get-package-lv-version.ps1`, so no LabVIEW-version input or override is accepted. If `vipb_path` is omitted or invalid, the action auto-discovers the single `.vipb` under `repository_path`.

**PPL staging expectations (build-vip preflight):**
- `resource/plugins/lv_icon.lvlibp` (neutral)
- `resource/plugins/lv_icon.lvlibp.windows_x64`
- `resource/plugins/lv_icon.lvlibp.windows_x86`

`build-ppl-x64` uploads both the neutral PPL and the windows_x64 variant; `build-ppl-x86` uploads the windows_x86 variant. The `build-vip` job downloads these artifacts into `resource/plugins` so the VIPB references resolve without additional renames. The preflight in `build_vip.ps1` will fail fast if any of the above three files are missing.

The `major`, `minor`, and `patch` inputs are derived from pull-request labels (`major`,
`minor`, `patch`) by the `version` job (which runs the `compute-version` action) in
`ci.yml`. If a pull request lacks these labels, the `compute-version` action
defaults to bumping the patch version. For direct pushes without labels, the version
components remain unchanged and only the build number increases.

### 3.3 Customization & Fork Setup
- **Fork Setup**:
  1. **Copy** the workflow file (`.github/workflows/ci-composite.yml`) into your fork.
  2. **Update** any references to the official repo name (`ni/labview-icon-editor`) if your fork is named differently.
 3. **Self-Hosted Runner**: Confirm your runner uses the `self-hosted-windows-lv` label (or `self-hosted-linux-lv` for Linux jobs) or update `runs-on` to match your runner’s labels.
  4. **Write Permissions**: In fork settings → Actions → General, ensure “Workflow Permissions” = “Read and write.”

### 3.4 Artifact Publication
- The `.vip` is **uploaded** as an ephemeral artifact for that run.



## 4. **Workflow Details**

### 4.1 Pipeline Overview

1. **Check Out & Full Clone**
   - Uses `actions/checkout@v4` with `fetch-depth: 0` so we get the entire commit history (required for the commit-based build number).

2. **Determine Bump Type**
   - On PR events, scans the PR labels: `major`, `minor`, `patch`, or defaults to `none`.  
   - If `none`, no version increment beyond the build number.

3. **Commit-Based Build Number**
   - We run `git rev-list --count HEAD`, storing the integer in `new_build_number`.  
   - This increments automatically with every commit, ensuring a unique build suffix like `-build37`.

4. **Compute Final Version**
   - Merges the label-based bump with existing tags (if any).
   - If on `release-alpha/*`, `release-beta/*`, or `release-rc/*`, appends `-alpha.<commitCount>`, `-beta.<commitCount>`, or `-rc.<commitCount>` respectively. Here `<N>` equals the commit count, matching [`compute-version`](../../../scripts/compute-version/action.yml).
   - Always adds `-build<BUILD_NUMBER>` last, e.g. `v1.2.3-rc.37-build37`. Because both values use the commit count, the pre-release number and build number are identical.

5. **Build the Icon Editor VI Package**
   - Uses the `build-lvlibp` action to compile the packed libraries.
   - Generates a display-information JSON blob that now includes:
     - semantic-version components (`major`, `minor`, `patch`, `build`),
     - repository-derived metadata (company/author names, homepage URL, and description), and
     - the markdown release notes captured from `Tooling/deployment/release_notes.md`.
   - Runs the `build-vip` action to generate the final `.vip` file with those values embedded.

6. **Capture & Upload Artifacts**
   - Uploads the generated `.vip` as an ephemeral artifact for the current Actions run.

### 4.2 Version or Tagging Steps

- **`git describe --tags --abbrev=0`** or a custom pattern `v*.*.*-build*` might be used to find the last version tag.  
- If no prior tags, it defaults to `v0.0.0-build<commitCount>` (plus any suffix if `major/minor/patch` was used).

### 4.3 Pre-Release vs. Final Release

- **`release-alpha/*`, `release-beta/*`, `release-rc/*`** branches → Add `-alpha.<commitCount>`, `-beta.<commitCount>`, or `-rc.<commitCount>` suffixes to indicate pre-release. The `<N>` value equals the commit count and therefore matches the build suffix.
- Merging back to `main` typically yields a final version with no pre-release suffix.
- Maintainers can manually convert a pre-release to a final release after verifying assets or notes.



## 5. **Security & Permissions**

### 5.1 Secure Data Handling
1. **GITHUB_TOKEN**
   - This workflow relies on GitHub’s ephemeral GITHUB_TOKEN with read permissions to access the repository and upload artifacts.
   - Ensure your repository’s settings under **Actions** → **General** → **Workflow permissions** allow the workflow to read contents and publish artifacts.

2. **LabVIEW License**
   - Your self-hosted runner must have a **validly licensed** copy of LabVIEW. If LabVIEW is not licensed or is missing required modules, the build might fail.

3. **No Long-Term Secrets**
   - By default, no additional secrets are stored. The ephemeral GITHUB_TOKEN is enough for standard build tasks.

### 5.2 Fork & Pull Request Security
- For a public fork, limit your workflow’s scope if you worry about malicious PRs.
- By default, secrets like `GITHUB_TOKEN` are available only in limited capacity on PRs from external repos.



## 6. **Maintenance & Administration**

### 6.1 Keeping the Workflow Updated
1. **Actions Versions**
   - This workflow references certain actions, like `actions/checkout@v4` or `actions/github-script@v7`. Keep an eye on updates or deprecations. Update to a newer checkout version when the action itself is revised. Some internal actions—such as `compute-version`—may still pin different releases for compatibility, so mixing versions is expected.
2. **Build Actions**
   - If your LabVIEW project evolves or you add steps, keep the `build-lvlibp` and `build-vip` actions up to date.
3. **Windows Runner Updates**  
   - Ensure your self-hosted runner OS is patched and has any new LabVIEW versions if your project updates.

### 6.2 Runner Management
- **Labels**: The workflow uses `runs-on: self-hosted-windows-lv` (and `self-hosted-linux-lv` where applicable). Confirm your runner has the required label.
- **Resource Monitoring**: If the build is large or slow, upgrade the machine specs or add more runners to handle parallel tasks.

### 6.3 Adding New Features
- You can insert additional steps (e.g., unit tests, static analysis, doc generation) in the YAML. For instance, add a test step before building the `.vip`.
- To add additional channels, replicate the `release-*/*` logic with your own branch pattern (e.g., `release-gamma/*` => `-gamma.<N>`).

### 6.4 Delegating Workflow Administration
- If multiple maintainers handle the Action:
  1. Document who can change the `.github/workflows/ci-composite.yml` file.
  2. Decide if changes to the workflow require a PR review or certain status checks.



## 7. **Usage & Examples**

### 7.1 Pull Requests with Labels
- **Scenario**: You create a PR from a feature branch into `develop`.
- **Action**: Add a label like `major` or `minor`.
- **Result**: Upon merging, the workflow updates that version field (major/minor/patch) and applies a commit-based build number. If the PR has no version label, the patch version is bumped by default. The `.vip` artifact is uploaded; any tagging or release must be handled separately.

#### Example:
1. PR labeled `minor`:
   - Previous version: `v1.2.3-build45`
   - New version on merge: `v1.3.0-build46`
   - If it’s `release-rc/*`, might become `v1.3.0-rc.46-build46` (`release-alpha/*` and `release-beta/*` yield `-alpha.<commitCount>` and `-beta.<commitCount>`).

### 7.2 Direct Push to Main or Develop
- **Scenario**: You quickly push a fix to `develop` without opening a PR.
- **Action**: With no pull request labels available, major/minor/patch remain unchanged while the build number increments automatically.
- **Result**: The version might progress from `v1.2.3-build46` to `v1.2.3-build47`.

### 7.3 Working on a Release Branch
- **Scenario**: You branch off `release-rc/1.2`.
- **Action**: The workflow appends `-rc.<commitCount>` each time you commit to that pre-release branch, e.g. `v1.2.0-rc.50-build50`. Branches named `release-alpha/1.2` or `release-beta/1.2` would similarly append `-alpha.<commitCount>` or `-beta.<commitCount>`; these patterns correspond to the `release-alpha/*`, `release-beta/*`, and `release-rc/*` rules in `ci.yml`.
- **Result**: Merging `release-rc/1.2` back to `main` finalizes `v1.2.0-build51`.

### 7.4 Manually Triggering (workflow_dispatch)
- **Scenario**: A maintainer manually runs the workflow from the Actions tab (if enabled).
- **Action**: Provide any input parameters (if configured), or rely on defaults like `none` for version bump.
- **Result**: The script runs as if it were a push event and produces a `.vip` artifact. Creating tags or releases requires additional steps.



## 8. **Testing & Verification**



### 8.1 Fork Testing
1. **Fork the Repo**: Copy `.github/workflows/ci.yml` to your fork.
2. **Push Changes**: Create or modify a branch in your fork.
3. **Open PR (optional)**: If you label it, watch the logs to see if the version increments properly.
4. **Check Artifacts**: Ensure a `.vip` file is built and uploaded as an artifact for your run.

### 8.2 Main Repo Testing
1. Merge a labeled PR (e.g., `patch`) into `develop`.  
2. Observe the workflow’s console output: the version should increment patch by 1, and the build number increments from commit count.  
3. Verify that the `.vip` artifact is available. If you run a separate release workflow, confirm that the release was created.

### 8.3 LabVIEW-Specific QA
- If you have LabVIEW unit tests, integrate them by adding a step in the YAML:
  ```yaml
  - uses: ./scripts/run-unit-tests
    with:
      repository_path: ${{ github.workspace }}
      supported_bitness: ${{ matrix.bitness }}
  ```
- Ensure they pass before building the `.vip`. If they fail, the script can exit with a non-zero code, stopping the workflow run.

## 9. **Troubleshooting**

### 9.1 Common Error Scenarios

1. **No .vip Found**
   - Ensure the `build-vip` action completed successfully and produced the artifact.
   - Check action logs for errors in the packaging steps.

2. **LabVIEW Licensing Failure**
   - The self-hosted runner might not have a proper LabVIEW license or is missing required toolkits.
   - Check LabVIEW logs or ensure you’ve got the correct environment on that machine.

### 9.2 Debugging Tips
- **Enable -Verbose** in the script calls, capturing detailed logs.  
- **Check Self-Hosted Runner Logs** on Windows in `%UserProfile%\.runner\` or wherever your runner is installed.  
- **Local Testing**: Try running the same powershell commands locally on a dev environment.

### 9.3 Where to Seek Help
- For general build issues, consult NI or LabVIEW community forums.
 - For GitHub Actions or workflow YAML syntax, check official GitHub Docs or open an issue on your repo.



## 10. **FAQ**

**Q:** *How do I force a “patch” bump if I push directly to develop?*
**A:** Use a pull request with the `patch` label. Direct pushes without PR labels always use the previous version numbers.

**Q:** How do I override the build number?
**A:** By default, we rely on `git rev-list --count HEAD`. You can change it by passing a custom environment variable or adjusting the version logic in your workflow.

**Q:** Does it support alpha/beta channels out of the box?
**A:** Yes. Branches `release-alpha/*`, `release-beta/*`, and `release-rc/*` automatically append `-alpha.<commitCount>`, `-beta.<commitCount>`, or `-rc.<commitCount>` during the “Compute version string” step, so the pre-release number matches the build number.

**Q:** What about manual triggers?  
**A:** If `workflow_dispatch` is enabled, you can run it from the Actions tab, typically defaulting to the same logic (`none` for bump).

**Q:** Where do I see ephemeral artifacts?
**A:** In the Actions run logs. Look for the “Artifacts” section. If you later create a release and attach the `.vip`, it becomes permanent under “Assets” on the Release page.

## 11. **Conclusion**

By properly setting up environment variables, referencing your LabVIEW environment on a self-hosted runner, and using label-based version increments plus a commit-based build number, this GitHub Action automates your `.vip` build and artifact upload process. Maintainers can extend the pipeline with tagging or release steps if desired. Follow the troubleshooting steps if anything goes awry, and enjoy streamlined LabVIEW CI/CD!



