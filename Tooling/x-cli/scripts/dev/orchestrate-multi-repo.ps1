[CmdletBinding()]
param(
  [string] $XCliRepo = 'LabVIEW-Community-CI-CD/x-cli',
  [string] $XSdkRepo = 'LabVIEW-Community-CI-CD/x-sdk',
  [string] $WingetRepo = 'LabVIEW-Community-CI-CD/winget-bucket',
  [string] $XSdkDelegatorWorkflow = 'delegate-xcli-orchestrate.yml',
  [string] $XCliRef = 'develop',
  [string] $XSdkRef = 'develop',
  [int] $TimeoutMinutes = 45,
  [int] $PollSeconds = 5,
  [switch] $DryRun,
  [switch] $PlanOnly,
  [string] $OutPath,
  [string] $HistoryPath,
  [switch] $Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Info([string] $m) { $ts = (Get-Date).ToString('HH:mm:ss'); Write-Host "[$ts] $m" }
function Warn([string] $m) { $ts = (Get-Date).ToString('HH:mm:ss'); Write-Warning "[$ts] $m" }
function Require([string] $cmd) { if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Missing command: $cmd" } }

$startTime = Get-Date

# Resolve default output/history paths under artifacts
if (-not $OutPath -or -not $HistoryPath) {
  $artDir = Join-Path $PSScriptRoot '../../artifacts'
  if (-not (Test-Path -LiteralPath $artDir)) { New-Item -ItemType Directory -Force -Path $artDir | Out-Null }
  if (-not $OutPath) { $OutPath = Join-Path $artDir 'multi-repo-run.json' }
  if (-not $HistoryPath) { $HistoryPath = Join-Path $artDir 'multi-repo-run.history.jsonl' }
} else {
  foreach ($path in @($OutPath, $HistoryPath)) {
    if ([string]::IsNullOrEmpty($path)) { continue }
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  }
}

if ($OutPath) { $OutPath = [System.IO.Path]::GetFullPath($OutPath) }
if ($HistoryPath) { $HistoryPath = [System.IO.Path]::GetFullPath($HistoryPath) }

$summary = [ordered]@{
  started = $startTime.ToString('o')
  mode = if ($PlanOnly) { 'plan-only' } elseif ($DryRun) { 'dry-run' } else { 'execute' }
  repos = @{ xcli = $XCliRepo; xsdk = $XSdkRepo; winget = $WingetRepo }
  ref = $XCliRef
  xsdk_ref = $XSdkRef
  history_path = $HistoryPath
  steps = @()
}

function Add-Step([string] $name, [string] $status, [hashtable] $data) {
  $summary.steps += [ordered]@{ name = $name; status = $status; data = $data; ts = (Get-Date).ToString('o') }
}

function Save-Summary() {
  if (-not $OutPath) { return }
  ($summary | ConvertTo-Json -Depth 6) | Out-File -FilePath $OutPath -Encoding utf8
}

function Append-History() {
  if (-not $HistoryPath) { return }
  $dir = Split-Path -Parent $HistoryPath
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  ($summary | ConvertTo-Json -Depth 6 -Compress) | Out-File -FilePath $HistoryPath -Encoding utf8 -Append
}

function Finalize-Run([string] $status) {
  $summary.status = $status
  $summary.ended = (Get-Date).ToString('o')
  $summary.duration_seconds = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
  Save-Summary
  Append-History
  if ($Json) {
    ($summary | ConvertTo-Json -Depth 6) | Write-Output
  } elseif ($OutPath) {
    Write-Host ("Wrote: {0}" -f $OutPath)
  }
}

function Check-GhAuth() {
  $auth = [ordered]@{ available = $false; user = $null; host = $null }
  try {
    Require gh
    $auth.available = $true
    $out = gh auth status 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) {
      if ($out -match 'Logged in to ([^ ]+) as ([^ ]+)') { $auth.host = $Matches[1]; $auth.user = $Matches[2] }
    }
  } catch {
    $auth.available = $false
  }
  return $auth
}

function Start-XSdkDelegator([string] $xsdkRepo, [string] $workflow, [string] $xcliRef, [string] $xsdkRef, [int] $timeoutMin, [int] $pollSec) {
  $deadline = (Get-Date).AddMinutes($timeoutMin)
  $result = [ordered]@{ dispatched = $false; run_id = $null; url = $null; status = $null; conclusion = $null; error = $null; attempts=@() }
  try {
    Info ("Dispatching {0} in {1} (xsdk_ref={2}; xcli_ref={3})" -f $workflow, $xsdkRepo, $xsdkRef, $xcliRef)
    $out1 = gh workflow run $workflow -R $xsdkRepo --ref $xsdkRef -f xcli_ref=$xcliRef 2>&1
    $exit1 = $LASTEXITCODE
    $result.attempts += [ordered]@{ ref=$xsdkRef; exit=$exit1; output=($out1 | Out-String) }
    if ($exit1 -ne 0) {
      $o1 = ($out1 | Out-String)
      if (($o1 -match 'HTTP 422') -and ($xsdkRef -ne 'develop')) {
        Info ("Dispatch returned 422 on '{0}'; falling back to 'develop'" -f $xsdkRef)
        $out2 = gh workflow run $workflow -R $xsdkRepo --ref develop -f xcli_ref=$xcliRef 2>&1
        $exit2 = $LASTEXITCODE
        $result.attempts += [ordered]@{ ref='develop'; exit=$exit2; output=($out2 | Out-String) }
        if ($exit2 -ne 0) {
          $result.error = "dispatch failed after fallback (exit $exit2)"
          return $result
        } else {
          $result.dispatched = $true
          $result.fallback_used = $true
          $result.fallback_ref = 'develop'
        }
      } else {
        $result.error = "dispatch failed (exit $exit1)"
        return $result
      }
    } else {
      $result.dispatched = $true
    }
  } catch {
    $result.error = $_.Exception.Message
    return $result
  }
  Start-Sleep -Seconds 3
  $found = $false
  for ($i = 0; $i -lt 20 -and -not $found; $i++) {
    try {
      $candidates = gh run list -R $xsdkRepo --workflow $workflow --json databaseId,createdAt,event,status,conclusion,url -L 15 | ConvertFrom-Json
      $run = $candidates | Where-Object { $_.event -eq 'workflow_dispatch' } | Sort-Object createdAt -Descending | Select-Object -First 1
      if ($run) {
        $result.run_id = $run.databaseId
        $result.url = $run.url
        $found = $true
        break
      }
    } catch { }
    Start-Sleep -Seconds 2
  }
  if (-not $found) {
    $result.error = 'delegator run not found'
    return $result
  }

  Info ("Watching delegator run {0}" -f $result.run_id)
  while ((Get-Date) -lt $deadline) {
    try {
      $view = gh run view -R $xsdkRepo $result.run_id --json status,conclusion,url,updatedAt | ConvertFrom-Json
      $result.status = $view.status
      $result.conclusion = $view.conclusion
      $result.url = $view.url
      if ($view.status -in @('completed', 'cancelled')) { break }
    } catch {
      $result.error = $_.Exception.Message
      break
    }
    Start-Sleep -Seconds $pollSec
  }
  return $result
}

$auth = Check-GhAuth
Add-Step 'env/gh' ($auth.available ? 'ok' : 'missing') @{ user = $auth.user; host = $auth.host }

$plan = @(
  @{ name = 'x-sdk/delegator'; desc = ("Run {0} in {1} for {2}@{3}" -f $XSdkDelegatorWorkflow, $XSdkRepo, $XCliRepo, $XCliRef) },
  @{ name = 'winget/dispatch'; desc = ("winget_publish from x-sdk to {0}" -f $WingetRepo) }
)
Add-Step 'plan' 'ready' @{ items = $plan }

if ($PlanOnly) {
  Info 'Plan-only mode: not executing.'
  Finalize-Run 'planned'
  return
}

if (-not $auth.available -or $DryRun) {
  Warn 'Dry-run or gh unavailable: skipping remote dispatch. Writing plan only.'
  Add-Step 'x-sdk/delegator' 'skipped' @{ reason = if ($DryRun) { 'dry-run' } else { 'gh-auth-missing' } }
  Finalize-Run 'skipped'
  return
}

$delegator = Start-XSdkDelegator -xsdkRepo $XSdkRepo -workflow $XSdkDelegatorWorkflow -xcliRef $XCliRef -xsdkRef $XSdkRef -timeoutMin $TimeoutMinutes -pollSec $PollSeconds
$hasFallback = $false
try { if ($null -ne $delegator -and ($delegator.PSObject.Properties.Name -contains 'fallback_used') -and $delegator.fallback_used) { $hasFallback = $true } } catch { $hasFallback = $false }
$effectiveRef = if ($hasFallback) { 'develop' } else { $XSdkRef }
$att = $null
try { $att = $delegator.attempts } catch { $att = $null }
$delegatorData = [ordered]@{
  run_id = $delegator.run_id
  url = $delegator.url
  status = $delegator.status
  error = $delegator.error
  xsdk_ref_requested = $XSdkRef
  xsdk_ref_effective = $effectiveRef
  fallback_used = $hasFallback
  attempts = $att
}
Add-Step 'x-sdk/delegator' (($delegator.conclusion ?? 'unknown')) $delegatorData

try {
  $wingetRuns = gh run list -R $WingetRepo --json databaseId,createdAt,event,status,conclusion,url -L 20 | ConvertFrom-Json
  $repoDispatch = $wingetRuns | Where-Object { $_.event -eq 'repository_dispatch' } | Sort-Object createdAt -Descending | Select-Object -First 1
  if ($repoDispatch) {
    Add-Step 'winget/repo_dispatch' ($repoDispatch.conclusion ?? 'unknown') @{ run_id = $repoDispatch.databaseId; url = $repoDispatch.url; status = $repoDispatch.status }
  } else {
    Add-Step 'winget/repo_dispatch' 'n/a' @{ note = 'no recent repository_dispatch runs found' }
  }
} catch {
  Add-Step 'winget/repo_dispatch' 'skip' @{ error = $_.Exception.Message }
}

$finalStatus = if ($delegator.error) { 'error' } elseif ($delegator.conclusion) { $delegator.conclusion } else { 'unknown' }
Finalize-Run $finalStatus
