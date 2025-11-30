#!/usr/bin/env pwsh
[CmdletBinding()]
param(
  [string] $XCliRepo = 'LabVIEW-Community-CI-CD/x-cli',
  [int] $XCliPr = 783,
  [string] $XSdkRepo = 'LabVIEW-Community-CI-CD/x-sdk',
  [string] $DelegatorWorkflow = 'delegate-xcli-orchestrate.yml',
  [string] $XCliRef = 'develop',
  [string] $XSdkRef = 'develop',
  [int] $LoopDelaySeconds = 30,
  [int] $TimeoutMinutes = 45,
  [switch] $Continuous,
  [int] $MaxLoops = 0,
  [string] $Branch = 'develop',
  [string] $StatePath,
  [string] $HistoryPath,
  [int] $MaxHistoryLines = 5000,
  [int] $KeepTailLines = 500,
  [switch] $CompressRotated,
  [switch] $AutoTriage,
  [string] $TriageRoot,
  [ValidateSet('on-merge','always','on-failure')]
  [string] $LoopMode = 'on-merge',
  [int] $DeadlockThreshold = 5,
  [int] $BackoffMinSeconds = 5,
  [int] $BackoffMaxSeconds = 60,
  [switch] $OrchestratorPlanOnly,
  [switch] $OrchestratorDryRun,
  [switch] $OrchestratorVerbose,
  [ValidateSet('off','warn','fail')]
  [string] $GuardMode = 'warn',
  [string[]] $GuardIgnoreModes = @('plan-only','dry-run'),
  [switch] $Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Info([string] $m) { $ts=(Get-Date).ToString('HH:mm:ss'); Write-Host "[$ts] $m" }
function Require([string] $cmd) { if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Missing command: $cmd" } }
Require gh

# Paths
if (-not $StatePath -or -not $HistoryPath -or -not $TriageRoot) {
  $artDir = Join-Path $PSScriptRoot '../../artifacts'
  if (-not (Test-Path -LiteralPath $artDir)) { New-Item -ItemType Directory -Force -Path $artDir | Out-Null }
  if (-not $StatePath) { $StatePath = Join-Path $artDir 'monitor-delegate.state.json' }
  if (-not $HistoryPath) { $HistoryPath = Join-Path $artDir 'monitor-delegate.history.jsonl' }
  if (-not $TriageRoot) { $TriageRoot = Join-Path $artDir 'monitor-delegate-triage' }
}

function Load-State() { if (Test-Path -LiteralPath $StatePath) { try { Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json } catch { $null } } else { $null } }
function Save-State($obj) { ($obj | ConvertTo-Json -Depth 6) | Out-File -FilePath $StatePath -Encoding utf8 }

function Rotate-History([string] $path) {
  try {
    if ($MaxHistoryLines -le 0 -or -not (Test-Path -LiteralPath $path)) { return }
    $lineCount = (Get-Content -LiteralPath $path).Count
    if ($lineCount -le $MaxHistoryLines) { return }
    $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $rot = "$path.$ts.jsonl"
    Copy-Item -LiteralPath $path -Destination $rot -Force
    if ($CompressRotated) {
      $gz = "$rot.gz"
      $in = [System.IO.File]::OpenRead($rot)
      $out = [System.IO.File]::Create($gz)
      try { $gzip = New-Object System.IO.Compression.GZipStream($out,[System.IO.Compression.CompressionLevel]::Optimal); try { $in.CopyTo($gzip) } finally { $gzip.Dispose() } } finally { $in.Dispose(); $out.Dispose() }
      Remove-Item -LiteralPath $rot -Force -ErrorAction SilentlyContinue
    }
    $keep = if ($KeepTailLines -gt 0 -and $KeepTailLines -lt $lineCount) { $KeepTailLines } else { [math]::Min(500, $lineCount) }
    Get-Content -LiteralPath $path -Tail $keep | Out-File -FilePath $path -Encoding utf8NoBOM
    Info ("Rotated history -> {0} (kept last {1} lines)" -f ($CompressRotated ? "$rot.gz" : $rot), $keep)
  } catch { Write-Warning ("History rotation failed: {0}" -f $_.Exception.Message) }
}

function Get-LatestMergedPr() {
  try {
    $list = gh pr list -R $XCliRepo -B $Branch --state merged --json number,mergedAt,url -L 1 | ConvertFrom-Json
    if ($list -and $list.Count -gt 0) { return $list[0] }
  } catch { }
  return $null
}

function Invoke-Orchestrator([string] $ref) {
  $scriptPath = Join-Path $PSScriptRoot 'orchestrate-multi-repo.ps1'
  $artDir = Join-Path $PSScriptRoot '../../artifacts'
  if (-not (Test-Path -LiteralPath $artDir)) { New-Item -ItemType Directory -Force -Path $artDir | Out-Null }
  $outPath = Join-Path $artDir 'last-orchestrator.json'
  $histPath = Join-Path $artDir 'multi-repo-run.from-monitor.jsonl'
  $params = @{ XCliRepo=$XCliRepo; XSdkRepo=$XSdkRepo; XCliRef=$ref; XSdkRef=$XSdkRef; OutPath=$outPath; HistoryPath=$histPath; Json=$true }
  if ($OrchestratorPlanOnly) { $params.PlanOnly = $true }
  if ($OrchestratorDryRun) { $params.DryRun = $true }
  try {
    $stdout = & $scriptPath @params
    if (Test-Path -LiteralPath $outPath) {
      try { return (Get-Content -Raw -LiteralPath $outPath) | ConvertFrom-Json } catch { }
    }
    # Fallback: pick last JSON line from stdout
    $text = if ($stdout -is [array]) { ($stdout -join "`n") } else { $stdout.ToString() }
    $first = $text.IndexOf('{')
    if ($first -ge 0) {
      $json = $text.Substring($first)
      try { return $json | ConvertFrom-Json } catch { }
    }
    return $null
  } catch { $null }
}

function Summarize-Orchestrator($o, [bool] $IncludeData) {
  if (-not $o) { return $null }
  $steps = @()
  try {
    foreach ($s in ($o.steps | ForEach-Object { $_ })) {
      if (-not $s) { continue }
      if ($IncludeData) {
        $steps += [ordered]@{ name=$s.name; status=$s.status; data=$s.data }
      } else {
        $steps += [ordered]@{ name=$s.name; status=$s.status }
      }
    }
  } catch { }
  return [ordered]@{ mode=$o.mode; status=$o.status; ref=$o.ref; steps=$steps }
}

function Evaluate-Guard($o) {
  if ($GuardMode -eq 'off') { return @{ triggered=$false; level='off'; message=$null } }
  if (-not $o) { return @{ triggered=$true; level=$GuardMode; message='orchestrator: null summary' } }
  $mode = ($o.mode ?? '').ToString().ToLowerInvariant()
  if ($GuardIgnoreModes -contains $mode) { return @{ triggered=$false; level=$GuardMode; message='ignored by mode' } }
  $status = ($o.status ?? 'unknown').ToString().ToLowerInvariant()
  if ($status -ne 'success') {
    $msg = "Orchestrator guard: status=$status mode=$mode"
    return @{ triggered=$true; level=$GuardMode; message=$msg }
  }
  return @{ triggered=$false; level=$GuardMode; message='ok' }
}

function Append-Iteration([int] $prNumber, [datetime] $mergedAt, $orch) {
  function Refresh-ConveyorSummary() {
    try {
      $sumScript = Join-Path $PSScriptRoot 'conveyor-summary.ps1'
      if (Test-Path -LiteralPath $sumScript) {
        $artDir = Join-Path $PSScriptRoot '../../artifacts'
        if (-not (Test-Path -LiteralPath $artDir)) { New-Item -ItemType Directory -Force -Path $artDir | Out-Null }
        $jsonOut = Join-Path $artDir 'conveyor-summary.json'
        & $sumScript -JsonOut $jsonOut *> $null
        # Archive snapshot under artifacts/smokes (keep last 20)
        try {
          $smokeDir = Join-Path $artDir 'smokes'
          if (-not (Test-Path -LiteralPath $smokeDir)) { New-Item -ItemType Directory -Force -Path $smokeDir | Out-Null }
          $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
          $arch = Join-Path $smokeDir ("conveyor-summary.{0}.json" -f $stamp)
          if (Test-Path -LiteralPath $jsonOut) { Copy-Item -LiteralPath $jsonOut -Destination $arch -Force }
          $existing = Get-ChildItem -LiteralPath $smokeDir -Filter 'conveyor-summary.*.json' | Sort-Object LastWriteTime -Descending
          if ($existing.Count -gt 20) {
            $existing | Select-Object -Skip 20 | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
          }
        } catch { }
      }
    } catch { }
  }

  $delegator = $null
  try {
    $step = $orch?.steps | Where-Object { $_.name -eq 'x-sdk/delegator' } | Select-Object -First 1
    if ($step) { $delegator = [ordered]@{ id=$step.data.run_id; url=$step.data.url; status=$step.data.status; conclusion=$step.status } }
  } catch { }
  $orchSummary = Summarize-Orchestrator -o $orch -IncludeData:$OrchestratorVerbose
  $guardEval = Evaluate-Guard -o $orchSummary
  $iter = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    branch = $Branch
    xcli_ref = $XCliRef
    pr = $prNumber
    merged_at = $mergedAt.ToString('o')
    delegator = $delegator
    orchestrator = $orchSummary
    guard = $guardEval
  }
  $line = ($iter | ConvertTo-Json -Depth 6)
  $dir = Split-Path -Parent $HistoryPath
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $line | Out-File -FilePath $HistoryPath -Encoding utf8NoBOM -Append
  Rotate-History -path $HistoryPath
  Refresh-ConveyorSummary

  # Guard (warn only in continuous path)
  if ($guardEval.triggered -and $GuardMode -ne 'off') { Write-Warning $guardEval.message }
}

$state = Load-State
$lastMergedAt = if ($state -and $state.last_merged_at) { [datetime]$state.last_merged_at } else { [datetime]'1900-01-01' }
$lastPr = if ($state -and $state.last_pr) { [int]$state.last_pr } else { 0 }

if ($Continuous) {
  Info ("Continuous mode: watching merges into {0}/{1}" -f $XCliRepo,$Branch)
  $loops = 0
  while ($true) {
    $latest = Get-LatestMergedPr
    if ($latest -and $latest.mergedAt) {
      $mergedAt = [datetime]$latest.mergedAt
      if ($mergedAt -gt $lastMergedAt) {
        $orch = Invoke-Orchestrator -ref $XCliRef
        Append-Iteration -prNumber $latest.number -mergedAt $mergedAt -orch $orch
        $lastMergedAt = $mergedAt; $lastPr = $latest.number
        Save-State @{ last_merged_at=$lastMergedAt.ToString('o'); last_pr=$lastPr }
        $loops++
        if ($MaxLoops -gt 0 -and $loops -ge $MaxLoops) { break }
        continue
      }
    }
    # Optionally re-run even without a new merge
    $shouldReRun = $false
    if ($LoopMode -eq 'always') { $shouldReRun = $true }
    elseif ($LoopMode -eq 'on-failure') {
      try {
        if (Test-Path -LiteralPath $HistoryPath) {
          $last = Get-Content -LiteralPath $HistoryPath -Tail 1 | ConvertFrom-Json
          if ($last) {
            $d = $last.delegator
            if ($d -and ($d.conclusion ?? 'unknown') -ne 'success') { $shouldReRun = $true }
          }
        }
      } catch { }
    }

    if ($shouldReRun -and $lastPr -gt 0 -and $lastMergedAt -gt [datetime]'1900-01-01') {
      $orch = Invoke-Orchestrator -ref $XCliRef
      Append-Iteration -prNumber $lastPr -mergedAt $lastMergedAt -orch $orch
      $loops++
      if ($MaxLoops -gt 0 -and $loops -ge $MaxLoops) { break }
      continue
    }

    Start-Sleep -Seconds $LoopDelaySeconds
  }
  $out = if ($Json) { '{"status":"ok","mode":"continuous"}' } else { 'OK' }
  $out | Write-Output
  exit 0
}

# Single-run: watch a specific PR until merged, or use the latest merged PR
if ($XCliPr -gt 0) {
  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
  Info ("Monitoring PR {0} in {1} until merged (timeout {2}m)" -f $XCliPr,$XCliRepo,$TimeoutMinutes)
  while ((Get-Date) -lt $deadline) {
    try {
      $pr = gh pr view $XCliPr -R $XCliRepo --json mergedAt,state,mergeStateStatus,url | ConvertFrom-Json
      if ($pr -and $pr.mergedAt) { break }
    } catch { }
    Start-Sleep -Seconds $LoopDelaySeconds
  }
  if (-not $pr -or -not $pr.mergedAt) { Write-Warning 'Timeout waiting for merge.'; exit 1 }
  $mergedAt = [datetime]$pr.mergedAt
  $orch = Invoke-Orchestrator -ref $XCliRef
  Append-Iteration -prNumber $XCliPr -mergedAt $mergedAt -orch $orch
  Save-State @{ last_merged_at=$mergedAt.ToString('o'); last_pr=$XCliPr }
  $g = $null; $g = & { function _e { param($o) ($o) } _e $null } # force new scope
  $g = @{ triggered=$false; level=$GuardMode; message='ok' }
  if ($GuardMode -ne 'off') { $g = (Evaluate-Guard -o $orch) }
  if ($Json) {
    $orchObj = Summarize-Orchestrator -o $orch -IncludeData:$OrchestratorVerbose
    $payload = [ordered]@{ pr=$XCliPr; merged_at=$mergedAt.ToString('o'); orchestrator = $orchObj; guard = $g }
    $payload | ConvertTo-Json -Depth 6 | Write-Output
  } else {
    $payload = if ($orch) { $orch } else { [ordered]@{ pr=$XCliPr; merged_at=$mergedAt.ToString('o'); orchestrator=$null } }
    $payload | Write-Output
  }
  if ($g.triggered -and $GuardMode -eq 'fail') { exit 2 }
  exit 0
}
else {
  $latest = Get-LatestMergedPr
  if (-not $latest) { Write-Warning "No merged PR found on $Branch"; exit 0 }
  $mergedAt = [datetime]$latest.mergedAt
  $orch = Invoke-Orchestrator -ref $XCliRef
  Append-Iteration -prNumber $latest.number -mergedAt $mergedAt -orch $orch
  Save-State @{ last_merged_at=$mergedAt.ToString('o'); last_pr=$latest.number }
  $g = @{ triggered=$false; level=$GuardMode; message='ok' }
  if ($GuardMode -ne 'off') { $g = (Evaluate-Guard -o $orch) }
  if ($Json) {
    $orchObj = Summarize-Orchestrator -o $orch -IncludeData:$OrchestratorVerbose
    $payload = [ordered]@{ pr=$latest.number; merged_at=$mergedAt.ToString('o'); orchestrator = $orchObj; guard = $g }
    $payload | ConvertTo-Json -Depth 6 | Write-Output
  } else {
    $payload = if ($orch) { $orch } else { [ordered]@{ pr=$latest.number; merged_at=$mergedAt.ToString('o'); orchestrator=$null } }
    $payload | Write-Output
  }
  if ($g.triggered -and $GuardMode -eq 'fail') { exit 2 }
  exit 0
}

if ($Continuous) {
  Info ("Continuous mode: watching merges into {0}/{1}" -f $XCliRepo,$Branch)
  while ($true) {
    $latest = Get-LatestMergedPr
    if ($latest -and $latest.mergedAt) {
      $mergedAt = [datetime]$latest.mergedAt
      if ($mergedAt -gt $lastMergedAt) {
        $summary.steps = @() # reset per-iteration
        Invoke-Orchestration -prNumber $latest.number -mergedAt $mergedAt
        $lastMergedAt = $mergedAt
        $lastPr = $latest.number
        Save-State @{ last_merged_at = $lastMergedAt.ToString('o'); last_pr = $lastPr }
        $loops++
        if ($MaxLoops -gt 0 -and $loops -ge $MaxLoops) { break }
        # Immediately continue to next loop without delay (unless no new merges)
        continue
      }
    }
    # Optionally loop again without a new merge
    $shouldReRun = $false
    if ($LoopMode -eq 'always') { $shouldReRun = $true }
    elseif ($LoopMode -eq 'on-failure') {
      try {
        if (Test-Path -LiteralPath $HistoryPath) {
          $last = Get-Content -LiteralPath $HistoryPath -Tail 1 | ConvertFrom-Json
          if ($last) {
            $d = $last.delegator
            if ($d -and ($d.conclusion ?? 'unknown') -ne 'success') { $shouldReRun = $true }
            elseif ($last.wrappers) {
              foreach ($w in $last.wrappers) { if (($w.conclusion ?? 'unknown') -ne 'success') { $shouldReRun = $true; break } }
            }
          }
        }
      } catch { }
    }
    if ($shouldReRun -and $lastPr -gt 0 -and $lastMergedAt -gt [datetime]'1900-01-01') {
      if ($failureCount -gt 0) { Info ("Backoff {0}s before retry" -f $backoff); Start-Sleep -Seconds $backoff }
      $summary.steps = @()
      Invoke-Orchestration -prNumber $lastPr -mergedAt $lastMergedAt
      $loops++
      if ($MaxLoops -gt 0 -and $loops -ge $MaxLoops) { break }
      continue
    }
    Start-Sleep -Seconds $LoopDelaySeconds
  }
  $summary.ended = (Get-Date).ToString('o')
  if ($Json) { ($summary | ConvertTo-Json -Depth 6) } else { $summary }
  exit 0
}

Info ("Monitoring PR {0} in {1} until merged (timeout {2}m)" -f $XCliPr,$XCliRepo,$TimeoutMinutes)
while ((Get-Date) -lt $deadline) {
  try {
    $pr = gh pr view $XCliPr -R $XCliRepo --json mergedAt,state,mergeStateStatus,url | ConvertFrom-Json
    if ($pr -and $pr.mergedAt) {
      Info ("PR merged at {0}" -f $pr.mergedAt)
      Add-Step 'x-cli/pr' 'merged' @{ url=$pr.url; mergedAt=$pr.mergedAt }
      break
    }
    Add-Step 'x-cli/pr' 'pending' @{ state=$pr.state; mergeState=$pr.mergeStateStatus }
  } catch {
    Add-Step 'x-cli/pr' 'fail' @{ error = $_.Exception.Message }
  }
  Start-Sleep -Seconds $LoopDelaySeconds
}

if (-not ($summary.steps | Where-Object { $_.name -eq 'x-cli/pr' -and $_.status -eq 'merged' })) {
  Info 'Timeout waiting for merge.'
  if ($Json) { ($summary | ConvertTo-Json -Depth 6) } else { $summary }
  exit 1
}

# Dispatch delegator in x-sdk
Info ("Dispatching {0} in {1} (xcli_ref={2})" -f $DelegatorWorkflow,$XSdkRepo,$XCliRef)
$start = Get-Date
try {
  gh workflow run $DelegatorWorkflow -R $XSdkRepo --ref develop -f xcli_ref=$XCliRef | Out-Null
  Add-Step 'x-sdk/dispatch' 'ok' @{ workflow=$DelegatorWorkflow }
} catch {
  Add-Step 'x-sdk/dispatch' 'fail' @{ error = $_.Exception.Message }
  if ($Json) { ($summary | ConvertTo-Json -Depth 6) } else { $summary }
  exit 1
}

# Locate the new run and wait for completion
Start-Sleep -Seconds 5
$run = $null
for ($i=0; $i -lt 20; $i++) {
  try {
    $candidates = gh run list -R $XSdkRepo --workflow $DelegatorWorkflow --json databaseId,createdAt,event,status,conclusion,url -L 10 | ConvertFrom-Json
    $run = $candidates | Where-Object { $_.event -eq 'workflow_dispatch' -and ([datetime]$_.createdAt) -ge $start.AddMinutes(-1) } | Sort-Object createdAt -Descending | Select-Object -First 1
    if ($run) { break }
  } catch { }
  Start-Sleep -Seconds 3
}
if (-not $run) {
  Add-Step 'x-sdk/run' 'fail' @{ error='delegator run not found' }
  if ($Json) { ($summary | ConvertTo-Json -Depth 6) } else { $summary }
  exit 1
}

Info ("Watching delegator run {0}" -f $run.databaseId)
try { gh run watch -R $XSdkRepo $run.databaseId | Out-Null } catch { }

try {
  $view = gh run view -R $XSdkRepo $run.databaseId --json url,status,conclusion,createdAt,updatedAt | ConvertFrom-Json
  Add-Step 'x-sdk/run' ($view.conclusion ?? 'unknown') @{ id=$run.databaseId; url=$view.url; status=$view.status; conclusion=$view.conclusion; createdAt=$view.createdAt; updatedAt=$view.updatedAt }
} catch {
  Add-Step 'x-sdk/run' 'fail' @{ error = $_.Exception.Message }
}

$summary.ended = (Get-Date).ToString('o')
$artDir = Join-Path $PSScriptRoot '../../artifacts'
if (-not (Test-Path -LiteralPath $artDir)) { New-Item -ItemType Directory -Force -Path $artDir | Out-Null }
$outPath = Join-Path $artDir 'monitor-delegate.summary.json'
($summary | ConvertTo-Json -Depth 6) | Out-File -FilePath $outPath -Encoding utf8
Info ("Wrote summary: {0}" -f $outPath)
if ($Json) { ($summary | ConvertTo-Json -Depth 6) } else { $summary }
