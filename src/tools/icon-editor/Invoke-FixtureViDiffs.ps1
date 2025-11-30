 #Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600,
  [string]$RequestsPath,
  [string]$CapturesRoot,
  [string]$SummaryPath,
  [switch]$DryRun,
  [int]$TimeoutSeconds,
  [string]$CompareScript
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
if (-not (Test-Path 'variable:Global:InvokeValidateLocalStubLog')) {
    $Global:InvokeValidateLocalStubLog = @()
} elseif (-not $Global:InvokeValidateLocalStubLog) {
    $Global:InvokeValidateLocalStubLog = @()
}
$Global:InvokeValidateLocalStubLog += [pscustomobject]@{
    Command = 'InvokeDiffs'
    Parameters = [pscustomobject]@{
        RequestsPath = $RequestsPath
        CapturesRoot = $CapturesRoot
        SummaryPath  = $SummaryPath
        DryRun       = $DryRun.IsPresent
    }
}
if (-not (Test-Path -LiteralPath $CapturesRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $CapturesRoot -Force | Out-Null
}
$summaryDir = Split-Path -Parent $SummaryPath
if ($summaryDir -and -not (Test-Path -LiteralPath $summaryDir -PathType Container)) {
    New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
}

$requestSpec = Get-Content -LiteralPath $RequestsPath -Raw | ConvertFrom-Json -Depth 6
$requests = @()
if ($requestSpec -and $requestSpec.requests) { $requests = @($requestSpec.requests) }
$total = $requests.Count
$counts = [ordered]@{
    total     = $total
    compared  = $DryRun.IsPresent ? 0 : $total
    same      = 0
    different = $DryRun.IsPresent ? 0 : $total
    skipped   = 0
    dryRun    = $DryRun.IsPresent ? $total : 0
    errors    = 0
}

$results = New-Object System.Collections.Generic.List[object]
$index = 0
foreach ($req in $requests) {
    $index++
    $entry = [ordered]@{
        name     = $req.name
        relPath  = $req.relPath
        category = $req.category
        status   = ($DryRun.IsPresent ? 'dry-run' : 'different')
    }
    if (-not $DryRun.IsPresent) {
        $captureDir = ('pair-{0:D3}' -f $index)
        $entry.captureDir = $captureDir
        $pairRoot = Join-Path $CapturesRoot $captureDir
        $compareDir = Join-Path $pairRoot 'compare'
        New-Item -ItemType Directory -Path $compareDir -Force | Out-Null
        $session = [ordered]@{
            schema  = 'teststand-compare-session/v1'
            at      = (Get-Date).ToString('o')
            outcome = @{ exitCode = 1; seconds = 0.5; diff = $true }
            error   = $null
        }
        $session | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $pairRoot 'session-index.json') -Encoding utf8
        $capture = @{
            exitCode = 1
            seconds  = 0.5
            command  = 'stub'
            environment = @{ cli = @{ message = 'differences detected' } }
        }
        $capture | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $compareDir 'lvcompare-capture.json') -Encoding utf8
    }
    $results.Add([pscustomobject]$entry) | Out-Null
}

$summaryObject = [ordered]@{
    schema      = 'icon-editor/vi-diff-summary@v1'
    generatedAt = (Get-Date).ToString('o')
    counts      = $counts
    requests    = $results
}
$summaryObject | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $SummaryPath -Encoding utf8
[pscustomobject]$summaryObject

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}
