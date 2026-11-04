# Local CI/CD Workflows

This document explains how to automate build, test, and distribution steps for the Icon Editor using GitHub Actions. It includes features such as **automatic version bumping** (using labels) and **artifact upload**. Additionally, it shows how you can **brand** the resulting VI Package with **organization** and **repository** metadata for unique identification.

---

## Table of Contents

1. [Introduction](#1-introduction)  
2. [Quickstart](#2-quickstart)  
3. [Detailed Guide](#3-detailed-guide)  
   1. [Development vs. Testing](#31-development-vs-testing)  
   2. [Available CI Workflows](#32-available-ci-workflows)  
   3. [Setting Up a Self-Hosted Runner](#33-setting-up-a-self-hosted-runner)  
   4. [Running the Actions Locally](#34-running-the-actions-locally)  
   5. [Example Developer Workflow](#35-example-developer-workflow)

---

## 1. Introduction

Automating your Icon Editor builds and tests:
- Provides consistent steps for every commit or pull request  
- Minimizes manual toggling of LabVIEW environment settings  
- Stores build artifacts (VI Packages) in GitHub for easy download  
- Automatically versions releases using **semantic version** logic  
- **Allows you to brand** each VI Package build with your organization or repository name for unique identification

**Prerequisites**:
- LabVIEW 2021 SP1 (32-bit and 64-bit) and LabVIEW 2023 (64-bit)
- PowerShell 7+
- Git for Windows

---

## 2. Quickstart

1. **Install PowerShell and Git**  
   Ensure your environment has the required tools before setting up the workflows.

2. **Configure a Self-Hosted Runner**  
   Under **Settings → Actions → Runners** in your GitHub repo or organization, add a runner with LabVIEW installed.

3. **Enable or Disable Development Mode**
   You can toggle Development Mode either via the “Development Mode Toggle” workflow or manually.
   - Development Mode modifies `labview.ini` to reference your local source code.

4. **Run Tests**
   Use the main CI workflow (`ci-composite.yml`) to confirm your environment is valid.
   - The workflow triggers on pushes to or pull requests targeting:
     - `main`
     - release branches: `releases/<YYYY>Q<N>` (e.g. `releases/2027Q1`)
     - feature branches: `feature/*`
     - hotfix branches: `hotfix/*`
     - issue branches: `issue-*`
     - `workflow_dispatch` enables manual runs.
     - Every run—push, pull request, or manual—requires the source branch name to match `issue-<number>` and the linked issue's Status to be **In Progress**; otherwise, downstream jobs are skipped.
     - Typically run with Dev Mode **disabled** unless you’re testing dev features specifically.
     - The `issue-status` job enforces these checks and also skips the workflow if the branch or pull request has a `NoCI` label. Contributors must ensure their issue is added to a project with the required Status. For pull requests, the check inspects the head branch. This gating helps avoid ambiguous runs for automated tools.
     - A concurrency group cancels any previous run on the same branch, ensuring only the latest pipeline execution continues.

5. **Build VI Package**
   - Produces `.vip` artifacts automatically. By default, the workflow populates the **“Company Name”** with `github.repository_owner` and the **“Author Name”** with `github.event.repository.name`, so each build is branded with your GitHub account and repository.
   - To use different branding, edit the **“Generate display information JSON”** step in [`.github/workflows/ci-composite.yml`](../.github/workflows/ci-composite.yml) and supply custom values for these fields.
   - Uses **label-based** version bumping (major/minor/patch) on pull requests.
   - Generates `Tooling/deployment/release_notes.md` summarizing recent commits. Use this file to draft changelogs or release notes.

6. **Disable Dev Mode** (optional)  
   Reverts your environment to normal LabVIEW settings, removing local overrides.

> [!NOTE]
> The workflow automatically brands the VI Package using the repository owner (`github.repository_owner`) and repository name (`github.event.repository.name`). Modify the “Generate display information JSON” step in `.github/workflows/ci-composite.yml` if you need different values.

---

## 3. Detailed Guide

### 3.1 Development vs. Testing

- **Development Mode**:  
  A specialized configuration where LabVIEW references local paths for the Icon Editor code. Useful for debugging or certain dev features.  
  - Enable via `Set_Development_Mode.ps1` or the **Development Mode Toggle** workflow.

- **Testing / Distributable Builds**:  
  Typically done in **normal** LabVIEW mode. If you forget to disable Dev Mode, tests or builds might rely on your local dev environment in unexpected ways.

---

### 3.2 Available CI Workflows

Below are the **key GitHub Actions** provided in this repository:

1. **[Development Mode Toggle](ci/actions/development-mode-toggle.md)**
   - Invokes `Set_Development_Mode.ps1` or `RevertDevelopmentMode.ps1`.  
   - Usually triggered via `workflow_dispatch` for manual toggling.

2. **[Build VI Package](ci/actions/build-vi-package.md)**
   - **Automatically** versions your code based on PR labels (`major`, `minor`, `patch`).
     Direct pushes retain the previous version and increment only the build number.
   - Uses a **build counter** to ensure each artifact is uniquely numbered (e.g., `v1.2.3-build4`).
   - **Fork-Friendly**: Runs in forks without requiring extra signing keys.
   - Produces the `.vip` file via a PowerShell script (e.g., `Build.ps1`).
   - By default, “Company Name” and “Author Name” in the generated `.vip` come from `github.repository_owner` and `github.event.repository.name`. Update the “Generate display information JSON” step in [`ci-composite.yml`](../.github/workflows/ci-composite.yml) if you need custom values.
   - Uploads the `.vip` artifact to GitHub’s build artifacts.

#### Jobs in CI workflow

The [`ci-composite.yml`](../.github/workflows/ci-composite.yml) pipeline breaks the build into several jobs:

- **issue-status** – skips the workflow if the pull request or branch has a `NoCI` label, then queries the **Status** field of the linked GitHub issue’s associated GitHub Project and proceeds only when that field is **In Progress**. Contributors must ensure their issue is added to a project with this Status value. It also requires the source branch name to contain `issue-<number>` (such as `issue-123` or `feature/issue-123`). For pull requests, the job evaluates the PR’s head branch.
- **changes** – checks out the repository and detects `.vipc` file changes to determine if dependencies need to be applied.
- **apply-deps** – installs VIPC dependencies for multiple LabVIEW versions and bitnesses **only when** the `changes` job reports `.vipc` modifications (`if: needs.changes.outputs.vipc == 'true'`).
- **version** – computes the semantic version and build number using commit count and PR labels.
- **missing-in-project-check** – verifies every source file is referenced in the `.lvproj`.
- **test** – runs LabVIEW unit tests on Windows in LabVIEW 2021 (32- and 64-bit).
- **build-ppl** – uses a matrix to build 32-bit and 64-bit packed libraries, then uses the `rename-file` action to append the bitness to each library’s filename.
- **build-vi-package** – packages the final VI Package using the built libraries and version information. In `ci-composite.yml` this job passes `supported_bitness: 64`, so it produces only a 64-bit `.vip`.

Both `build-ppl` and `build-vi-package` run a `close-labview` step after their build actions finish but before any steps that rename files or upload artifacts, so it isn't the job's final step.

The `build-ppl` job uses a matrix to produce both bitnesses rather than distinct jobs.

LUnit tests run in [`ci.yml`](../.github/workflows/ci.yml) as the required `lunit-windows-container` job, calling [`lunit-windows-container-tests.yml`](../.github/workflows/lunit-windows-container-tests.yml). The `windows-2022` job pulls a repository-owned GHCR dependency image tagged with a SHA-256 hash of the Dockerfile and build/setup scripts. On a cache miss it builds the image from `nationalinstruments/labview:2026q1-windows`. Successful builds on non-PR events are published for subsequent runs; PRs build locally if necessary but never publish. Make the GHCR package public for cross-fork reuse; the workflow uses only `GITHUB_TOKEN` for registry access, not VIPM activation secrets.

[`Build-LUnitWindowsImage.ps1`](../Tooling/Build-LUnitWindowsImage.ps1) stages only the setup script and Dockerfile, never the checkout's `.git` or credentials. **VIPM is not used**: its installs repeatedly stalled or failed in Windows containers (refresh/lookup failures, "Not inside a Git repository" for local files, and `wait for VIPM startup` timeouts). Instead, [`lunit-windows.Dockerfile`](../Tooling/containers/lunit-windows.Dockerfile) runs the helper's `Setup` stage, which downloads the pinned public JKI packages (`astemes_lib_lunit` 2.0.13.6 and `astemes_lib_lunit_cli` 1.7.1.32) over HTTPS, checks ZIP signatures and publisher MD5 checksums, extracts them, and copies each package's `File Group 0\vi.lib\Astemes\<package>` tree into LabVIEW's `vi.lib\Astemes`. This is the method that executed all ten tests in a manually prepared container.

This is a CLI-only deployment, not a full VIPM install: package post-install actions (palette menus, global LabVIEW CLI operation registration) are skipped, so the test stage passes `-AdditionalOperationDirectory` pointing at `vi.lib\Astemes\LUnit CLI`. Download, checksum, or missing-folder failures (including a missing `LUnitCLI\RunOperation.vi`) fail the image build. The dependency manifest records the install method, package names, versions, and checksums, plus the LabVIEW file version.

The test container reads that manifest, opens `lv_icon_editor.lvproj`, and runs native `LabVIEWCLI -OperationName LUnit`. LabVIEWCLI can exit 0 even when a test fails, so the workflow validates the JUnit report: it must contain at least 10 non-skipped tests and no failures or errors. **Temporary exception:** `Library Icon Data::Test Write Read Library Icon Data.vi` is allowed to fail only when its single assertion failure is the `NI.Lib.VIIconTemplate` vs `NI_IconEditor` tag mismatch. In headless CLI runs, a plain `Library:Save` does not rename the tag. When this happens, the workflow emits a warning. Any other failure, including a different failure in that same test, still fails the job. Remove the exception once the save behaviour is resolved. Failing tests and their messages are written to the job summary; reports, manifest, and logs are uploaded as `lunit-windows-results-*`. An image build is not proof of passing tests; verify an actual workflow run.

Local image build (Windows Docker engine required; CI builds it automatically):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tooling\Build-LUnitWindowsImage.ps1 `
  -Image lvie-lunit-windows:local
```

If the local `nat` network cannot resolve public hosts, pass `-Network 'Default Switch'` only when that existing Docker network has been verified to work. No global Docker DNS settings are changed.

The Windows workflow supports `workflow_dispatch` as well as `workflow_call`. Passing tests in the Windows desktop UI does not establish that they pass in a headless Windows container; verify the Windows workflow run before merging.

---

### 3.3 Setting Up a Self-Hosted Runner

1. **Install Prerequisites**:
   - LabVIEW 2021 SP1 (32-bit and 64-bit) and LabVIEW 2023 (64-bit)
   - PowerShell 7+
   - Git for Windows

2. **Add Self-Hosted Runner**:  
   Go to **Settings → Actions → Runners** in your GitHub repository (or organization) and follow the steps to register a runner on your machine that has LabVIEW installed.

3. **Label the Runner**:
   - **Canonical label**: `self-hosted-windows-lv` must always be present.
   - The workflows use `LVIE_RUNNER_LABEL` (repo variable) and fall back to `self-hosted-windows-lv`.
   - For forks, set **Settings → Actions → Variables → `LVIE_RUNNER_LABEL`** to match your runner label.
   - If `LVIE_RUNNER_LABEL` is set to a fork-specific label, keep `self-hosted-windows-lv` on the same runner.
   - Example label set: `self-hosted-windows-lv`, `self-hosted-windows-lv-ie`.

4. **Runner Contract (recommended)**:
   - Run `Tooling/Setup-Runner.ps1` to create a runner contract and standardize work roots.
   - The contract is written under the runner root and used by `Tooling/Check-Runner.ps1`.
   - The template is `Tooling/runner-contract.template.json`.
   - CI validates the runner labels using `Tooling/Assert-RunnerLabel.ps1` at job start.

5. **Git safe.directory**:
   - `Tooling/Setup-Runner.ps1` configures a scoped safe.directory for the work root.
   - This prevents Git “dubious ownership” errors when the runner service account differs from the checkout owner.

---

### 3.4 Running the Actions Locally

Although GitHub Actions primarily run on GitHub-hosted or self-hosted agents, you can **replicate** the general process locally:

1. **Enable Development Mode** (if necessary to do dev tasks):  
   - Run the “Development Mode Toggle” workflow with `enable` or manually call `Set_Development_Mode.ps1`.

2. **Run Tests**:
   - Confirm everything passes in your local environment or via the main CI workflow.
   - If you have custom or dev references, ensure Dev Mode is toggled appropriately.

3. **Build VI Package**:
   - Manually invoke `Build.ps1` from `.github/actions/build` to generate a `.vip`.
   - Pass optional metadata fields (e.g., `-CompanyName`, `-AuthorName`) if you want your build to be **branded**.
   - On GitHub Actions, the workflow will produce and upload the artifact automatically.

4. **Disable Dev Mode**:  
   - Revert to a normal LabVIEW environment so standard usage or testing can resume.

---

### 3.5 Example Developer Workflow

**Scenario**: You want to implement a new feature, test it, and produce a **uniquely branded** `.vip`.

1. **Enable Development Mode**:  
   - Either via the **Development Mode Toggle** workflow or by running `Set_Development_Mode.ps1`.

2. **Implement and Test**:
   - Use the main CI workflow (or a local script) to verify your changes pass.
   - Keep Dev Mode enabled if needed for debugging; disable it if you want a “clean” environment.

3. **Open a Pull Request** and **Label** it:
   - Assign `major`, `minor`, or `patch` to control the version bump.
   - The CI validates your code without creating tags or releases.

4. **Merge the PR** into `main` (or the applicable `releases/<YYYY>Q<N>` branch for a patch):
     - The **Build VI Package** workflow builds and uploads the `.vip` artifact.
     - **Inside** that `.vip`, the **“Company Name”** and **“Author Name (Person or Company)”** fields are filled automatically using `github.repository_owner` and `github.event.repository.name`. Modify the “Generate display information JSON” step in `.github/workflows/ci-composite.yml` to override them.

5. **Disable Development Mode**:  
   - Switch LabVIEW back to normal mode.  
   - Optionally install the resulting `.vip` to confirm your new feature in a production-like environment.

---

## Final Notes

- **Artifact Storage**: The `.vip` file is accessible under the Actions run summary (click “Artifacts”).  
- **Version Enforcement**: Pull requests without a version label default to `patch`; you can enforce labeling with an optional “Label Enforcer” step if desired.  
- **Branding**: To highlight the **organization** or **repository** behind a particular build, simply pass `-CompanyName` and `-AuthorName` (or similar parameters) into the `Build.ps1` script. This metadata flows into the final **Display Information** of the Icon Editor’s VI Package.

## Portability

**What is portable**
- Any Windows self-hosted runner with LabVIEW 2021 (21.0), PowerShell 7+, and Git installed.
- Forks or orgs that keep the canonical runner label `self-hosted-windows-lv`.
- Environments where the GitHub Actions API is restricted (runner contract fallback is local).

**What is not portable**
- Non-Windows runners (LabVIEW + g-cli requires Windows).
- Hosts without LabVIEW 2021 installed for both 32-bit and 64-bit.

**Operational caveats**
- Service restart requires admin rights on the host machine.
- If runner paths differ, use `Tooling/Setup-Runner.ps1` to generate the contract and set paths.

By adopting these workflows—**Development Mode Toggle** and **Build VI Package**—you can maintain a **streamlined, consistent** CI/CD process for the Icon Editor while customizing the VI Package with your own **unique** or **fork-specific** branding.
