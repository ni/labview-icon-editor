# Local Agent Instructions

This repository uses LabVIEW, g-cli, and PowerShell tooling. Follow the steps below so the agent can run tests and local CI parity safely.

## Prerequisites
- Windows with PowerShell 7+ available as `pwsh`.
- `g-cli` available on PATH.
- LabVIEW 2021 (21.0) 32-bit and 64-bit installed.
- VIPM/VIPC installed (required for dependency application).
- Python 3 with `pylavi` installed so `vi_validate` is on PATH.

## Repo Setup
- Open a PowerShell terminal at the repo root.
- Confirm `g-cli` is available:
  - `g-cli --version`
- Resolve the current repository for `gh` commands:
  - `$repo = pwsh -NoProfile -File .\Tooling\Resolve-GitHubRepo.ps1`
  - `GH_REPO` is an optional override and takes precedence when set.
- If you need to open a PR from the current branch, use `gh`:
  - Default template: `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE.md`
  - Draft PR: `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE.md --draft`

## Repo-Agnostic Issue/Discussion Policy
- Issue and discussion actions operate on the repository currently being worked in.
- Use this command before issue/PR/workflow operations:
  - `$repo = pwsh -NoProfile -File .\Tooling\Resolve-GitHubRepo.ps1`
- Examples:
  - Create issue: `gh issue create --repo $repo --template "Bug Report"`
  - Create PR: `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE.md`
  - List issues: `gh issue list --repo $repo --limit 50`
  - Run workflow: `gh workflow run labels-sync.yml --repo $repo -f dry_run=true -f include_aliases=true`

## GitHub Templates and Labels
- Use issue templates with `gh` (preferred):
  - Bug report: `gh issue create --repo $repo --template "Bug Report"`
  - Feature request: `gh issue create --repo $repo --template "Feature request"`
- Use PR templates with `gh`:
  - Generic: `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE.md`
  - Bug fix: `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE/bug_fix.md`
  - Feature addition: `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE/feature_request.md`
  - Documentation update: `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE/documentation.md`
  - Infrastructure change: `gh pr create --repo $repo --base develop -T .github/PULL_REQUEST_TEMPLATE/infrastructure_change.md`
- Web fallback links:
  - Resolve repository URL: `$repoUrl = gh repo view $repo --json url --jq .url`
  - Issues: `"$repoUrl/issues/new/choose"`
  - Bug form: `"$repoUrl/issues/new?template=bug_report.yml"`
  - Feature form: `"$repoUrl/issues/new?template=feature_request.yml"`
  - PR page: `"$repoUrl/compare"`

Label policy:
- Canonical release labels:
  - `Version Increment: Major`
  - `Version Increment: Minor`
  - `Version Increment: Patch`
- Canonical issue-type labels:
  - `Issue group: Bug`
  - `Type: Enhancement`
- Compatibility aliases are accepted for two release cycles:
  - `major` -> `Version Increment: Major`
  - `minor` -> `Version Increment: Minor`
  - `patch` -> `Version Increment: Patch`
  - `bug` -> `Issue group: Bug`
  - `enhancement` -> `Type: Enhancement`
- Sync labels from contract (manual workflow):
  - Dry run: `gh workflow run labels-sync.yml --repo $repo -f dry_run=true -f include_aliases=true`
  - Apply: `gh workflow run labels-sync.yml --repo $repo -f dry_run=false -f include_aliases=true`

Stale issue policy:
- Workflow: `.github/workflows/stale-issues.yml`
- Scope: issues only (PR stale automation is disabled)
- Thresholds: mark stale at 45 days, auto-close at 14 additional inactive days
- Exempt labels:
  - `Workflow: Actively discussing`
  - `Workflow: NI Approves`
  - `Workflow: Requires R&D clarification`
  - `Workflow: Open to contribution`
  - `Issue group: Added to agenda`
  - `good first issue`
- Manual stale candidate query:
  - ```
    $cutoff = (Get-Date).AddDays(-45).ToString('yyyy-MM-dd')
    $query = @(
      "updated:<$cutoff"
      '-label:"Workflow: Actively discussing"'
      '-label:"Workflow: NI Approves"'
      '-label:"Workflow: Requires R&D clarification"'
      '-label:"Workflow: Open to contribution"'
      '-label:"Issue group: Added to agenda"'
      '-label:"good first issue"'
    ) -join ' '
    gh issue list --repo $repo --state open --search $query --limit 200
    ```

Metadata quick-checks:
- Unlabeled PRs (no normalized release label):
  - `gh pr list --repo $repo --state open --search "-label:'Version Increment: Major' -label:'Version Increment: Minor' -label:'Version Increment: Patch' -label:major -label:minor -label:patch"`
- Unlabeled issues:
  - `gh issue list --repo $repo --state open --search "no:label" --limit 200`
- Alias-only issue types:
  - ```
    $items = gh issue list --repo $repo --state open --limit 200 --json number,title,labels | ConvertFrom-Json
    $items | Where-Object {
      ($_.labels.name -contains 'enhancement' -or $_.labels.name -contains 'bug') -and
      -not ($_.labels.name -contains 'Type: Enhancement' -or $_.labels.name -contains 'Issue group: Bug')
    } | Select-Object number,title,@{Name='labels';Expression={ $_.labels.name -join ', ' }}
    ```

## CI Debt Training (Issue #74)
- Install/update the pinned Codex skill layer:
  - `pwsh -NoProfile -File .\Tooling\Install-CodexSkillLayer.ps1`
- Codex skill layer preflight (required; hard-fails when missing or invalid):
  - `pwsh -NoProfile -File .\Tooling\Assert-CodexSkillLayer.ps1`
- Analyze a specific CI run:
  - `pwsh -NoProfile -File .\Tooling\Invoke-CiDebtAnalysis.ps1 -Repo $repo -RunId 21840801109`
- Use fixture-only local validation (no live API calls):
  - `pwsh -NoProfile -File .\Tooling\Invoke-CiDebtAnalysis.ps1 -Repo $repo -RunId 21840801109 -FixturePath .\Tooling\tests\fixtures\ci-debt\run-21840801109.json`
- Enforce unknown-signature failures during training:
  - `pwsh -NoProfile -File .\Tooling\Invoke-CiDebtAnalysis.ps1 -Repo $repo -RunId 21840801109 -FailOnUnknown`
- Run training workflow manually:
  - `gh workflow run ci-debt-train.yml --repo $repo -f run_id=21840801109 -f issue_number=74 -f post_comment=true`
- Run policy gate manually:
  - `gh workflow run ci-debt-policy-gate.yml --repo $repo -f mode=warn`
- Local policy check:
  - `pwsh -NoProfile -File .\Tooling\Test-CiDebtPolicyGate.ps1 -Mode warn`

## pylavi / vi_validate gate
- The local CI parity run includes a fast LabVIEW file validation step powered by `pylavi` (`vi_validate`) and runs **before** any g-cli/LabVIEW work.
- The gate uses `.lvversion` as the canonical LabVIEW version and passes it to `vi_validate --eq` automatically.
- Absolute-path focus: optionally set `LVIE_PYLAVI_ABSOLUTE_PATH_ROOTS` (semicolon-delimited) to flag specific roots without committing sensitive paths. CI redacts configured roots in logs and the uploaded pylavi log artifact.
- CI also uploads a redacted top-offenders report artifact per pylavi run (`pylavi-validate-offenders-<label>`) and prints the top offenders table in the step summary.
- Local runs write a redacted offenders report to `TestResults\agent-logs\pylavi-offenders.latest.json`. Use `Tooling\Get-PylaviOffenders.ps1` to summarize it.
- If the local report is missing, fetch the latest CI artifact instead: `pwsh -NoProfile -File .\Tooling\Fetch-PylaviOffenders.ps1 -Branch develop` or `pwsh -NoProfile -File .\Tooling\Get-PylaviOffenders.ps1 -FetchLatest`. Requires `GH_TOKEN`/`GITHUB_TOKEN` with `actions:read`.
- Deterministic: `Tooling\Get-PylaviOffenders.ps1 -Sha <commit>` to read `pylavi-offenders.<sha>.json`, or `-RunId <id> -FetchLatest` to pin a specific workflow run.
- Baseline/delta gating (runner-cli): set `LVIE_PYLAVI_BASELINE_PATH` to a redacted offenders report and optionally `LVIE_PYLAVI_FAIL_ON_DELTA=1` to fail on new offenders. Use `LVIE_PYLAVI_BASELINE_REQUIRED=1` to require the baseline file.
- Runner-cli-only toggle: set `LVIE_REQUIRE_RUNNER_CLI=1` to enforce runner-cli usage (no PowerShell fallback).
- Config files:
  - `Tooling/pylavi/vi-validate.yml` (strict scope; version injected at runtime).
  - `Tooling/pylavi/vi-validate-legacy.yml` (legacy scope; typically absolute-path checks only).
- CI report-only step uses the composite action: `.github/actions/pylavi-validate`.
- Install (user scope):
  - `py -m pip install --user pylavi`
- Verify install:
  - `vi_validate --help`
- If `vi_validate` is not found, ensure your Python Scripts folder is on PATH (typical: `%APPDATA%\Python\Python3x\Scripts`).
- Skip the gate if needed:
  - `pwsh -NoProfile -File .\Tooling\Invoke-WorktreeOrchestrator.ps1 -Run -RunArgs -SkipViValidate`
  - `pwsh -NoProfile -File .\Tooling\Run-CICompositeLocal-Auto.ps1 -SkipViValidate`
- Smoke run (pylavi only):
  - `pwsh -NoProfile -File .\Tooling\Invoke-WorktreeOrchestrator.ps1 -Run -RunArgs -ViValidateOnly`
  - `pwsh -NoProfile -File .\Tooling\Run-ViValidate.ps1`
  - Profiles: `-ViValidateProfile strict|legacy|both` (optional `-ViValidateReportOnly`, `-ViValidateSkipVersionGate`)

## Worktree root (short paths)
Use a short path for worktrees to avoid Windows path-length issues. Default to `C:\dev` for local dev; for self-hosted runners, standardize under the runner directory (example: `C:\actions-runner\_work\lvie\w`).

Override:
- Set `LVIE_WORKTREE_ROOT` to change the default worktree root.
  - Runner contract helper: `pwsh -NoProfile -File .\Tooling\Setup-Runner.ps1 -RunnerRoot C:\actions-runner -Scope Machine` (creates `<runner-root>\_work\lvie\w`, writes `<runner-root>\_work\lvie\runner-contract.json`, and sets env vars).

Preflight requirement:
- If the chosen worktree root does not exist, ask the user to create it before proceeding.
- For CI/self-hosted runners, ensure the directory is pre-created; fail fast with a clear message if missing.
 - Local parity scripts hard-fail if `RepoRoot` is not under the worktree root; set `LVIE_WORKTREE_ROOT` or run from a worktree path.

Example preflight (PowerShell):
```
$worktreeRoot = $env:LVIE_WORKTREE_ROOT
if ([string]::IsNullOrWhiteSpace($worktreeRoot)) { $worktreeRoot = 'C:\dev' }
if (-not (Test-Path $worktreeRoot)) {
  throw "Worktree root '$worktreeRoot' does not exist. Create it or set LVIE_WORKTREE_ROOT."
}
```

Worktree creation helper (recommended):
```
pwsh -NoProfile -File .\Tooling\New-CIWorktree.ps1 `
  -Ref HEAD
```

Notes:
- The helper enforces the worktree root and fails fast if it is missing.
- Use `-Name` to label the worktree directory.
- Use `-WorktreeRoot` (or `LVIE_WORKTREE_ROOT`) to override the default.

## CI worktree naming (ci-composite.yml)
CI jobs create short-path worktrees under `LVIE_WORKTREE_ROOT` with a deterministic name:
- `ci-<workflowhash>-<jobhash>-<bitness>-<runid>-<attempt>`
- Some workflows insert an extra variant token (e.g. LabVIEW version) between `<jobhash>` and `<bitness>`.
- `workflowhash` is the first 8 chars of the SHA1 of workflow identity (`GITHUB_WORKFLOW_REF`, fallback `GITHUB_WORKFLOW`).
- `jobhash` is the first 8 chars of the SHA1 of `GITHUB_JOB` (prevents collisions across jobs).
- `bitness` is `32` or `64`.
Example: `C:\dev\ci-2A4C7D91-D170BDEE-64-21534416929-1`

Troubleshooting:
- CI worktree setup automatically runs `git worktree prune` and clears stale registrations for the target path before creation to avoid `missing but already registered worktree` failures.

The workflow exports:
- `REPO_ROOT` → worktree path (authoritative for all scripts)
- `PROJECT_PATH` → `$REPO_ROOT\lv_icon_editor.lvproj`
- `LABVIEW_VERSION_YEAR` / `LABVIEW_MINOR_REVISION` → derived from `.lvversion` (e.g., `21.0` → `2021` and minor `0`)

Note: CI reads `.lvversion` from `REPO_ROOT` as the canonical LabVIEW version for runs.

Helper used by CI:
```
pwsh -NoProfile -File .\Tooling\New-CIWorktreeForJob.ps1 -Bitness 64
```

## CI concurrency (self-hosted LabVIEW runners)
LabVIEW workflows are serialized on the shared self-hosted runner label to avoid concurrent g-cli/LabVIEW conflicts.

Notes:
- Workflows share a concurrency group keyed by repository + runner label (e.g., `labview-<repo>-self-hosted-windows-lv-ie`).
- Missing-in-project is inlined in `ci-composite.yml` to avoid reusable workflow skips; the standalone workflow is manual only.
- Self-hosted LabVIEW jobs acquire a runner lock at `<lock_root>\labview-runner.lock` via `Tooling\RunnerLock.ps1`. The lock auto-expires stale entries (lease + optional GitHub run status check) and logs owner metadata. Env overrides: `LVIE_LOCK_ROOT`, `LVIE_RUNNER_LOCK_TIMEOUT_SECONDS`, `LVIE_RUNNER_LOCK_LEASE_SECONDS`, `LVIE_RUNNER_LOCK_STALE_SECONDS`, `LVIE_RUNNER_LOCK_GITHUB_CHECK`, `LVIE_RUNNER_LOCK_GITHUB_MIN_AGE_SECONDS`, `LVIE_RUNNER_LOCK_GITHUB_CHECK_INTERVAL_SECONDS`.

## Local CI Parity (recommended)
Run the local parity script that mirrors `ci-composite.yml` (preferred entrypoint is the worktree orchestrator):
```
pwsh -NoProfile -File .\Tooling\Invoke-WorktreeOrchestrator.ps1 `
  -Run `
  -RunArgs
```

Notes:
- Outputs go to `$WORKTREE_ROOT\artifacts\<runid>\ci-local` when guardrails are active (default for local runs).
- GitHub Actions disables artifact roots by default unless `LVIE_ENABLE_ARTIFACT_ROOT=1` or an explicit `-RunId`/`-ArtifactRoot` is passed.
- The script always runs both 64-bit and 32-bit steps for LabVIEW 2021 (21.0).
- The script handles Verify IE Paths, VIPC audit, unit tests, PPL builds, and VIP build.
- VIPC default behavior is audit-first (`-VipcMode audit`); optional diagnostics are available via `-VipcMode apply-info` or strict apply via `-VipcMode apply-enforce`.
- The script runs `vi_validate` (pylavi) and uses `.lvversion` as the canonical LabVIEW version. Skip with `-SkipViValidate`.
- If you pass `-LabVIEWVersion`, it must match `.lvversion` or the run will fail fast.
- If LabVIEW or g-cli is already running, the script waits for them to exit before starting.
- You can skip steps with switches like `-SkipBuildVip` or `-SkipUnitTests`.
- VIP builds flow through `Tooling\Invoke-VipBuild.ps1`, which emits `builds\status\vip-build.json` and respects `LVIE_VIPM_TIMEOUT_SECONDS`, `LVIE_VIPM_MAX_ATTEMPTS`, and `LVIE_VIPM_RETRY_DELAY_SECONDS`.

## Adaptive timeouts and continuous troubleshooting
Use fixed timeouts for deterministic CI runs. Use adaptive timeouts only for local/manual runs while tuning.

**CI guidance (deterministic):**
- Set conservative fixed values and keep them stable across runs.
- Prefer failing on the status-file contract over wall-clock timing when possible.

**Local guidance (adaptive):**
There are no fixed timeout defaults. Use the following protocol so timeouts evolve based on actual runtime:

1. Log every command, capture duration, and append a CSV row.
2. If a timeout occurs, retry once with larger timeouts (e.g. 1.5x or 2x).
3. Use the last successful durations to set the next run's timeouts:
   - `ConnectTimeoutMs = max(120000, last_connect_ms * 2)`
   - `ProcessTimeoutMs = max(300000, last_process_ms * 2)`

Suggested logging wrapper (PowerShell):
```
$logRoot = Join-Path $PWD 'TestResults\agent-logs'
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $logRoot "run-$timestamp.log"
$csv = Join-Path $logRoot 'run-history.csv'
$command = 'pwsh -NoProfile -File .\Tooling\Invoke-WorktreeOrchestrator.ps1 -Run -RunArgs'

$start = Get-Date
Start-Transcript -Path $logFile -Append | Out-Null
try {
  $duration = Measure-Command { Invoke-Expression $command }
  $status = if ($LASTEXITCODE -eq 0) { 'success' } else { "exit:$LASTEXITCODE" }
} finally {
  Stop-Transcript | Out-Null
  $elapsedSec = [Math]::Round($duration.TotalSeconds, 2)
  "{0},{1},{2},{3}" -f $timestamp, $status, $elapsedSec, $command | Add-Content -Path $csv
}
```

## Proactive belt-and-suspenders loop (standard)
Use the canonical wrapper to run local parity first, then remote CI for the exact same SHA, then automatic CI debt analysis on remote failure.

Standard command:
```
pwsh -NoProfile -File .\Tooling\Invoke-BeltAndSuspendersCI.ps1 `
  -Sha HEAD
```

What it does:
- Runs `Run-CICompositeLocal-Auto.ps1` in standardized local mode (`-SuccessTarget ppl -SkipVerifyIEPaths -SkipMissingInProject -SkipBuildVip`) unless `-SkipLocalParity` is set.
- Dispatches `CI Pipeline (Composite)` for the exact target SHA via a temp `ci-run/*` branch.
- Waits for completion and runs `Tooling\Invoke-CiDebtAnalysis.ps1` automatically on non-success.

Useful switches:
- `-SkipLocalParity` for remote-only verification.
- `-FullLocalParity` to override the standardized local mode and require full VIP-producing parity.
- `-DispatchCleanupRemote` to delete the temporary dispatch branch after completion.
- `-CiDebtFailOnUnknown` to hard-fail on unknown CI debt signatures.
- `-MaxLocalAttempts <n>` to tune local parity retries.

Local-only fallback:
```
pwsh -NoProfile -File .\Tooling\Run-CICompositeLocal-Auto.ps1 `
  -MaxAttempts 5
```

Notes:
- Logs/status are written under `TestResults\agent-logs`.
- The local loop waits for existing `g-cli`/`LabVIEW` processes and never terminates them.
- By default, local parity auto-loop creates a *new* short-path worktree under the configured worktree root (`C:\dev` unless `LVIE_WORKTREE_ROOT` is set).
  - Naming: `<repo>-ci-parity-auto-<yyyyMMdd-HHmmss>`
  - Old worktrees accumulate over time; see **Worktree cleanup** below.
- Set `-LocalUseWorktree:$false` (wrapper) or `-UseWorktree:$false` (local-only script) to run directly from the current repo path.

## Worktree cleanup
To keep `C:\dev` tidy, remove old worktrees after you’re done with them.

List worktrees:
```
git worktree list
```

Remove a specific worktree directory:
```
git worktree remove C:\dev\<worktree-folder>
```

Prune stale worktree metadata (after deleting folders manually):
```
git worktree prune
```

## Run CI for a specific commit (workflow_dispatch)
Use the helper to target a specific commit without relying on PR pushes:
```
pwsh -NoProfile -File .\Tooling\Run-CICompositeForCommit.ps1 -Sha <commit>
```

Notes:
- The script creates a temporary branch under `ci-run/<shortsha>` and dispatches the workflow.
- Use `-CleanupRemote` if you want the temporary branch deleted after dispatch.

## Background automation safety
Some automation may be running in the background and must not be killed. Do not terminate `g-cli` or `LabVIEW` processes unless you have explicit confirmation it is safe.
- Before running a new step, record active processes:
  - `Get-Process -Name g-cli,LabVIEW -ErrorAction SilentlyContinue | Format-Table -AutoSize`
- If a process is already running, wait for it to finish or skip the new run and log the reason. Do not kill it.
- Only use `.github\actions\close-labview\Close_LabVIEW.ps1` when it will not interfere with background automation.

## Pester Integration Tests
Run the integration suite (includes dev-mode tests when enabled):
```
pwsh -NoProfile -File .\Test\Pester\Run-Pester.ps1 `
  -LabVIEWBitness both `
  -RunDevModeTests `
  -ConnectTimeoutMs 180000 `
  -ProcessTimeoutMs 300000
```

Notes:
- Dev-mode tests toggle LabVIEW dev mode and require `RUN_DEV_MODE_TESTS`.
- If LabVIEW is not installed for a bitness, tests will skip that bitness.

## Troubleshooting
- If `g-cli` cannot connect, increase `-ConnectTimeoutMs` and `-ProcessTimeoutMs`.
- If a run hangs, close LabVIEW and re-run the step:
  - `.github\actions\close-labview\Close_LabVIEW.ps1`
- Release note generation can log `git describe` errors in shallow or tagless repos; VIP builds may still complete, but fetch tags if you need accurate version strings.
- If `vi_validate` is missing, confirm `py -m pip show pylavi` and ensure the Python Scripts directory is on PATH.
- If Windows container parity fails with `ScriptRequiresUnmatchedPSVersion`, run `pwsh -NoProfile -File .\Tooling\Test-PathContract.ps1 -WriteSummary` and remove any file-scope `#Requires -Version` from `Tooling\support\PathContract.ps1`.

