# **Introduction**

This document is designed to help maintainers, contributors, and engineers automate the build and packaging process for LabVIEW-based projects—particularly the **Icon Editor**. By following this workflow, you can:

- Incorporate **label-based semantic versioning** to increment major, minor, or patch numbers automatically.
- Integrate a **commit-based build number** so each new commit naturally increases a “build” suffix (e.g., `-build42`).
- Seamlessly **build** a `.vip` file and **upload** it as an artifact through GitHub Actions as the packaging handoff point.

> This guide documents packaging behavior. Release publication policy is defined in [CI Workflows Overview](../../ci-workflows.md), with normative prerelease contract details in [VI Package Pre-Release Requirements](../../vip-prerelease-requirements.md).


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
3. **Uploads artifacts** for the build and hands them off to the repository release publication policy.

It eliminates confusion around versioning, keeps everything in one pipeline, and ensures every commit or merge triggers a reproducible build.

### 1.2 Why Was It Created & Primary Function
- **Why**:  
  - Old manual processes for releasing LabVIEW add-ons involved manually bumping versions, creating `.vip` files, and drafting GitHub releases by hand. This was prone to mistakes.  
- **Primary Function**:
  - Offer a single, fork-friendly packaging path that compiles the `.vip`, increments the version, and uploads the resulting artifact for release handoff.

### 1.3 Intended Users
- **Library Maintainers** needing reliable, standardized version increments.  
- **CI/CD Engineers** who want to embed LabVIEW packaging in a broader automation ecosystem.  

### 1.4 High-Level Benefits
- **Label-Based Version Bumping**: Maintainers just add `major`, `minor`, or `patch` labels to the PR, no custom scripts needed.  
- **Commit-Based Build Number**: Every commit increments a “build” suffix, ensuring no collisions.  
- **Fork-Friendly**: The workflow runs in forks without requiring extra credentials.
- **Simplicity**: Build and artifact upload steps are combined in a single YAML file, with release publishing policy centralized in `docs/ci-workflows.md`.



## 2. **Environment & Requirements**

### 2.1 Supported Windows OS Versions
- Typically tested on **Windows Server 2019** or **2022** for self-hosted runners.
- Any Windows environment hosting LabVIEW and `.NET` frameworks needed for your build scripts should suffice.

### 2.2 Windows-Specific Prerequisites
- **PowerShell 7+** recommended (since the script uses `pwsh`).  
- **LabVIEW** itself installed on the runner, including any **Application Builder** or modules required to build `.vip` files.  
- (Optional) Additional Windows components (like .NET or Visual Studio) if your pipeline references them.

### 2.3 Additional Software & Tools
- **Build Tools**: The composite workflow uses the `build-project-spec` and `build-vi-package` GitHub actions to compile libraries and create the `.vip` package.
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
The `build-vi-package` directory defines a **composite action**. It does not listen for events on its own; instead, the CI workflow in [`ci-composite.yml`](../../../.github/workflows/ci-composite.yml) invokes it.
That workflow runs on `push`, `pull_request`, and `workflow_dispatch` events. Early jobs like `run-metadata`, `prerelease-context`, `version-gate`, and `changes` run on GitHub-hosted `ubuntu-latest`. Windows self-hosted jobs handle LabVIEW validation and packaging (`dev-mode-gate`, `unit-tests`, `build-ppl-x64`, `build-ppl-x86`, `build-vip`) when the active `ci_profile` requires them. Current branch filters for push/PR triggers are `main`, `develop`, `release/*`, `feature/*`, and `hotfix/*` in `ci-composite.yml`.
Companion workflow note: [`ci.yml`](../../../.github/workflows/ci.yml) is PR-only (`pull_request`) and intentionally omits publish-path jobs.

### 3.2 Configurable Inputs / Parameters
`ci-composite.yml` calls this action and provides all required inputs automatically. When invoking
`build-vi-package` from another workflow, supply the following parameters
(see [action.yml](../../../.github/actions/build-vi-package/action.yml) for details):

| Input | Description |
| --- | --- |
| `supported_bitness` | `32` or `64`; selects the VI Package bitness. |
| `labview_version` | Defaults to `.lvversion`; if provided it must match. |
| `labview_minor_revision` | Defaults to `.lvversion`; if provided it must match. |
| `major` | Major version component. |
| `minor` | Minor version component. |
| `patch` | Patch version component. |
| `build` | Build number. |
| `commit` | Commit identifier. |
| `release_notes_file` | Path to release notes file. |
| `display_information_json` | DisplayInformation JSON string. |

The action automatically uses the first `.vipb` file found in `.github/actions/build-vi-package`.

The `major`, `minor`, and `patch` inputs are derived from pull-request labels (`major`,
`minor`, `patch`) by the `version` job (which runs the `compute-version` action) in
`ci-composite.yml`. If a pull request lacks these labels, the `compute-version` action
defaults to bumping the patch version. For direct pushes without labels, the version
components remain unchanged and only the build number increases.

### 3.3 Customization & Fork Setup
- **Fork Setup**:
  1. **Copy** the workflow file (`.github/workflows/ci-composite.yml`) into your fork.
  2. **Update** any references to the official repo name (`ni/labview-icon-editor`) if your fork is named differently.
 3. **Self-Hosted Runner**: Confirm your runner uses the `self-hosted-windows-lv-ie` label (or the value set in `LVIE_RUNNER_LABEL`) or update `runs-on` to match your runner’s labels.
  4. **Write Permissions**: In fork settings → Actions → General, ensure “Workflow Permissions” = “Read and write.”

### 3.4 Artifact Publication
- Packaging output: the `.vip` is uploaded as a run artifact by `build-vip`.
- Publication contract: prerelease publication is defined by [`vip-prerelease-requirements.md`](../../vip-prerelease-requirements.md), including eligibility, version binding, and required asset rules.
- Manual publish intent: `workflow_dispatch` can publish eligible assets only when `publish_prerelease=true`, `expected_sha=<sha>`, and `strict_sha=true`.
- `ci_profile` behavior:
  - `full` and `pr-fast` runs include `build-vip` and full prerelease asset expectations.
  - `release-priority` (`workflow_dispatch` + `force_gcli_lunit=true`) intentionally skips `build-vip` and publishes container packed-library assets only.
  - Release-priority publish intent requires a successful `full` profile run on `develop` within the previous 24 hours.



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
   - For optional legacy channel branch names (`release-alpha/*`, `release-beta/*`, `release-rc/*`), `compute-version` appends `-alpha.<commitCount>`, `-beta.<commitCount>`, or `-rc.<commitCount>` respectively. Here `<N>` equals the commit count, matching [`compute-version`](../../../.github/actions/compute-version/action.yml).
   - Always adds `-build<BUILD_NUMBER>` last (for example, `v1.2.3-build37` or `v1.2.3-rc.37-build37` when legacy channel suffixes are used).

5. **Build the Icon Editor VI Package**
   - Uses the `build-project-spec` action to compile the packed libraries.
   - Downloads both packed libraries (`lv_icon_x86.lvlibp`, `lv_icon_x64.lvlibp`) as required inputs for packaging.
   - Generates a display-information JSON blob that now includes:
     - semantic-version components (`major`, `minor`, `patch`, `build`),
     - repository-derived metadata (company/author names, homepage URL, and description), and
     - the markdown release notes captured from `Tooling/deployment/release_notes.md`.
   - Runs the Windows/self-hosted `build-vip` packaging path for `full` and `pr-fast` profiles.
   - `release-priority` profile intentionally skips `build-vip` to prioritize publish latency.

6. **Capture & Upload Artifacts**
   - Uploads the generated `.vip` as an ephemeral artifact for the current Actions run.

### 4.2 Version or Tagging Steps

- **`git describe --tags --abbrev=0`** or a custom pattern `v*.*.*-build*` might be used to find the last version tag.  
- If no prior tags, it defaults to `v0.0.0-build<commitCount>` (plus any suffix if `major/minor/patch` was used).

### 4.3 Pre-Release vs. Final Release

- Develop prereleases are governed by [`vip-prerelease-requirements.md`](../../vip-prerelease-requirements.md).
- Prerelease publication is manual-intent via `workflow_dispatch` (`publish_prerelease=true`, `expected_sha=<sha>`, `strict_sha=true`) and uses `needs.version.outputs.VERSION` as tag/title.
- Optional legacy behavior: `compute-version` still supports alpha/beta/rc suffixes for `release-alpha/*`, `release-beta/*`, and `release-rc/*` branch names.
- Merging to `main` remains the stable/final release path.



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
   - If your LabVIEW project evolves or you add steps, keep the `build-project-spec` and `build-vi-package` actions up to date.
3. **Windows Runner Updates**  
   - Ensure your self-hosted runner OS is patched and has any new LabVIEW versions if your project updates.

### 6.2 Runner Management
- **Labels**: The workflow uses `runs-on` with `LVIE_RUNNER_LABEL` fallback to `self-hosted-windows-lv`. Confirm your runner has the required Windows label(s).
- **Resource Monitoring**: If the build is large or slow, upgrade the machine specs or add more runners to handle parallel tasks.

### 6.3 Adding New Features
- You can insert additional steps (e.g., unit tests, static analysis, doc generation) in the YAML. For instance, add a test step before building the `.vip`.
- To add additional legacy channel suffixes, extend `compute-version` branch suffix logic (for example, `release-gamma/*` => `-gamma.<N>`), and align workflow triggers if those channels should run automatically.

### 6.4 Delegating Workflow Administration
- If multiple maintainers handle the Action:
  1. Document who can change the `.github/workflows/ci-composite.yml` file.
  2. Decide if changes to the workflow require a PR review or certain status checks.



## 7. **Usage & Examples**

### 7.1 Pull Requests with Labels
- **Scenario**: You create a PR from a feature branch into an integration branch.
- **Action**: Add a label like `major` or `minor`.
- **Result**: Upon merge-commit merge (`--merge`), the workflow updates that version field (major/minor/patch) and applies a commit-based build number. If the PR has no version label, the patch version is bumped by default. The `.vip` artifact is uploaded. Publication remains manual-intent via `workflow_dispatch`.

#### Example:
1. PR labeled `minor`:
   - Previous version: `v1.2.3-build45`
   - New version on merge: `v1.3.0-build46`
   - Optional legacy channel example: `release-rc/*` may produce `v1.3.0-rc.46-build46` (`release-alpha/*` and `release-beta/*` similarly yield `-alpha.<commitCount>` and `-beta.<commitCount>`).

### 7.2 Direct Push to Main or Develop
- **Scenario**: You quickly push a fix to `develop` without opening a PR.
- **Action**: With no pull request labels available, major/minor/patch remain unchanged while the build number increments automatically.
- **Result**: The version might progress from `v1.2.3-build46` to `v1.2.3-build47`, and the pipeline runs the Windows VI Package packaging path.

### 7.3 Optional Legacy Channel Branches
- **Scenario**: Your repository intentionally uses legacy channel branches such as `release-rc/1.2`.
- **Action**: `compute-version` appends `-rc.<commitCount>` on that branch (for example, `v1.2.0-rc.50-build50`). Branches named `release-alpha/1.2` or `release-beta/1.2` similarly append `-alpha.<commitCount>` or `-beta.<commitCount>`.
- **Result**: You can still finalize on `main` without a prerelease suffix. Use this as an optional legacy model, not the default policy.

### 7.4 Manually Triggering (workflow_dispatch)
- **Scenario**: A maintainer manually runs the workflow from the Actions tab (if enabled).
- **Action**: For prerelease backfill, set `publish_prerelease=true`, set `expected_sha` to the merged `develop` SHA, and set `strict_sha=true`. Use `force_gcli_lunit=true` only when intentionally selecting `release-priority` mode.
- **Result**: `full` dispatch runs produce `.vip` artifacts; `release-priority` dispatch runs skip `build-vip`, require a recent successful `full` run on `develop` (<=24h), and publish container packed-library assets when all prepublish gate checks succeed.

## 8. **Testing & Verification**



### 8.1 Fork Testing
1. **Fork the Repo**: Copy `.github/workflows/ci-composite.yml` to your fork.
2. **Push Changes**: Create or modify a branch in your fork.
3. **Open PR (optional)**: If you label it, watch the logs to see if the version increments properly.
4. **Check Artifacts**: Ensure a `.vip` file is built and uploaded as an artifact for your run.

### 8.2 Main Repo Testing
1. Merge a labeled PR (e.g., `patch`) into `develop`.  
2. Observe the workflow’s console output: the version should increment patch by 1, and the build number increments from commit count.  
3. Verify that the `.vip` artifact is available and that prerelease publication behavior matches policy (manual `workflow_dispatch` with explicit publish intent and SHA binding).

### 8.3 LabVIEW-Specific QA
- If you have LabVIEW unit tests, run them directly through `g-cli lunit` and then parse the report:
  ```yaml
  - name: Run LUnit
    shell: pwsh
    run: |
      $report = Join-Path $env:REPO_ROOT '.github/actions/run-unit-tests/UnitTestReport.xml'
      & g-cli --lv-ver $env:LABVIEW_VERSION_YEAR --arch ${{ matrix.bitness }} lunit -- -r $report "$env:PROJECT_PATH"
      $gcliExit = $LASTEXITCODE
      & pwsh -NoProfile -File .github/actions/run-unit-tests/RunUnitTests.ps1 -LabVIEWVersion $env:LABVIEW_VERSION_YEAR -SupportedBitness ${{ matrix.bitness }} -ReportPath $report
      $parserExit = $LASTEXITCODE
      if ($gcliExit -ne 0) { exit $gcliExit }
      exit $parserExit
  ```
- Ensure they pass before building the `.vip`. If they fail, the script can exit with a non-zero code, stopping the workflow run.

## 9. **Troubleshooting**

### 9.1 Common Error Scenarios

1. **No .vip Found**
   - Ensure the `build-vi-package` action completed successfully and produced the artifact.
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
**A:** `compute-version` supports alpha/beta/rc suffixes for `release-alpha/*`, `release-beta/*`, and `release-rc/*` branch names. Treat this as optional legacy behavior unless your repository explicitly adopts those channels.

**Q:** What about manual triggers?  
**A:** If `workflow_dispatch` is enabled, you can run it from the Actions tab, typically defaulting to the same logic (`none` for bump).

**Q:** Where do I see ephemeral artifacts?
**A:** In the Actions run logs. Look for the “Artifacts” section. Publication rules for turning those artifacts into GitHub releases are documented in `docs/ci-workflows.md`.

## 11. **Conclusion**

By properly setting up environment variables, referencing your LabVIEW environment on a self-hosted runner, and using label-based version increments plus a commit-based build number, this GitHub Action automates `.vip` build and artifact handoff. Use `docs/ci-workflows.md` as the canonical release/publication policy source (manual-intent prerelease publication and explicit dispatch controls).




