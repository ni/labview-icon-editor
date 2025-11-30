Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
#Requires -Version 7.0
[CmdletBinding()]
param(
  [int]$LabVIEWVersion = 2021,
  [ValidateSet(32, 64)][int]$Bitness = 64,
  [ValidateRange(1, 20)][int]$Iterations = 3,
  [string]$DevModeOperation = 'Reliability',
  [string]$RepoRoot,
  [string]$ResultsRoot = 'tests/results',
  [string]$EnableScriptPath,
  [string]$DisableScriptPath,
  [string]$ScenarioScriptPath,
  [string]$ScenarioProjectPath,
  [string]$ScenarioAnalyzerConfigPath,
  [string]$ScenarioResultsPath,
  [bool]$ScenarioAutoCloseWrongLV = $true,
  [bool]$ScenarioDryRun = $false,
  [string[]]$ScenarioAdditionalArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:failureMessage = $null

function Resolve-RepoRoot {
  param([string]$Override)
  if ($Override) {
    return (Resolve-Path -LiteralPath $Override).Path
  }
  Import-Module (Join-Path $PSScriptRoot 'IconEditorDevMode.psm1') -Force
  return Resolve-IconEditorRepoRoot
}

function Resolve-IconEditorRoot {
  param([string]$RepoRoot)
  return Resolve-Path -LiteralPath (Join-Path $RepoRoot 'vendor' 'icon-editor')
}

function Resolve-ScriptPath {
  param(
    [string]$Path,
    [string]$DefaultRelative,
    [string]$RepoRoot
  )
  $candidate = $Path
  if (-not $candidate) {
    $candidate = Join-Path $RepoRoot $DefaultRelative
  }
  return (Resolve-Path -LiteralPath $candidate).Path
}

function Get-LatestDevModeRunPath {
  param([string]$RunDir)
  if (-not (Test-Path -LiteralPath $RunDir -PathType Container)) {
    return $null
  }
  $latest = Get-ChildItem -LiteralPath $RunDir -Filter 'dev-mode-run-*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($latest) {
    return $latest.FullName
  }
  return $null
}

function Get-ExternalExitCode {
  $var = Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue
  if ($null -ne $var) {
    return [int]$var.Value
  }
  return 0
}

function Get-NewAnalyzerRun {
  param(
    [string]$AnalyzerRoot,
    [string[]]$ExistingPaths
  )
  if (-not (Test-Path -LiteralPath $AnalyzerRoot -PathType Container)) {
    return $null
  }
  $dirs = Get-ChildItem -LiteralPath $AnalyzerRoot -Directory -ErrorAction SilentlyContinue
  if (-not $dirs) { return $null }
  $newDirs = @()
  if ($ExistingPaths) {
    $existingSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$ExistingPaths)
    foreach ($dir in $dirs) {
      if (-not $existingSet.Contains($dir.FullName)) {
        $newDirs += $dir
      }
    }
  }
  $target = if ($newDirs.Count -gt 0) {
    $newDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  } else {
    $dirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  }
  if ($target) {
    return $target.FullName
  }
  return $null
}

function Save-StabilitySummary {
  param(
    [string]$Path,
    [string]$LatestPath,
    [hashtable]$Summary
  )
  $Summary.generatedAt = (Get-Date).ToString('o')
  $json = $Summary | ConvertTo-Json -Depth 7
  $json | Set-Content -LiteralPath $Path -Encoding utf8
  $json | Set-Content -LiteralPath $LatestPath -Encoding utf8
}

function Get-DevModeTelemetryPayload {
  param([string]$Path)
  if (-not $Path) {
    throw "Dev-mode telemetry path was not provided."
  }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Dev-mode telemetry file '$Path' was not found."
  }
  try {
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Failed to parse dev-mode telemetry '$Path': $($_.Exception.Message)"
  }
}

function Analyze-DevModeRunTelemetry {
  param(
    [psobject]$Telemetry,
    [ValidateSet('enable','disable')][string]$ExpectedMode,
    [switch]$RequireVerification
  )

  if (-not $Telemetry) {
    throw "Dev-mode telemetry payload was empty for the $ExpectedMode stage."
  }

  if ($Telemetry.PSObject.Properties['mode']) {
    $modeValue = $Telemetry.mode
    if ($modeValue -and $modeValue -ne $ExpectedMode) {
      throw ("Dev-mode telemetry '{0}' reported mode '{1}' but expected '{2}'." -f $Telemetry.label, $modeValue, $ExpectedMode)
    }
  }

  $analysis = [ordered]@{
    settleSeconds = $null
    settleFailed = $false
    settleFailureReason = $null
    devModeVerified = if ($RequireVerification) { $false } else { $null }
    verificationFailureReason = $null
  }

  $settleSummary = $null
  if ($Telemetry.PSObject.Properties['settleSummary']) {
    $settleSummary = $Telemetry.settleSummary
  } elseif ($Telemetry.PSObject.Properties['stages']) {
    $allEvents = @()
    foreach ($stage in $Telemetry.stages) {
      if ($stage -and $stage.settleEvents) {
        $allEvents += $stage.settleEvents
      }
    }
    if ($allEvents.Count -gt 0) {
      $settleSummary = Get-IconEditorSettleSummary -Events $allEvents
    }
  }

  if ($settleSummary) {
    if ($settleSummary.PSObject.Properties['totalDurationSeconds']) {
      $analysis.settleSeconds = [double]$settleSummary.totalDurationSeconds
    }
    $failedCount = $null
    if ($settleSummary.PSObject.Properties['failedEvents']) {
      $failedCount = [int]$settleSummary.failedEvents
    } elseif ($settleSummary.PSObject.Properties['failed']) {
      $failedCount = [int]$settleSummary.failed
    }
    if ($failedCount -and $failedCount -gt 0) {
      $analysis.settleFailed = $true
      if ($settleSummary.PSObject.Properties['failedStages'] -and $settleSummary.failedStages) {
        $analysis.settleFailureReason = "Failed settle stages: {0}" -f ([string]::Join(', ', $settleSummary.failedStages))
      }
    }
  } elseif ($Telemetry.PSObject.Properties['settleSeconds']) {
    $analysis.settleSeconds = [double]$Telemetry.settleSeconds
  }

  if ($RequireVerification) {
    $verificationSummary = $null
    if ($Telemetry.PSObject.Properties['verificationSummary']) {
      $verificationSummary = $Telemetry.verificationSummary
    } elseif ($Telemetry.PSObject.Properties['verification']) {
      $verificationSummary = Get-IconEditorVerificationSummary -Verification $Telemetry.verification
    }

    if (-not $verificationSummary) {
      $analysis.verificationFailureReason = 'Verification summary missing from telemetry.'
    } else {
      $presentCount = if ($verificationSummary.PSObject.Properties['presentCount']) { [int]$verificationSummary.presentCount } else { 0 }
      $containsCount = if ($verificationSummary.PSObject.Properties['containsIconEditorCount']) { [int]$verificationSummary.containsIconEditorCount } else { 0 }
      $activeFlag = $verificationSummary.active
      if ($presentCount -le 0) {
        $analysis.verificationFailureReason = 'No LabVIEW targets reported in verification summary.'
      } elseif (-not $activeFlag -or $containsCount -lt $presentCount) {
        if ($verificationSummary.PSObject.Properties['missingTargets'] -and $verificationSummary.missingTargets) {
          $missingDescriptions = @(
            $verificationSummary.missingTargets | ForEach-Object {
              if ($_ -and $_.version -and $_.bitness) {
                "LV {0} ({1}-bit)" -f $_.version, $_.bitness
              } else {
                $null
              }
            } | Where-Object { $_ }
          )
          if ($missingDescriptions -and $missingDescriptions.Count -gt 0) {
            $analysis.verificationFailureReason = "Missing icon-editor path for {0}." -f ([string]::Join(', ', $missingDescriptions))
          } else {
            $analysis.verificationFailureReason = 'Verification summary indicates icon-editor path was removed.'
          }
        } else {
          $analysis.verificationFailureReason = 'Verification summary indicates icon-editor path was removed.'
        }
      } else {
        $analysis.devModeVerified = $true
      }
    }
  }

  return $analysis
}

Import-Module (Join-Path $PSScriptRoot 'IconEditorDevMode.psm1') -Force
$resolvedRepoRoot = Resolve-RepoRoot -Override $RepoRoot
$iconEditorRootInfo = Resolve-IconEditorRoot -RepoRoot $resolvedRepoRoot
if ($null -eq $iconEditorRootInfo) {
  throw "Could not resolve icon-editor root under repo '$resolvedRepoRoot'."
} elseif ($iconEditorRootInfo -is [string]) {
  $iconEditorRoot = $iconEditorRootInfo
} elseif ($iconEditorRootInfo.PSObject.Properties['Path']) {
  $iconEditorRoot = $iconEditorRootInfo.Path
} else {
  $iconEditorRoot = [string]$iconEditorRootInfo
}

$enableScript = Resolve-ScriptPath -Path $EnableScriptPath -DefaultRelative 'tools/icon-editor/Enable-DevMode.ps1' -RepoRoot $resolvedRepoRoot
$disableScript = Resolve-ScriptPath -Path $DisableScriptPath -DefaultRelative 'tools/icon-editor/Disable-DevMode.ps1' -RepoRoot $resolvedRepoRoot
$scenarioScript = Resolve-ScriptPath -Path $ScenarioScriptPath -DefaultRelative 'tools/icon-editor/Run-MipLunit-2021x64.ps1' -RepoRoot $resolvedRepoRoot

$resultsRootAbs = if ([System.IO.Path]::IsPathRooted($ResultsRoot)) { $ResultsRoot } else { Join-Path $resolvedRepoRoot $ResultsRoot }
if (-not (Test-Path -LiteralPath $resultsRootAbs -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $resultsRootAbs | Out-Null
}

$stabilityRoot = Join-Path $resultsRootAbs '_agent' 'icon-editor' 'dev-mode-stability'
if (-not (Test-Path -LiteralPath $stabilityRoot -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $stabilityRoot | Out-Null
}

$label = "dev-mode-stability-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmssfff')
$summaryPath = Join-Path $stabilityRoot ("{0}.json" -f $label)
$summaryLatestPath = Join-Path $stabilityRoot 'latest-run.json'

$summary = [ordered]@{
  schema = 'icon-editor/dev-mode-stability@v1'
  label = $label
  labview = [ordered]@{
    version = $LabVIEWVersion
    bitness = $Bitness
    operation = $DevModeOperation
  }
  resultsRoot = $resultsRootAbs
  iterationsRequested = $Iterations
  iterations = @()
  status = 'pending'
  failure = $null
}
$requiredConsecutive = 3
$summary.requirements = [ordered]@{
  consecutiveVerifiedRequired = $requiredConsecutive
  maxConsecutiveVerified = 0
  met = $false
}

$scenarioParams = @{}
if ($ScenarioProjectPath) {
  $scenarioParams['ProjectPath'] = $ScenarioProjectPath
}
if ($ScenarioAnalyzerConfigPath) {
  $scenarioParams['AnalyzerConfigPath'] = $ScenarioAnalyzerConfigPath
}
if ($ScenarioResultsPath) {
  $scenarioParams['ResultsPath'] = $ScenarioResultsPath
}
if ($ScenarioAutoCloseWrongLV) {
  $scenarioParams['AutoCloseWrongLV'] = $true
}
if ($ScenarioDryRun) {
  $scenarioParams['DryRun'] = $true
}

$viAnalyzerRoot = Join-Path $resultsRootAbs 'vi-analyzer'
$devModeRunDir = Join-Path $resultsRootAbs '_agent' 'icon-editor' 'dev-mode-run'

$failed = $false
$consecutiveVerified = 0

for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
  $iterationStart = Get-Date
  $iterationData = [ordered]@{
    iteration = $iteration
    startedAt = $iterationStart.ToString('o')
    status = 'pending'
    enable = [ordered]@{}
    analyzer = [ordered]@{}
    disable = [ordered]@{}
  }

  try {
    $beforeAnalyzerDirs = @()
    if (Test-Path -LiteralPath $viAnalyzerRoot -PathType Container) {
      $beforeAnalyzerDirs = (Get-ChildItem -LiteralPath $viAnalyzerRoot -Directory -ErrorAction SilentlyContinue).FullName
    }

    Write-Host ("[stability] Detecting rogue LabVIEW instances before iteration {0}." -f $iteration)
    $rogueScript = Join-Path $resolvedRepoRoot 'tools/Detect-RogueLV.ps1'
    if (Test-Path -LiteralPath $rogueScript -PathType Leaf) {
      try {
        & $rogueScript -FailOnRogue -ResultsDir $resultsRootAbs | Out-Null
      } catch {
        Write-Warning ("[stability] Rogue detection before iteration {0} reported: {1}" -f $iteration, $_.Exception.Message)
        $rogueNotice = Join-Path $resultsRootAbs '_agent/icon-editor/rogue-lv'
        if (Test-Path -LiteralPath $rogueNotice -PathType Container) {
          Get-ChildItem -LiteralPath $rogueNotice -Filter 'rogue-*.json' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 3 |
            ForEach-Object { Write-Host ("[stability] Rogue artifact: {0}" -f $_.FullName) }
        }
        $live = @(Get-Process LabVIEW -ErrorAction SilentlyContinue)
        if ($live.Count -gt 0) {
          Write-Warning ("[stability] Forcing termination of LabVIEW PIDs {0} before continuing." -f ($live.Id -join ','))
          foreach ($proc in $live) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch {}
          }
        }
        throw
      }
    }

    $enableWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $global:LASTEXITCODE = 0
    & $enableScript -RepoRoot $resolvedRepoRoot -IconEditorRoot $iconEditorRoot -Versions $LabVIEWVersion -Bitness $Bitness -Operation $DevModeOperation
    $enableExit = Get-ExternalExitCode
    $enableWatch.Stop()
    $iterationData.enable.durationSeconds = [math]::Round($enableWatch.Elapsed.TotalSeconds, 2)
    $iterationData.enable.exitCode = $enableExit
    $iterationData.enable.telemetryPath = Get-LatestDevModeRunPath -RunDir $devModeRunDir
    if ($enableExit -ne 0) {
      throw "Enable-DevMode script exited with $enableExit."
    }
    $enableTelemetry = Get-DevModeTelemetryPayload -Path $iterationData.enable.telemetryPath
    $enableAnalysis = Analyze-DevModeRunTelemetry -Telemetry $enableTelemetry -ExpectedMode 'enable' -RequireVerification
    $iterationData.enable.settleSeconds = $enableAnalysis.settleSeconds
    $iterationData.enable.devModeVerified = $enableAnalysis.devModeVerified
    if ($enableAnalysis.settleFailed) {
      $reason = if ($enableAnalysis.settleFailureReason) { $enableAnalysis.settleFailureReason } else { 'Settle summary reported failures.' }
      throw "Enable-stage settle failed: $reason"
    }
    if (-not $enableAnalysis.devModeVerified) {
      $reason = if ($enableAnalysis.verificationFailureReason) { $enableAnalysis.verificationFailureReason } else { 'Dev-mode verification missing.' }
      throw "Dev-mode verification failed: $reason"
    }

    $scenarioWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $global:LASTEXITCODE = 0
    if ($ScenarioAdditionalArguments -and $ScenarioAdditionalArguments.Count -gt 0) {
      if ($scenarioParams.Count -gt 0) {
        & $scenarioScript @scenarioParams @ScenarioAdditionalArguments
      } else {
        & $scenarioScript @ScenarioAdditionalArguments
      }
    } elseif ($scenarioParams.Count -gt 0) {
      & $scenarioScript @scenarioParams
    } else {
      & $scenarioScript
    }
    $scenarioExit = Get-ExternalExitCode
    $scenarioWatch.Stop()
    $iterationData.analyzer.durationSeconds = [math]::Round($scenarioWatch.Elapsed.TotalSeconds, 2)
    $iterationData.analyzer.exitCode = $scenarioExit

    $newAnalyzerDir = Get-NewAnalyzerRun -AnalyzerRoot $viAnalyzerRoot -ExistingPaths $beforeAnalyzerDirs
    if ($newAnalyzerDir) {
      $iterationData.analyzer.reportDir = $newAnalyzerDir
      $jsonPath = Join-Path $newAnalyzerDir 'vi-analyzer.json'
      if (Test-Path -LiteralPath $jsonPath -PathType Leaf) {
        try {
          $analyzerData = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
          $iterationData.analyzer.analyzerExitCode = $analyzerData.exitCode
          if ($analyzerData.PSObject.Properties['devModeLikelyDisabled']) {
            $iterationData.analyzer.devModeLikelyDisabled = [bool]$analyzerData.devModeLikelyDisabled
          }
        } catch {
          $iterationData.analyzer.notes = "Failed to parse analyzer JSON: $($_.Exception.Message)"
        }
      } else {
        $iterationData.analyzer.notes = 'Analyzer JSON not found.'
      }
    } else {
      $iterationData.analyzer.notes = 'No analyzer output detected.'
    }

    if ($scenarioExit -ne 0) {
      throw "Scenario script exited with $scenarioExit."
    }
    if ($iterationData.analyzer.devModeLikelyDisabled) {
      throw "Analyzer reported dev mode disabled (MissingInProjectCLI flag)."
    }

    $disableWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $global:LASTEXITCODE = 0
    & $disableScript -RepoRoot $resolvedRepoRoot -IconEditorRoot $iconEditorRoot -Versions $LabVIEWVersion -Bitness $Bitness -Operation $DevModeOperation | Out-Null
    $disableExit = Get-ExternalExitCode
    $disableWatch.Stop()
    $iterationData.disable.durationSeconds = [math]::Round($disableWatch.Elapsed.TotalSeconds, 2)
    $iterationData.disable.exitCode = $disableExit
    $iterationData.disable.telemetryPath = Get-LatestDevModeRunPath -RunDir $devModeRunDir
    if ($disableExit -ne 0) {
      throw "Disable-DevMode script exited with $disableExit."
    }
    $disableTelemetry = Get-DevModeTelemetryPayload -Path $iterationData.disable.telemetryPath
    $disableAnalysis = Analyze-DevModeRunTelemetry -Telemetry $disableTelemetry -ExpectedMode 'disable'
    $iterationData.disable.settleSeconds = $disableAnalysis.settleSeconds
    if ($disableAnalysis.settleFailed) {
      $reason = if ($disableAnalysis.settleFailureReason) { $disableAnalysis.settleFailureReason } else { 'Settle summary reported failures.' }
      throw "Disable-stage settle failed: $reason"
    }

    $iterationData.status = 'ok'
    $consecutiveVerified += 1
    if ($consecutiveVerified -gt $summary.requirements.maxConsecutiveVerified) {
      $summary.requirements.maxConsecutiveVerified = $consecutiveVerified
    }
  } catch {
    $iterationData.status = 'failed'
    $iterationData.error = $_.Exception.Message
    $summary.failure = [ordered]@{
      iteration = $iteration
      reason = $_.Exception.Message
    }
    $summary.status = 'failed'
    $failed = $true
    $summary.iterations += $iterationData
    $consecutiveVerified = 0
    break
  }

  if ($iterationData.status -ne 'ok') {
    $consecutiveVerified = 0
  }

  $summary.iterations += $iterationData
}

if (-not $failed) {
  if ($summary.requirements.maxConsecutiveVerified -ge $requiredConsecutive) {
    $summary.status = 'succeeded'
    $summary.requirements.met = $true
  } else {
    $summary.status = 'failed'
    $summary.failure = [ordered]@{
      iteration = $null
      reason = ("Dev-mode stability requires {0} consecutive verified iterations; best streak was {1}." -f $requiredConsecutive, $summary.requirements.maxConsecutiveVerified)
    }
    $failed = $true
  }
}

Save-StabilitySummary -Path $summaryPath -LatestPath $summaryLatestPath -Summary $summary

if ($failed) {
  Write-Warning "Dev-mode stability run failed: $($summary.failure.reason)"
  exit 1
}

Write-Host ("Dev-mode stability run '{0}' completed successfully." -f $label)
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