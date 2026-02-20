# Local CI/CD Workflows

**Last updated:** 2026-02-20

Quick link: `.github/workflows/runner-cli.yml` (Runner CLI consolidated workflow).

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
- LabVIEW version declared in `.lvversion` (currently `20.0`) installed for 32-bit and 64-bit lanes as needed by your workflow profile
- PowerShell 7+
- Git for Windows

### Issue 91 Reconciliation Note (2026-02-11)

- Reconciled branch purpose: forward-port the `456-2026-migration` work onto the current CI/tooling baseline while removing CI selector/dev-mode coupling.
- CI behavior change: `ci.yml`, `ci.yml`, and container parity CI scripts no longer perform automatic selector mode set/unset or development-mode toggles.
- Windows container parity guardrail: `Tooling/Test-PathContract.ps1` now runs before Windows container parity execution to enforce `Tooling/support/PathContract.ps1` compatibility with Windows PowerShell 5.1 and prevent `ScriptRequiresUnmatchedPSVersion`.
- Manual development mode support remains available through [`development-mode-toggle.yml`](../.github/workflows/development-mode-toggle.yml).

### Solo Maintainer Operating Note (2026-02-19)

- Repository operation is optimized for a single maintainer with PR-gated integration and auto publish on eligible `develop` merged-PR commits.
- Canonical release/publication behavior is defined by [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) and this document.
- LLM runbook: [`docs/ci/llm-operator-runbook.md`](ci/llm-operator-runbook.md)

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
   Use the main CI workflow (`ci.yml`) to confirm your environment is valid.
   - `ci.yml` is the canonical publish-capable workflow. It triggers on pushes to or pull requests targeting configured branches and supports manual `workflow_dispatch` runs.
     - Typically run with Dev Mode **disabled** unless you’re testing dev features specifically.
     - Concurrency is isolated by repository, runner label, event name, and ref.
     - Pull request runs auto-cancel earlier runs for the same PR ref.
     - Push and `workflow_dispatch` runs are isolated by event/ref and are not canceled by pull request updates.
   - `ci.yml` (`CI Pipeline`) is publish-capable on eligible events; PR branch validation now flows through `pull_request` events (feature/hotfix branch pushes do not trigger this workflow).

5. **Build VI Package**
   - Produces `.vip` artifacts automatically using the Windows/self-hosted `build-vip` job in `ci.yml` for `full` and `pr-fast` profiles.
   - The `release-priority` profile (`workflow_dispatch` with `force_gcli_lunit=true`) intentionally skips `build-vip` and publishes prereleases from container packed-library assets.
   - By default, the workflow populates the **“Company Name”** with `github.repository_owner` and the **“Author Name”** with `github.event.repository.name`, so each build is branded with your GitHub account and repository.
   - To use different branding, edit the **“Generate display information JSON”** step in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) and supply custom values for these fields.
   - Uses **label-based** version bumping (major/minor/patch) on pull requests.
   - Generates `Tooling/deployment/release_notes.md` summarizing recent commits and embedding `Minimum supported LabVIEW version: <raw .lvversion>`.

6. **Disable Dev Mode** (optional)  
   Reverts your environment to normal LabVIEW settings, removing local overrides.

> [!NOTE]
> The workflow automatically brands the VI Package using the repository owner (`github.repository_owner`) and repository name (`github.event.repository.name`). Modify the “Generate display information JSON” step in `.github/workflows/ci.yml` if you need different values.

### Release Publication Policy

This document is the canonical source for release/publication policy.

- Normative contract: [VI Package Pre-Release Requirements](vip-prerelease-requirements.md).
- Merge strategy contract: pull requests intended to drive prerelease publication to `develop` must use merge commits (`--merge`), not squash or rebase.
- Publish contract: prerelease publication is automatic for eligible merged-PR merge commits on `develop`.
- Auto relay workflow: [`.github/workflows/prerelease-auto-dispatch.yml`](../.github/workflows/prerelease-auto-dispatch.yml) listens for successful `CI Pipeline` `push` runs on `develop`, re-validates merge-commit + merged-PR eligibility, then dispatches strict SHA-pinned publish intent through `ci.yml` with `release-priority`.
- Manual fallback: `workflow_dispatch` remains available for deterministic backfill when auto relay is not sufficient.
- Execution profiles (`prerelease-context` output `ci_profile`):
  - `release-priority`: `workflow_dispatch` with `force_gcli_lunit=true`; skips most self-hosted heavy jobs (`Verify IE Paths`, `VI Analyzer`, smoke, unit-tests, `build-ppl-x64`, `build-ppl-x86`, `build-vip`) and targets <= 25 minutes.
  - `pr-fast`: `pull_request`; keeps validation coverage but uses 64-bit-only matrices for smoke/unit-tests, targeting <= 35 minutes.
  - `full`: default for `push` and `workflow_dispatch` without `force_gcli_lunit=true`; preserves full publish-eligible flow.
- Verify IE Paths rollout toggle: `LVIE_VERIFY_IEPATHS_ENFORCE` defaults to `0` (canary/non-blocking). Set to `1` to enforce failures.
- Profile routing note: `force_gcli_lunit=true` is now used only to select the `release-priority` profile; unit-test execution is standardized on direct `g-cli lunit` in workflows that run tests.
- Release-priority guardrail: `workflow_dispatch` publish intent in `release-priority` requires a successful `full` profile run on `develop` completed within the previous 24 hours.
- Asset contract: published prereleases in `full`/`pr-fast` attach `.vip`, release notes, `labviewcli-logs`, `vip-build-status`, Linux and Windows container packed libraries, and `codex-skill-layer`; `release-priority` publishes Linux and Windows container packed libraries plus `codex-skill-layer`.
- Immutable publish contract: if the tag already exists, publish verifies required assets and reports `publish_status=already-published`; existing release metadata/assets are not patched or clobbered.
- Branch trigger reality for `ci.yml`: `push` runs on `main`, `develop`, and `release/*`; `pull_request` runs on `main`, `develop`, `release/*`, `feature/*`, and `hotfix/*`; `workflow_dispatch` is supported.
- PR branch policy: `feature/*` and `hotfix/*` branch pushes no longer trigger `ci.yml`; PR synchronization is the single CI path for those branches.
- Runner CLI trigger reality for `runner-cli.yml`: `push` runs on `main`, `develop`, and `release/*`; `pull_request` runs on `main` and `develop` when path filters match; `workflow_dispatch` is supported.

#### Deterministic Manual Backfill Procedure (Fallback)

Use this procedure when you need to replay publication for a specific merged `develop` SHA, or when auto relay was intentionally bypassed.

1. Run the deterministic publish helper:
   ```powershell
   pwsh -NoProfile -File .\Tooling\Invoke-DeterministicPrereleasePublish.ps1
   ```
2. Optional explicit SHA:
   ```powershell
   pwsh -NoProfile -File .\Tooling\Invoke-DeterministicPrereleasePublish.ps1 `
     -Sha <merged-develop-merge-sha> `
     -Wait
   ```
3. Manual fallback (if needed): create a temporary `ci-run` ref and dispatch strict publish intent against that ref:
   ```powershell
   $repo = pwsh -NoProfile -File .\Tooling\Resolve-GitHubRepo.ps1
   $sha = (git rev-parse HEAD).Trim()
   $shortSha = $sha.Substring(0,8)
   git push origin "${sha}:refs/heads/ci-run/$shortSha"
   gh workflow run "CI Pipeline" --repo $repo --ref "ci-run/$shortSha" `
     -f publish_prerelease=true `
     -f expected_sha=$sha `
     -f strict_sha=true
   ```

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
   - Uses `runner-cli version-gate` when available to resolve `.lvversion` (falls back to PowerShell).

2. **[Build VI Package](ci/actions/build-vi-package.md)**
   - **Automatically** versions your code based on PR labels (`major`, `minor`, `patch`).
     Direct pushes retain the previous version and increment only the build number.
   - Uses a **build counter** to ensure each artifact is uniquely numbered (e.g., `v1.2.3-build4`).
   - **Fork-Friendly**: Runs in forks without requiring extra signing keys.
   - Produces the `.vip` file via a PowerShell script (e.g., `Build.ps1`).
   - By default, “Company Name” and “Author Name” in the generated `.vip` come from `github.repository_owner` and `github.event.repository.name`. Update the “Generate display information JSON” step in [`ci.yml`](../.github/workflows/ci.yml) if you need custom values.
   - Uploads the `.vip` artifact to GitHub’s build artifacts.

3. **Runner CLI**
   - [`runner-cli.yml`](../.github/workflows/runner-cli.yml) is the single source of truth for runner-cli build/test paths.
   - It builds/tests the .NET CLI, publishes multi-RID artifacts on pushes, runs cross-platform smoke tests, and validates pylavi inside the Linux Docker image.
   - `ci.yml` still uses `runner-cli-reusable.yml` as an internal helper to publish a Linux artifact for version-gate usage; `runner-audit.yml` downloads the latest artifact when available.

4. **Headless Self-Hosted PPL Parity**
   - [`headless-self-hosted-parity.yml`](../.github/workflows/headless-self-hosted-parity.yml) validates the local/self-hosted headless PPL path with container-aligned pre-steps:
     - staged `MassCompile`,
     - source synchronization into LabVIEW install paths,
     - `ExecuteBuildSpec`.
   - Fail-fast preflight gate:
     - runs `Tooling/Assert-LabVIEWVersion.ps1 -EnforceProjectLvVersion` before parity execution,
     - requires `lv_icon_editor.lvproj` root `LVVersion` to match `.lvversion`,
     - requires `Split-Path -Parent $PROJECT_PATH` to equal `REPO_ROOT`.
   - Trigger policy:
     - manual `workflow_dispatch` for explicit validation,
     - `push` to `develop` for observability.
   - Rollout status: non-blocking diagnostic lane (not wired into publish required-job gates yet).
   - Artifacts: LabVIEWCLI logs, agent logs, build status, and `lv_icon_x64.lvlibp` when produced.

5. **Prerelease Auto Dispatch**
   - [`.github/workflows/prerelease-auto-dispatch.yml`](../.github/workflows/prerelease-auto-dispatch.yml) reacts to successful `CI Pipeline` `push` runs on `develop`.
   - It re-checks merged-PR merge-commit eligibility for `github.event.workflow_run.head_sha`.
   - When eligible, it dispatches `Tooling/Invoke-DeterministicPrereleasePublish.ps1 -ReleasePriority` for unattended strict-SHA publication.

#### Jobs in CI workflow

The [`ci.yml`](../.github/workflows/ci.yml) pipeline breaks the build into several jobs:

- **pylavi-validate** – report-only LabVIEW file validation using `vi_validate` (strict + legacy profiles) with `.lvversion`-synced version gating and optional baseline/delta reporting.
- **VI Analyzer ownership note** – container VI Analyzer responsibilities remain merged into parity container lanes in [`labview-parity.yml`](../.github/workflows/labview-parity.yml): `Parity (Linux Container <.lvcontainer>)` (artifacts `vi-analyzer-reports-parity`, `vi-analyzer-status-parity`) and `Parity (Windows Container <resolved windows tag>)` (artifacts `vi-analyzer-reports-parity-windows`, `vi-analyzer-status-parity-windows`).
- **prerelease-context** – computes prerelease publish eligibility, reason, merged-PR bump override context, and the execution profile (`ci_profile`: `release-priority`, `pr-fast`, `full`).
- **changes** – checks out the repository and detects `.vipc` file changes for diagnostics/reporting in downstream jobs.
- **apply-deps-64 / apply-deps-32** – run VIPC audit (`Assert-VipcApplied`) per bitness lane on bitness-addressable runner labels (`LVIE_RUNNER_LABEL_64` / `LVIE_RUNNER_LABEL_32`, with fallback to `LVIE_RUNNER_LABEL`), then optionally run informational VIPC apply diagnostics when manually dispatched with `vipc_apply_info=true`.
- **vi-analyzer** – runs `Tooling/Run-ViAnalyzer.ps1` on self-hosted 64-bit and 32-bit lanes after VIPC application for `full`/`pr-fast`; publishes per-lane `vi-analyzer-reports-*` and `vi-analyzer-status-*` artifacts.
- **verify-iepaths** – runs Verify IE Paths on self-hosted 64-bit and 32-bit lanes before source tests for `full`/`pr-fast`; defaults each lane to a LabVIEW-year + bitness label derived from `.lvversion` (`self-hosted-windows-lv<year>x64` / `self-hosted-windows-lv<year>x86`) with `LVIE_RUNNER_LABEL_64` / `LVIE_RUNNER_LABEL_32` override support; proactively closes stale LabVIEW sessions before the gate, emits status/evidence artifacts, and supports canary vs enforcing mode through `LVIE_VERIFY_IEPATHS_ENFORCE`.
- **version** – computes the semantic version and build number using commit count and PR labels.
- **unit-tests** – runs LabVIEW unit tests on Windows for the `.lvversion` target (currently `20.0` in this repository) after dependency application. Canonical execution is `runner-cli lunit run` (g-cli backend); parse/summary validation is parse-only via `runner-cli lunit validate` (`RunUnitTests.ps1 -SkipGcli`). Runs both 64-bit and 32-bit in `full` and `pr-fast`, and is skipped in `release-priority`.
  - Runtime compatibility mapping is execution-year only: source `.lvversion` year `2020` executes tests on year `2026`, while `.lvversion` remains the source contract.
  - Each matrix job appends a short `GITHUB_STEP_SUMMARY` line stating the fixed executor (`g-cli`).
- **build-ppl-x86 / build-ppl-x64** – separate self-hosted jobs that build 32-bit and 64-bit packed libraries through `runner-cli ppl build`, then rename each library artifact with explicit bitness.
  - Runtime compatibility mapping mirrors source-test behavior: source `.lvversion` year `2020` maps to execution year `2026` for runtime operations, while source version validation remains `.lvversion`-strict.
- **build-ppl-linux-container** – builds the Linux container packed library (`lv_icon.lvlibp`) via `runner-cli parity context/run` for publish-eligible runs and emits a versioned artifact for prerelease attachment.
- **build-ppl-windows-container** – builds the Windows container packed library (`lv_icon.lvlibp`) via `runner-cli parity context/run` for publish-eligible runs and emits a versioned artifact for prerelease attachment.
- **codex-skill-layer-asset** – downloads the pinned Codex skill-layer installer asset (`lvie-codex-skill-layer-installer.exe`), validates SHA256, performs silent install into a temp directory, verifies required files + `0BSD` manifest license, and publishes artifact `codex-skill-layer` for prerelease attachment.
- **build-vip** – Windows/self-hosted VI Package packaging path. This job requires both PPL artifacts (`lv_icon_x86.lvlibp`, `lv_icon_x64.lvlibp`) and runs for `full`/`pr-fast`; it is intentionally skipped in `release-priority`.
  - Runtime compatibility mapping is also execution-year only (`2020 -> 2026`) for VIPM/LabVIEW runtime actions, while `.lvversion` remains the source contract.
- **publish-gate** – evaluates profile-required prepublish job outcomes and blocks prerelease publication when required checks are missing or non-success.
- **publish-prerelease** – creates prereleases for eligible new tags, verifies required assets for existing immutable tags (`already-published`), attaches required assets for new tags, and emits `prerelease-publish-status`.
- **pipeline-contract** – validates required-job outcomes using profile-specific expectations so intentionally skipped jobs in `release-priority` do not fail the run.

Companion workflow note: [`runner-cli.yml`](../.github/workflows/runner-cli.yml) provides runner-cli-specific validation/publish signaling and is intentionally separate from prerelease asset publication.

Dedicated headless parity note: [`headless-self-hosted-parity.yml`](../.github/workflows/headless-self-hosted-parity.yml) is intentionally separate from publish-capable workflows during initial rollout, so regressions are visible without blocking release lanes.

Manual VIPC diagnostics example (non-blocking apply after audit):
`gh workflow run ci.yml --ref <branch> -f vipc_apply_info=true`

Windows self-hosted build jobs (`build-ppl-x86`, `build-ppl-x64`, and `build-vip`) run a `close-labview` step after their build actions finish but before any steps that rename files or upload artifacts, so it is not the final step.

#### Event matrix (VIP packaging)

| Event / profile | `build-vip` (Windows) |
| --- | --- |
| `pull_request` (`pr-fast`) | Runs (required) |
| `push` (`full`) | Runs (required) |
| `workflow_dispatch` (`full`, `force_gcli_lunit=false`) | Runs (required) |
| `workflow_dispatch` (`release-priority`, `force_gcli_lunit=true`) | Skipped intentionally |

Branch protection recommendation for solo mode: require the canonical synthetic context `CI Pipeline / CI Required / Lint+Contract` for pull requests.

*(The **Run Unit Tests** workflow has been consolidated into the main CI process.)*

---

### 3.3 Setting Up a Self-Hosted Runner

1. **Install Prerequisites**:
   - LabVIEW version declared in `.lvversion` (currently `20.0`) for 32-bit and 64-bit lanes as required
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
   - Manually invoke `Tooling/Invoke-VipBuild.ps1` (preferred) to generate a `.vip`, or run the full `Run-CI.ps1` parity workflow.
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
   - The CI validates your code and produces versioned build artifacts.

4. **Merge the PR into your target integration branch with a merge commit**:
     - The **Build VI Package** workflow builds and uploads the `.vip` artifact.
     - Use merge commits only (`gh pr merge <pr-number> --merge --delete-branch`); do not use squash/rebase for prerelease-driving changes.
     - Merge-commit merges to `develop` publish automatically when eligible via `prerelease-auto-dispatch.yml`; use `Tooling/Invoke-DeterministicPrereleasePublish.ps1` only for deterministic fallback/backfill (`workflow_dispatch` with strict SHA inputs).
     - **Inside** that `.vip`, the **“Company Name”** and **“Author Name (Person or Company)”** fields are filled automatically using `github.repository_owner` and `github.event.repository.name`. Modify the “Generate display information JSON” step in `.github/workflows/ci.yml` to override them.

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
- Any Windows self-hosted runner with `.lvversion`-compatible LabVIEW installs, PowerShell 7+, and Git installed.
- Forks or orgs that keep the canonical runner label `self-hosted-windows-lv`.
- Environments where the GitHub Actions API is restricted (runner contract fallback is local).

**What is not portable**
- Non-Windows runners (LabVIEW + g-cli requires Windows).
- Hosts without required `.lvversion`-compatible LabVIEW installs for the lanes they run.

**Operational caveats**
- Service restart requires admin rights on the host machine.
- If runner paths differ, use `Tooling/Setup-Runner.ps1` to generate the contract and set paths.

By adopting these workflows—**Development Mode Toggle** and **Build VI Package**—you can maintain a **streamlined, consistent** CI/CD process for the Icon Editor while customizing the VI Package with your own **unique** or **fork-specific** branding.

