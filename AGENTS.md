# Local Agent Instructions

This repository uses LabVIEW, g-cli, and PowerShell tooling. Follow the steps below so the agent can run tests and local CI parity safely.

## Prerequisites
- Windows with PowerShell 7+ available as `pwsh`.
- `g-cli` available on PATH.
- LabVIEW 2021 (21.0) 32-bit and 64-bit installed.
- VIPM/VIPC installed (required for dependency application).

## Repo Setup
- Open a PowerShell terminal at the repo root.
- Confirm `g-cli` is available:
  - `g-cli --version`

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
- `ci-<jobhash>-<bitness>-<runid>-<attempt>`
- Some workflows insert an extra variant token (e.g. LabVIEW version) between `<jobhash>` and `<bitness>`.
- `jobhash` is the first 8 chars of the SHA1 of `GITHUB_JOB` (prevents collisions across jobs).
- `bitness` is `32` or `64`.
Example: `C:\dev\ci-D170BDEE-64-21534416929-1`

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
Run the local parity script that mirrors `ci-composite.yml`:
```
pwsh -NoProfile -File .\Tooling\Run-CICompositeLocal.ps1 `
  -LabVIEWVersion 2021 `
  -EnsureCleanState
```

Notes:
- Outputs go to `$WORKTREE_ROOT\artifacts\<runid>\ci-local` when guardrails are active (default for local runs).
- GitHub Actions disables artifact roots by default unless `LVIE_ENABLE_ARTIFACT_ROOT=1` or an explicit `-RunId`/`-ArtifactRoot` is passed.
- The script always runs both 64-bit and 32-bit steps for LabVIEW 2021 (21.0).
- The script handles Verify IE Paths, VIPC, missing-in-project, unit tests, PPL builds, and VIP build.
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
$command = 'pwsh -NoProfile -File .\Tooling\Run-CICompositeLocal.ps1 -LabVIEWVersion 2021 -EnsureCleanState'

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

## Proactive run loop (success = VI package produced)
When running locally, keep iterating until a `.vip` is produced. Do not kill background automation; wait if LabVIEW or g-cli is already running.

Success criteria:
- A new `.vip` exists under `builds\VI Package`. The local parity script copies the latest `.vip` into `builds\VI Package` after a successful VIP build.

Automated loop (PowerShell):
```
pwsh -NoProfile -File .\Tooling\Run-CICompositeLocal-Auto.ps1 `
  -LabVIEWVersion 2021 `
  -EnsureCleanState `
  -MaxAttempts 5
```

Notes:
- Logs to `TestResults\agent-logs` (see `auto-run-history.csv` plus parity logs).
- Timeouts grow on each failed attempt; caps are configurable in the script parameters.
- The script waits for existing `g-cli`/`LabVIEW` processes and never terminates them.
- By default, the loop creates a *new* worktree under the configured worktree root (`C:\dev` unless `LVIE_WORKTREE_ROOT` is set).
  - Naming: `<repo>-ci-parity-auto-<yyyyMMdd-HHmmss>`
  - This is intentional so each run uses a short path and prints `C:\dev\...` in logs (e.g. missing-in-project).
  - Old worktrees accumulate over time; see **Worktree cleanup** below.
- Set `-UseWorktree:$false` to run directly from the current repo path.

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
  -LabVIEWVersion 2021 `
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

