#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$RepoRoot,
  [string]$IconEditorRoot,
  [int[]]$Versions,
  [int[]]$Bitness,
  [string]$Operation = 'BuildPackage'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $PSCommandPath
$modulePath = Join-Path $scriptDirectory 'IconEditorDevMode.psm1'
Import-Module $modulePath -Force

$resolvedRepoRoot = $null
try {
  if ($RepoRoot) {
    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  } else {
    $resolvedRepoRoot = Resolve-IconEditorRepoRoot
  }
} catch {
  $resolvedRepoRoot = Resolve-IconEditorRepoRoot
}

$resolvedIconEditorRoot = $null
try {
  if ($IconEditorRoot) {
    $resolvedIconEditorRoot = (Resolve-Path -LiteralPath $IconEditorRoot).Path
  } elseif ($resolvedRepoRoot) {
    $resolvedIconEditorRoot = Resolve-IconEditorRoot -RepoRoot $resolvedRepoRoot
  }
} catch {
  $resolvedIconEditorRoot = $IconEditorRoot
}

$telemetryContext = Initialize-IconEditorDevModeTelemetry `
  -Mode 'enable' `
  -RepoRoot $resolvedRepoRoot `
  -IconEditorRoot $resolvedIconEditorRoot `
  -Versions $Versions `
  -Bitness $Bitness `
  -Operation $Operation

$invokeParams = @{}
if ($RepoRoot) { $invokeParams.RepoRoot = $RepoRoot }
if ($IconEditorRoot) { $invokeParams.IconEditorRoot = $IconEditorRoot }
if ($Versions) { $invokeParams.Versions = $Versions }
if ($Bitness) { $invokeParams.Bitness = $Bitness }
if ($Operation) { $invokeParams.Operation = $Operation }
if ($telemetryContext) { $invokeParams.TelemetryContext = $telemetryContext }

$rawState = $null

try {
  $rogueStageResult = Invoke-IconEditorTelemetryStage -Context $telemetryContext -Name 'rogue-check' -ExpectedSeconds 30 -Action {
    param($stage)
    $stage.stage = 'enable-devmode-pre'
    $result = Invoke-IconEditorRogueCheck -RepoRoot $resolvedRepoRoot -Stage 'enable-devmode-pre' -FailOnRogue -AutoClose
    if ($result) {
      $stage.snapshotPath = $result.Path
      $stage.exitCode = $result.ExitCode
      if ($telemetryContext.Telemetry) {
        $telemetryContext.Telemetry.rogueSnapshotPath = $result.Path
      }
    }
    $settle = Get-IconEditorLabVIEWSettleEvents
    if ($settle -and $settle.Count -gt 0) {
      $stage.settleEvents = $settle
    }
  }

  Invoke-IconEditorTelemetryStage -Context $telemetryContext -Name 'enable-dev-mode' -ExpectedSeconds 300 -Action {
    param($stage)
    $script:rawState = Enable-IconEditorDevelopmentMode @invokeParams
    if ($script:rawState -and $script:rawState.PSObject.Properties['Path']) {
      $stage.statePath = $script:rawState.Path
    }
    $settle = Get-IconEditorLabVIEWSettleEvents
    if ($settle -and $settle.Count -gt 0) {
      $stage.settleEvents = $settle
    }
  }

  if ($rawState -is [System.Array]) {
    $state = $rawState | Where-Object { $_ -is [psobject] -and $_.PSObject.Properties['Active'] } | Select-Object -Last 1
    if (-not $state) {
      $state = $rawState | Select-Object -Last 1
    }
  } else {
    $state = $rawState
  }

  Write-Host "Icon editor development mode enabled."
  if ($null -eq $state) {
    Write-Warning "Enable-IconEditorDevelopmentMode returned no state payload."
  } else {
    $stateType = $state.GetType().FullName
    $pathProp = $state.PSObject.Properties['Path']
    $updatedProp = $state.PSObject.Properties['UpdatedAt']

    if ($pathProp) {
      Write-Host ("State file: {0}" -f $pathProp.Value)
    } else {
      Write-Warning ("Dev-mode state omitted 'Path' (type: {0})" -f $stateType)
      Write-Warning ($state | ConvertTo-Json -Depth 5 -Compress)
    }

    if ($updatedProp) {
      Write-Host ("Updated at : {0}" -f $updatedProp.Value)
    } else {
      Write-Warning ("Dev-mode state omitted 'UpdatedAt' (type: {0})" -f $stateType)
    }

    $verificationProp = $state.PSObject.Properties['Verification']
    if ($verificationProp) {
      $verification = $verificationProp.Value
      if ($verification -and $verification.Entries) {
        $present = $verification.Entries | Where-Object { $_.Present }
        if ($present -and $present.Count -gt 0) {
          $summary = $present | ForEach-Object {
            $status = if ($_.ContainsIconEditorPath) { 'contains icon-editor path' } else { 'missing icon-editor path' }
            "LabVIEW {0} ({1}-bit): {2}" -f $_.Version, $_.Bitness, $status
          }
          Write-Host ("Verification: {0}" -f ([string]::Join('; ', $summary)))
        } else {
          Write-Host "Verification: no LabVIEW targets detected; token check skipped."
        }
      }
    }
  }

  Complete-IconEditorDevModeTelemetry -Context $telemetryContext -Status 'succeeded' -State $state
  $state
} catch {
  $errorText = $_.Exception.Message
  $status = 'failed'
  try {
    $status = Get-IconEditorDevModeOutcomeStatus -ErrorMessage $errorText
  } catch {
    $status = 'failed'
  }
  Complete-IconEditorDevModeTelemetry -Context $telemetryContext -Status $status -Error $errorText
  throw
}

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
