#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600,
  [string]$FixturePath,
  [string]$BaselineFixture,
  [string]$BaselineManifest,
  [string]$ResourceOverlayRoot,
  [switch]$SkipLVCompare,
  [string]$ResultsRoot,
  [switch]$KeepWorkspace,
  [switch]$SkipBootstrap,
  [switch]$IncludeSimulation,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'

<#
.SYNOPSIS
Runs a self-hosted Validate flow locally, including fixture report generation,
VI diff preparation, LVCompare execution, tests, and pre-push checks.

.DESCRIPTION
Recreates the icon-editor portions of the Validate workflow on a self-hosted
Windows runner. Expects LabVIEW/LVCompare/TestStand to be available, along with
GH_TOKEN/GITHUB_TOKEN for API calls. Leaves results under the specified
ResultsRoot (defaults to tests/results/_agent/icon-editor/local-validate).

 .PARAMETER FixturePath
 Path to the VIP produced by the build (for example, the artifact downloaded
 from the composite workflow).

.PARAMETER BaselineFixture
Optional path to the baseline VIP used for comparison prep.

.PARAMETER BaselineManifest
Optional path to the baseline manifest (icon-editor/fixture-manifest@v1).

.PARAMETER SkipLVCompare
When present, runs comparison tooling in dry-run mode (no LVCompare launch) but still renders reports.

.PARAMETER ResultsRoot
Root directory for all generated artifacts. Defaults to tests/results/_agent/icon-editor/local-validate.

.PARAMETER KeepWorkspace
If set, extraction directories are preserved for inspection.

.PARAMETER SkipBootstrap
Skips priority/bootstrap.ps1 (use only if the session is already bootstrapped).

.PARAMETER IncludeSimulation
Also run Simulate-IconEditorBuild VIP diff (dry-run compare and report).

#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try { return (git -C $StartPath rev-parse --show-toplevel 2>$null).Trim() } catch { return $StartPath }
}

function Resolve-PathFromRepo {
  param(
    [string]$Path,
    [string]$RepoRoot,
    [string]$ParameterName,
    [switch]$Optional
  )
  if (-not $Path) {
    if ($Optional) { return $null }
    throw "$ParameterName is required."
  }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return (Resolve-Path -LiteralPath $Path).Path
  }
  return (Resolve-Path -LiteralPath (Join-Path $RepoRoot $Path)).Path
}

$repoRoot = Resolve-RepoRoot
$iconEditorToolsRoot = Join-Path $repoRoot 'tools/icon-editor'
if (-not (Test-Path -LiteralPath $iconEditorToolsRoot -PathType Container)) {
  $altToolsRoot = Join-Path $repoRoot 'src/tools/icon-editor'
  if (Test-Path -LiteralPath $altToolsRoot -PathType Container) {
    $iconEditorToolsRoot = $altToolsRoot
  } else {
    throw "Icon Editor tooling not found under '$iconEditorToolsRoot' or '$altToolsRoot'."
  }
}

if (-not $SkipBootstrap.IsPresent) {
  Write-Host '==> Running priority bootstrap'
  pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot 'tools/priority/bootstrap.ps1') | Out-Null
}

if (-not $DryRun.IsPresent) {
  Write-Host '==> Running hook parity (warn-only)'
  node (Join-Path $repoRoot 'tools/npm/run-script.mjs') hooks:pre-commit | Out-Null
  node (Join-Path $repoRoot 'tools/npm/run-script.mjs') hooks:multi | Out-Null
} else {
  Write-Host '==> Dry run: skipping hook parity checks'
}

if (-not $ResultsRoot) {
  $ResultsRoot = Join-Path $repoRoot 'tests/results/_agent/icon-editor/local-validate'
}
if (-not (Test-Path -LiteralPath $ResultsRoot -PathType Container)) {
  [void][System.IO.Directory]::CreateDirectory($ResultsRoot)
}
$resultsRootResolved = (Resolve-Path -LiteralPath $ResultsRoot).Path

$fixtureCurrent = Resolve-PathFromRepo -Path $FixturePath -RepoRoot $repoRoot -ParameterName 'FixturePath'
$baselineFixtureResolved = Resolve-PathFromRepo -Path $BaselineFixture -RepoRoot $repoRoot -ParameterName 'BaselineFixture' -Optional
$baselineManifestResolved = Resolve-PathFromRepo -Path $BaselineManifest -RepoRoot $repoRoot -ParameterName 'BaselineManifest' -Optional
$overlayResolved = $null
if ($ResourceOverlayRoot) {
  $overlayResolved = (Resolve-Path -LiteralPath $ResourceOverlayRoot).Path
} else {
  $defaultOverlay = Join-Path $repoRoot 'vendor/icon-editor/resource'
  if (Test-Path -LiteralPath $defaultOverlay -PathType Container) {
    $overlayResolved = (Resolve-Path -LiteralPath $defaultOverlay).Path
  }
}

Write-Host "==> Current fixture: $fixtureCurrent"
Write-Host ("==> Baseline fixture: {0}" -f ($baselineFixtureResolved ?? '(not provided)'))
Write-Host ("==> Baseline manifest: {0}" -f ($baselineManifestResolved ?? '(not provided)'))
Write-Host "==> Results root: $resultsRootResolved"
if ($overlayResolved) {
  Write-Host "==> Resource overlay: $overlayResolved"
}

if (-not $env:GH_TOKEN -and -not $env:GITHUB_TOKEN) {
  Write-Warning 'GH_TOKEN / GITHUB_TOKEN not set; GitHub API calls may fail.'
}

$describeOut = Join-Path $resultsRootResolved 'fixture-report.json'
Write-Host '==> Generating fixture report'
$describeWork = Join-Path $resultsRootResolved '__describe'
if ((Test-Path -LiteralPath $describeWork -PathType Container) -and -not $KeepWorkspace.IsPresent) {
  Remove-Item -LiteralPath $describeWork -Recurse -Force
}
$describeParams = @{
  FixturePath = $fixtureCurrent
  ResultsRoot = $describeWork
  OutputPath  = $describeOut
  KeepWork    = $KeepWorkspace
}
if ($overlayResolved) {
  $describeParams['ResourceOverlayRoot'] = $overlayResolved
}
$summary = & (Join-Path $iconEditorToolsRoot 'Describe-IconEditorFixture.ps1') @describeParams

if (-not (Test-Path -LiteralPath $describeOut -PathType Leaf)) {
  Write-Host '    Report missing after describe; writing summary manually'
  $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $describeOut -Encoding utf8
}
if (-not $KeepWorkspace.IsPresent -and (Test-Path -LiteralPath $describeWork -PathType Container)) {
  Remove-Item -LiteralPath $describeWork -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "    Report: $describeOut"
$manifestCurrent = Join-Path $resultsRootResolved 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestCurrent -PathType Leaf)) {
  Write-Warning "Manifest not found at $manifestCurrent"
}

$viDiffRoot = Join-Path $resultsRootResolved 'vi-diff'
if (Test-Path -LiteralPath $viDiffRoot) {
  Remove-Item -LiteralPath $viDiffRoot -Recurse -Force
}
$prepareArgs = @{
  ReportPath          = $describeOut
  BaselineManifestPath= $baselineManifestResolved
  BaselineFixturePath = $baselineFixtureResolved
  OutputDir           = $viDiffRoot
}
if ($overlayResolved) {
  $prepareArgs['ResourceOverlayRoot'] = $overlayResolved
}
Write-Host '==> Preparing VI diff requests'
& (Join-Path $iconEditorToolsRoot 'Prepare-FixtureViDiffs.ps1') @prepareArgs | Out-Null

$requestsPath = Join-Path $viDiffRoot 'vi-diff-requests.json'
$requestCount = 0
if (Test-Path -LiteralPath $requestsPath -PathType Leaf) {
  $raw = Get-Content -LiteralPath $requestsPath -Raw | ConvertFrom-Json
  $requestCount = $raw.count
}
Write-Host "    Requests: $requestCount ($requestsPath)"

$capturesRoot = Join-Path $resultsRootResolved 'vi-diff-captures'
if (Test-Path -LiteralPath $capturesRoot) {
  Remove-Item -LiteralPath $capturesRoot -Recurse -Force
}

$skipCompare = $SkipLVCompare.IsPresent -or ($requestCount -le 0) -or $DryRun.IsPresent
if ($skipCompare) {
  Write-Host '==> Skipping LVCompare execution (dry-run)'
  & (Join-Path $iconEditorToolsRoot 'Invoke-FixtureViDiffs.ps1') `
    -RequestsPath $requestsPath `
    -CapturesRoot $capturesRoot `
    -SummaryPath (Join-Path $capturesRoot 'vi-comparison-summary.json') `
    -DryRun | Out-Null
} else {
  Write-Host '==> Running LVCompare on requests'
  & (Join-Path $iconEditorToolsRoot 'Invoke-FixtureViDiffs.ps1') `
    -RequestsPath $requestsPath `
    -CapturesRoot $capturesRoot `
    -SummaryPath (Join-Path $capturesRoot 'vi-comparison-summary.json') `
    -TimeoutSeconds 900 | Out-Null
}

$summaryPath = Join-Path $capturesRoot 'vi-comparison-summary.json'
if (Test-Path -LiteralPath $summaryPath -PathType Leaf) {
  & (Join-Path $iconEditorToolsRoot 'Render-ViComparisonReport.ps1') `
    -SummaryPath $summaryPath `
    -OutputPath (Join-Path $capturesRoot 'vi-comparison-report.md') | Out-Null
}

if ($IncludeSimulation.IsPresent) {
  Write-Host '==> Running simulation VIP diff (dry-run)'
  $simRoot = Join-Path $resultsRootResolved 'vip-vi-diff'
  if (Test-Path -LiteralPath $simRoot) { Remove-Item -LiteralPath $simRoot -Recurse -Force }
  $simulateParams = @{
    FixturePath      = $fixtureCurrent
    ResultsRoot      = $resultsRootResolved
    VipDiffOutputDir = $simRoot
    KeepExtract      = $KeepWorkspace
  }
  if ($overlayResolved) {
    $simulateParams['ResourceOverlayRoot'] = $overlayResolved
  }
  & (Join-Path $iconEditorToolsRoot 'Simulate-IconEditorBuild.ps1') @simulateParams | Out-Null
  $simRequests = Join-Path $simRoot 'vi-diff-requests.json'
  if (Test-Path -LiteralPath $simRequests -PathType Leaf) {
    & (Join-Path $iconEditorToolsRoot 'Invoke-FixtureViDiffs.ps1') `
      -RequestsPath $simRequests `
      -CapturesRoot (Join-Path $resultsRootResolved 'vip-vi-diff-captures') `
      -SummaryPath (Join-Path $resultsRootResolved 'vip-vi-diff-captures/vi-comparison-summary.json') `
      -DryRun | Out-Null
    & (Join-Path $iconEditorToolsRoot 'Render-ViComparisonReport.ps1') `
      -SummaryPath (Join-Path $resultsRootResolved 'vip-vi-diff-captures/vi-comparison-summary.json') `
      -OutputPath (Join-Path $resultsRootResolved 'vip-vi-diff-captures/vi-comparison-report.md') | Out-Null
  }
}

if (-not $DryRun.IsPresent) {
  Write-Host '==> Running PrePush checks'
  pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot 'tools/PrePush-Checks.ps1')

  Write-Host '==> Running targeted Pester suites'
  $pesterTests = @(
    'tests/Prepare-FixtureViDiffs.Tests.ps1',
    'tests/Prepare-VipViDiffRequests.Tests.ps1',
    'tests/Render-ViComparisonReport.Tests.ps1',
  'tests/Simulate-IconEditorVipDiff.Tests.ps1',
  'tests/Invoke-FixtureViDiffs.Tests.ps1',
  'tests/Simulate-IconEditorBuild.Tests.ps1',
  'tests/Stage-IconEditorSnapshot.Tests.ps1',
  'tests/Invoke-ValidateLocal.Tests.ps1'
)
  $invokeCmd = "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester -Path {0} -CI -Output Detailed" -f ($pesterTests -join ',')
  pwsh -NoLogo -NoProfile -Command $invokeCmd
} else {
  Write-Host '==> Dry run: skipping PrePush checks and targeted Pester suites'
}

Write-Host '==> Completed local Validate run'
Write-Host "    Fixture report : $describeOut"
Write-Host "    VI diff requests: $requestsPath"
Write-Host "    Compare captures: $capturesRoot"
Write-Host "    Compare summary : $summaryPath"
Write-Host "    PrePush logs    : see execution output"
Write-Host "    Pester summary  : tests/results/pester-summary.json (if generated)"

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
