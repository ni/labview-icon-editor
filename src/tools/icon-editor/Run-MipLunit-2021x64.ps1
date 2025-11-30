Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
#Requires -Version 7.0

<#
.SYNOPSIS
  Orchestrates Scenario 6b (legacy MIP 2021 x64 + LUnit) end-to-end.

.DESCRIPTION
  Runs a guarded MissingInProject suite with the VI Analyzer gate targeting LabVIEW 2021 x64,
  then executes LabVIEW unit tests via the run-unit-tests helper (also 2021 x64). Writes a
  compact integration summary JSON capturing key artifact paths and statuses.

.PARAMETER ProjectPath
  Path to the icon-editor .lvproj used for LUnit. Defaults to vendor/icon-editor/lv_icon_editor.lvproj.

.PARAMETER AnalyzerConfigPath
  Path to the VI Analyzer config for the MissingInProject suite.

.PARAMETER ResultsPath
  Root results directory (default tests/results).

.PARAMETER AutoCloseWrongLV
  When set, automatically close rogue/non-expected LabVIEW instances before starting.

.PARAMETER DryRun
  Print planned commands without executing them.
#>
[CmdletBinding()]
param(
  [string]$ProjectPath = 'vendor/icon-editor/lv_icon_editor.lvproj',
  [string]$AnalyzerConfigPath = 'configs/vi-analyzer/missing-in-project.viancfg',
  [string]$ResultsPath = 'tests/results',
  [switch]$AutoCloseWrongLV,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$helperModule = Join-Path $PSScriptRoot 'MipScenarioHelpers.psm1'
if (-not (Test-Path -LiteralPath $helperModule -PathType Leaf)) {
  throw "Helper module not found at '$helperModule'."
}
Import-Module $helperModule -Force

function Ensure-VendorTools {
  if (Get-Command -Name Find-LabVIEWVersionExePath -ErrorAction SilentlyContinue) { return }
  $modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'VendorTools.psm1'
  if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "Vendor tools module not found at '$modulePath'."
  }
  Import-Module $modulePath -Force
}

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if ($repoRoot) { $repoRoot = (Resolve-Path $repoRoot).Path } else { $repoRoot = (Get-Location).Path }

$projAbs = Resolve-Abs $ProjectPath
$cfgAbs  = Resolve-Abs $AnalyzerConfigPath
if (-not (Test-Path -LiteralPath $projAbs -PathType Leaf)) { throw "Project not found: $ProjectPath" }
if (-not (Test-Path -LiteralPath $cfgAbs -PathType Leaf)) { throw "Analyzer config not found: $AnalyzerConfigPath" }

$resultsAbs = if ([System.IO.Path]::IsPathRooted($ResultsPath)) { $ResultsPath } else { Join-Path $repoRoot $ResultsPath }
if (-not (Test-Path -LiteralPath $resultsAbs -PathType Container)) { [void](New-Item -ItemType Directory -Path $resultsAbs -Force) }

$label = "mip-legacy-labtest-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')
$summaryDir = Join-Path $resultsAbs '_agent' 'reports' 'integration'
if (-not (Test-Path -LiteralPath $summaryDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $summaryDir -Force) }
$summaryPath = Join-Path $summaryDir ("{0}.json" -f $label)

$summaryData = [ordered]@{
  schema = 'integration/mip-lunit-legacy@v1'
  label = $label
  resultsRoot = $resultsAbs
  status = 'pending'
  checks = [ordered]@{
    toolkit = [ordered]@{ status = 'pending'; version = 2021; bitness = 64; path = $null; labviewExe = $null; reason = $null }
    gcli = [ordered]@{ status = 'pending'; version = $null; reason = $null }
    labviewServer = [ordered]@{ status = 'pending'; iniPath = $null; enabled = $null; port = $null; warnings = @() }
  }
  analyzer = [ordered]@{ status = 'pending'; label = $label; logPath = $null; reportDir = $null; note = $null }
  mipReport = $null
  unit = [ordered]@{ status = 'pending'; total = $null; passed = $null; failed = $null; skipped = $null; reportPath = $null; note = $null }
  generatedAt = $null
}

function Save-IntegrationSummary {
  param([string]$Status = $null)
  if ($Status) { $summaryData.status = $Status }
  $summaryData.generatedAt = (Get-Date).ToString('o')
  $summaryData | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $summaryPath -Encoding utf8
}

Save-IntegrationSummary -Status 'pending'

try {
  $detectScript = Join-Path $repoRoot 'tools' 'Detect-RogueLV.ps1'
  if (Test-Path -LiteralPath $detectScript -PathType Leaf) {
    & $detectScript -FailOnRogue -Quiet | Out-Null
  }
} catch {
  Write-Host "[6b] ERROR: Rogue LV detection failed: $($_.Exception.Message)" -ForegroundColor Red
  throw
}

function Write-AnalyzerFindings {
  param(
    [string]$AnalyzerDir,
    [string]$Prefix = '[6b]'
  )
  if (-not $AnalyzerDir) { return }
  $jsonPath = Join-Path $AnalyzerDir 'vi-analyzer.json'
  if (-not (Test-Path -LiteralPath $jsonPath -PathType Leaf)) { return }
  try {
    $data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    $alreadyPrinted = $false
    if ($data.PSObject.Properties['summaryPrinted']) {
      $alreadyPrinted = [bool]$data.summaryPrinted
    }
    $summaryData.analyzer.findings = @{
      failureCount = $data.failureCount
      brokenViCount = $data.brokenViCount
    }
    if ($alreadyPrinted) { return }
    $failures = @()
    if ($data.failures) {
      $failures = $data.failures | Select-Object -First 5
    }
    if ($failures.Count -gt 0) {
      Write-Host ("{0} VI Analyzer top failures:" -f $Prefix) -ForegroundColor DarkGray
      foreach ($entry in $failures) {
        Write-Host ("{0}   {1} :: {2} :: {3}" -f $Prefix, $entry.vi, $entry.test, $entry.details) -ForegroundColor DarkGray
      }
      if ($data.failureCount -gt $failures.Count) {
        Write-Host ("{0}   ... {1} additional failures" -f $Prefix, ($data.failureCount - $failures.Count)) -ForegroundColor DarkGray
      }
    }
    if ($data.failureCount -gt 0 -and $data.cliLogPath -and (Test-Path -LiteralPath $data.cliLogPath -PathType Leaf)) {
      if (-not $summaryData.analyzer.logPath) {
        $summaryData.analyzer.logPath = $data.cliLogPath
      }
      $tail = Get-Content -LiteralPath $data.cliLogPath -Tail 15
      Write-Host ("{0} Analyzer CLI log tail:" -f $Prefix) -ForegroundColor DarkGray
      foreach ($line in $tail) {
        Write-Host ("{0}   {1}" -f $Prefix, $line.TrimEnd()) -ForegroundColor DarkGray
      }
    }
  } catch {
    Write-Host ("{0} Unable to summarize analyzer findings: {1}" -f $Prefix, $_.Exception.Message) -ForegroundColor DarkGray
  }
}

$toolkitCheckDone = $false
Ensure-VendorTools
$toolkitInfo = Test-VIAnalyzerToolkit -Version 2021 -Bitness 64
if (-not $toolkitInfo.exists) {
  Write-Host "[6b] VI Analyzer Toolkit check failed: $($toolkitInfo.reason)" -ForegroundColor Yellow
  Write-Host "[6b] Install 'LabVIEW 2021 VI Analyzer' via NI Package Manager and rerun." -ForegroundColor Yellow
  $summaryData.checks.toolkit.status = 'missing'
  $summaryData.checks.toolkit.reason = $toolkitInfo.reason
  Save-IntegrationSummary -Status 'failed'
  exit 2
} else {
  $toolkitCheckDone = $true
  $summaryData.checks.toolkit.status = 'ok'
  $summaryData.checks.toolkit.path = $toolkitInfo.toolkitPath
  $summaryData.checks.toolkit.labviewExe = $toolkitInfo.labviewExe
  Write-Host ("[6b] Detected VI Analyzer Toolkit at {0}" -f $toolkitInfo.toolkitPath) -ForegroundColor DarkGray
}

$gcliInfo = Test-GCliAvailable
if (-not $gcliInfo.available) {
  Write-Host "[6b] g-cli check failed: $($gcliInfo.reason)" -ForegroundColor Yellow
  Write-Host "[6b] Install g-cli 3.x and ensure it is on PATH before rerunning." -ForegroundColor Yellow
  $summaryData.checks.gcli.status = 'missing'
  $summaryData.checks.gcli.reason = $gcliInfo.reason
  Save-IntegrationSummary -Status 'failed'
  exit 5
} else {
  $summaryData.checks.gcli.status = 'ok'
  $summaryData.checks.gcli.version = $gcliInfo.version
  Write-Host ("[6b] g-cli detected ({0})" -f $gcliInfo.version) -ForegroundColor DarkGray
}

$serverInfo = Get-LabVIEWServerInfo -LabVIEWExePath $toolkitInfo.labviewExe
$summaryData.checks.labviewServer.status = if ($serverInfo.enabled) { 'ok' } else { 'warn' }
$summaryData.checks.labviewServer.iniPath = $serverInfo.iniPath
$summaryData.checks.labviewServer.enabled = $serverInfo.enabled
$summaryData.checks.labviewServer.port = $serverInfo.port
$summaryData.checks.labviewServer.warnings = $serverInfo.warnings
if (-not $serverInfo.enabled) {
  Write-Host "[6b] WARNING: LabVIEW VI Server appears disabled (server.tcp.enabled <> 1)." -ForegroundColor Yellow
}

[Environment]::SetEnvironmentVariable('MIP_EXPECTED_LV_VER','2021','Process')
[Environment]::SetEnvironmentVariable('MIP_EXPECTED_ARCH','64','Process')
[Environment]::SetEnvironmentVariable('MIP_ROGUE_PREFLIGHT','1','Process')
[Environment]::SetEnvironmentVariable('MIP_AUTOCLOSE_WRONG_LV','1','Process')

# Rogue preflight
$preflight = $null
try {
  $detectScript = Join-Path $repoRoot 'tools' 'Detect-RogueLV.ps1'
  if (Test-Path -LiteralPath $detectScript -PathType Leaf) {
    $prefOut = & $detectScript -ResultsDir $resultsAbs -LookBackSeconds 180 -RetryCount 1 -Quiet
    if ($prefOut) { $preflight = $prefOut | ConvertFrom-Json }
    if ($AutoCloseWrongLV.IsPresent -and $preflight -and $preflight.rogue.labview.Count -gt 0) {
      $closeScript = Join-Path $repoRoot 'tools' 'Close-LabVIEW.ps1'
      foreach ($entry in $preflight.liveDetails.labview) {
        $exe = $entry.executablePath
        if ($exe -and $exe -match 'LabVIEW.*2021' -and -not ($exe -match '\(x86\)')) { continue }
        try { & $closeScript -LabVIEWExePath $exe -Provider 'labviewcli' | Out-Null } catch {}
      }
    }
  }
} catch {}

Write-Host "[6b] Analyzer-gated MIP (2021/64) + LUnit orchestration" -ForegroundColor Cyan

if ($DryRun) {
  Write-Host "DRY RUN: would run analyzer-gated MIP and LUnit." -ForegroundColor DarkYellow
  Write-Host "- Label: $label"
  Write-Host "- Analyzer config: $cfgAbs"
  Write-Host "- Project: $projAbs"
  return
}

# Step 1: Analyzer-gated MIP (2021 x64)
$env:MIP_ALLOW_LEGACY = '1'
$mipScript = Join-Path $repoRoot 'tools' 'icon-editor' 'Invoke-MissingInProjectSuite.ps1'
if (-not (Test-Path -LiteralPath $mipScript -PathType Leaf)) { throw "Missing script: $mipScript" }

$mipArgs = @(
  '-Label', $label,
  '-ResultsPath', $resultsAbs,
  '-RequireCompareReport',
  '-ViAnalyzerConfigPath', $cfgAbs,
  '-ViAnalyzerVersion', '2021',
  '-ViAnalyzerBitness', '64'
)

$latestAnalyzerDir = $null
try {
  & pwsh -NoLogo -NoProfile -File $mipScript @mipArgs
  $summaryData.analyzer.status = 'ok'
  $summaryData.analyzer.note = 'completed'
  $analyzerRoot = Join-Path $resultsAbs 'vi-analyzer'
  if (Test-Path -LiteralPath $analyzerRoot -PathType Container) {
    $latestAnalyzerDir = Get-ChildItem -LiteralPath $analyzerRoot -Directory -Filter 'vi-analyzer-*' |
      Sort-Object LastWriteTimeUtc | Select-Object -Last 1
    if ($latestAnalyzerDir) {
      $summaryData.analyzer.reportDir = $latestAnalyzerDir.FullName
      $cliLog = Join-Path $latestAnalyzerDir.FullName 'vi-analyzer-cli.log'
      if (Test-Path -LiteralPath $cliLog -PathType Leaf) {
        $summaryData.analyzer.logPath = $cliLog
      }
      Write-AnalyzerFindings -AnalyzerDir $latestAnalyzerDir.FullName
    }
  }
  Save-IntegrationSummary -Status 'pending'
} catch {
  $message = $_.Exception.Message
  Write-Host "[6b] ERROR: MissingInProject suite failed: $message" -ForegroundColor Red
  $summaryData.analyzer.status = 'failed'
  $summaryData.analyzer.note = $message
  $lastAnalyzerRun = Join-Path $resultsAbs 'vi-analyzer'
  try {
    $latestAnalyzerDir = Get-ChildItem -LiteralPath $lastAnalyzerRun -Directory -Filter 'vi-analyzer-*' |
      Sort-Object LastWriteTimeUtc | Select-Object -Last 1
    if ($latestAnalyzerDir) {
      Write-Host ("[6b] See analyzer logs under {0}" -f $latestAnalyzerDir.FullName) -ForegroundColor DarkGray
      $cliLogPath = Join-Path $latestAnalyzerDir.FullName 'vi-analyzer-cli.log'
      $summaryData.analyzer.reportDir = $latestAnalyzerDir.FullName
      if (Test-Path -LiteralPath $cliLogPath -PathType Leaf) {
        $summaryData.analyzer.logPath = $cliLogPath
      }
      Write-AnalyzerFindings -AnalyzerDir $latestAnalyzerDir.FullName
      if (Test-Path -LiteralPath $cliLogPath -PathType Leaf) {
        Write-Host "[6b] Last 10 lines from analyzer CLI log:" -ForegroundColor DarkGray
        Get-Content -LiteralPath $cliLogPath -Tail 10 | ForEach-Object { Write-Host ('[6b]   ' + $_) }
      }
    }
    Write-AnalyzerDevModeWarning -AnalyzerDir $latestAnalyzerDir.FullName -Prefix '[6b]' | Out-Null
  } catch {}
  if ($message -match '-350053') {
    Write-Host "[6b] VI Analyzer returned error -350053 (missing or broken toolkit). Install/repair the VI Analyzer Toolkit for LabVIEW 2021 (64-bit) and rerun." -ForegroundColor Yellow
  } elseif ($message -match 'VI Analyzer report not found') {
    Write-Host "[6b] Analyzer did not emit a report (exit code 1). Review the log above for failed tests, fix the violations, or scope the .viancfg to known-good VIs before rerunning." -ForegroundColor Yellow
  }
  Save-IntegrationSummary -Status 'failed'
  exit 3
}

# Discover MIP report
$mipReportsDir = Join-Path $resultsAbs '_agent' 'reports' 'missing-in-project'
$mipReport = $null
if (Test-Path -LiteralPath $mipReportsDir -PathType Container) {
  $mipReport = Get-ChildItem -LiteralPath $mipReportsDir -Filter ("{0}-*.json" -f $label) |
    Sort-Object LastWriteTimeUtc | Select-Object -Last 1
}
if (-not $mipReport) {
  $summaryData.analyzer.note = 'missing MIP report'
  Save-IntegrationSummary -Status 'failed'
  throw "MIP report not found for label $label under $mipReportsDir"
}
$summaryData.mipReport = $mipReport.FullName
Save-IntegrationSummary -Status 'pending'

# Step 2: LUnit (2021 x64)
$unitScript = Join-Path $repoRoot '.github' 'actions' 'run-unit-tests' 'RunUnitTests.ps1'
if (-not (Test-Path -LiteralPath $unitScript -PathType Leaf)) { throw "Missing script: $unitScript" }

$unitArgs = @(
  '-MinimumSupportedLVVersion','2021',
  '-SupportedBitness','64',
  '-ProjectPath', $projAbs,
  '-ReportLabel', ('iconeditor-lunit-legacy-{0}' -f (Get-Date -Format 'yyyyMMddTHHmmss'))
)

$unitOutput = & pwsh -NoLogo -NoProfile -File $unitScript @unitArgs 2>&1
$unitExitCode = $LASTEXITCODE
$unitOutput | ForEach-Object { Write-Host $_ }
$unitSummaryLine = $unitOutput | Where-Object { $_ -match 'Total:\s*\d+' } | Select-Object -Last 1
$unitReportPath = Get-ReportPathFromOutput -Lines $unitOutput
if ($unitSummaryLine) {
  Write-Host ("[6b] LUnit summary: {0}" -f ($unitSummaryLine.Trim())) -ForegroundColor DarkGray
}
if ($unitReportPath) {
  Write-Host ("[6b] LUnit report: {0}" -f $unitReportPath) -ForegroundColor DarkGray
  $summaryData.unit.reportPath = $unitReportPath
}
$unitTotals = $null
if ($unitSummaryLine -and ($unitSummaryLine -match 'Total:\s*(\d+).+?Passed:\s*(\d+).+?Failed:\s*(\d+).+?Skipped:\s*(\d+)')) {
  $unitTotals = @{
    total = [int]$Matches[1]
    passed = [int]$Matches[2]
    failed = [int]$Matches[3]
    skipped = [int]$Matches[4]
  }
}
if ($unitExitCode -ne 0) {
  Write-Host "[6b] LUnit run failed. Review output above for details." -ForegroundColor Red
  $summaryData.unit.status = 'failed'
  $summaryData.unit.note = "exit code $unitExitCode"
  if ($unitTotals) {
    $summaryData.unit.total = $unitTotals.total
    $summaryData.unit.passed = $unitTotals.passed
    $summaryData.unit.failed = $unitTotals.failed
    $summaryData.unit.skipped = $unitTotals.skipped
  }
  Save-IntegrationSummary -Status 'failed'
  exit 4
}
$summaryData.unit.status = 'ok'
$summaryData.unit.note = 'completed'
if ($unitTotals) {
  $summaryData.unit.total = $unitTotals.total
  $summaryData.unit.passed = $unitTotals.passed
  $summaryData.unit.failed = $unitTotals.failed
  $summaryData.unit.skipped = $unitTotals.skipped
}
$summaryData.status = 'passed'
Save-IntegrationSummary -Status 'passed'
Write-Host ("Integration summary: {0}" -f $summaryPath) -ForegroundColor DarkGray
exit 0

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