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

## Local CI Parity (recommended)
Run the local parity script that mirrors `ci-composite.yml`:
```
pwsh -NoProfile -File .\Tooling\Run-CICompositeLocal.ps1 `
  -LabVIEWVersion 2021 `
  -EnsureCleanState
```

Notes:
- Outputs go to `TestResults\ci-local`.
- The script always runs both 64-bit and 32-bit steps for LabVIEW 2021 (21.0).
- The script handles Verify IE Paths, VIPC, missing-in-project, unit tests, PPL builds, and VIP build.
- If LabVIEW or g-cli is already running, the script waits for them to exit before starting.
- You can skip steps with switches like `-SkipBuildVip` or `-SkipUnitTests`.

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

Suggested loop (PowerShell):
```
$logRoot = Join-Path $PWD 'TestResults\agent-logs'
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
$csv = Join-Path $logRoot 'run-history.csv'
$maxAttempts = 5
$connectTimeout = 180000
$processTimeout = 300000

function Get-LatestVip {
  $buildsDir = Join-Path $PWD 'builds\VI Package'
  if (-not (Test-Path -Path $buildsDir)) {
    return $null
  }

  Get-ChildItem -Path $buildsDir -Recurse -Filter *.vip -ErrorAction SilentlyContinue |
    Sort-Object -Property LastWriteTime -Descending |
    Select-Object -First 1
}

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
  $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $logFile = Join-Path $logRoot "ci-local-$timestamp.log"

  $running = Get-Process -Name g-cli,LabVIEW -ErrorAction SilentlyContinue
  if ($running) {
    " $timestamp,wait,processes_running,$($running.Count)" | Add-Content -Path $csv
    Start-Sleep -Seconds 30
    continue
  }

  $command = "pwsh -NoProfile -File .\\Tooling\\Run-CICompositeLocal.ps1 -LabVIEWVersion 2021 -EnsureCleanState -ConnectTimeoutMs $connectTimeout -ProcessTimeoutMs $processTimeout"

  Start-Transcript -Path $logFile -Append | Out-Null
  try {
    $duration = Measure-Command { Invoke-Expression $command }
    $status = if ($LASTEXITCODE -eq 0) { 'success' } else { "exit:$LASTEXITCODE" }
  } finally {
    Stop-Transcript | Out-Null
  }

  $elapsedSec = [Math]::Round($duration.TotalSeconds, 2)
  "{0},{1},{2},{3}" -f $timestamp, $status, $elapsedSec, $command | Add-Content -Path $csv

  $vip = Get-LatestVip
  if ($vip) {
    " $timestamp,success,vip,$($vip.FullName)" | Add-Content -Path $csv
    break
  }

  # Backoff if needed for local tuning
  $connectTimeout = [Math]::Min([int]($connectTimeout * 1.5), 600000)
  $processTimeout = [Math]::Min([int]($processTimeout * 1.5), 1200000)
}
```

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
