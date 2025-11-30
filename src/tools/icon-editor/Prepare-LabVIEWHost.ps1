Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'
#Requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$FixturePath,
  [object[]]$Versions = @(2021),
  [object[]]$Bitness = @(32, 64),
  [string]$StageName,
  [string]$WorkspaceRoot,
  [string]$IconEditorRoot,
  [string]$Operation = 'MissingInProject',
  [string]$LogPath,
  [switch]$SkipStage,
  [switch]$SkipStageValidate,
  [switch]$SkipDevMode,
  [switch]$SkipClose,
  [switch]$SkipReset,
  [switch]$SkipRogueDetection,
  [switch]$SkipPostRogueDetection,
  [switch]$DryRun,
  [int]$RogueLookBackSeconds = 900
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:HostPrepClosureEvents = @()
$script:HostPrepCloseScriptPath = $null
$script:HostPrepDryRun = $false
$script:HostPrepVersions = @()
$script:HostPrepBitness = @()
$script:HostPrepReportScript = $null

$envInvocationLogPath = [System.Environment]::GetEnvironmentVariable('INVOCATION_LOG_PATH')
if (-not $LogPath -and $envInvocationLogPath) {
  $LogPath = $envInvocationLogPath
}

function Get-LabVIEWProcesses {
  try {
    return @(Get-Process -Name 'LabVIEW' -ErrorAction Stop)
  } catch {
    return @()
  }
}

function Ensure-LabVIEWClosed {
  param(
    [Parameter(Mandatory)][string]$Context,
    [Parameter(Mandatory)][string]$CloseScriptPath,
    [int[]]$Versions,
    [int[]]$Bitness,
    [int]$MaxAttempts = 3,
    [int]$WaitSeconds = 5
  )

  $event = [ordered]@{
    context         = $Context
    at              = (Get-Date).ToString('o')
    initialPidCount = 0
    attempts        = 0
    forcedTermination = $false
    terminatedPids  = @()
    finalPidCount   = $null
  }

  if (-not $Versions -or $Versions.Count -eq 0) {
    $Versions = $script:HostPrepVersions
  }
  if (-not $Bitness -or $Bitness.Count -eq 0) {
    $Bitness = $script:HostPrepBitness
  }

  $initialProcesses = @(Get-LabVIEWProcesses)
  $event.initialPidCount = $initialProcesses.Count

  if ($event.initialPidCount -eq 0) {
    $event.finalPidCount = 0
    return [pscustomobject]$event
  }

  if (-not (Test-Path -LiteralPath $CloseScriptPath -PathType Leaf)) {
    $event['note'] = 'close-script-missing'
    return [pscustomobject]$event
  }

  $waitSeconds = [Math]::Max(1, [Math]::Abs([int]$WaitSeconds))
  $event.attempts = 1
  foreach ($version in $Versions) {
    foreach ($bit in $Bitness) {
      try {
        & $CloseScriptPath `
          -MinimumSupportedLVVersion $version `
          -SupportedBitness $bit | Out-Null
      } catch {
        Write-Warning ("[prep] Close-LabVIEW helper failed during context '{0}' (version {1}, bitness {2}): {3}" -f $Context,$version,$bit,$_.Exception.Message)
      }
    }
  }
  Start-Sleep -Seconds $waitSeconds
  $live = @(Get-LabVIEWProcesses)
  if ($live.Count -eq 0) {
    $event.finalPidCount = 0
    return [pscustomobject]$event
  }

  $remaining = @(Get-LabVIEWProcesses)
  if ($remaining.Count -eq 0) {
    $event.finalPidCount = 0
    return [pscustomobject]$event
  }

  $event.forcedTermination = $true
  $event.terminatedPids = @($remaining | ForEach-Object { $_.Id })
  Write-Warning ("[prep] LabVIEWCLI reported shutdown but PID(s) {0} still running during context '{1}'. Forcing termination." -f ($event.terminatedPids -join ','), $Context)
  foreach ($proc in $remaining) {
    try {
      Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    } catch {
      Write-Warning ("[prep] Stop-Process failed for PID {0}: {1}" -f $proc.Id, $_.Exception.Message)
    }
  }
  Start-Sleep -Milliseconds 250
  $finalCheck = @(Get-LabVIEWProcesses)
  $event.finalPidCount = $finalCheck.Count
  if ($finalCheck.Count -gt 0) {
    throw "Failed to terminate LabVIEW processes ({0}) during context '{1}'." -f ($finalCheck.Id -join ','), $Context
  }
  return [pscustomobject]$event
}

function Invoke-ClosureCheck {
  param(
    [Parameter(Mandatory)][string]$Context,
    [int]$WaitSeconds = 5,
    [int[]]$Versions,
    [int[]]$Bitness
  )

  if ($script:HostPrepDryRun) { return }
  $closePath = $script:HostPrepCloseScriptPath
  if (-not $closePath) { return }

  $event = $null
  try {
    $event = Ensure-LabVIEWClosed `
      -Context $Context `
      -CloseScriptPath $closePath `
      -Versions $Versions `
      -Bitness $Bitness `
      -WaitSeconds $WaitSeconds
  } catch {
    throw
  } finally {
    if ($event) {
      $script:HostPrepClosureEvents += $event
    }
  }
}

function Get-LatestDevModeRunPath {
  param([string]$ResultsRoot)

  if (-not $ResultsRoot) { return $null }
  $devModeDir = Join-Path $ResultsRoot '_agent' 'icon-editor' 'dev-mode-run'
  if (-not (Test-Path -LiteralPath $devModeDir -PathType Container)) {
    return $null
  }
  $latest = Get-ChildItem -LiteralPath $devModeDir -Filter 'dev-mode-run-*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($latest) {
    try {
      return (Resolve-Path -LiteralPath $latest.FullName).Path
    } catch {
      return $latest.FullName
    }
  }
  return $null
}

function Set-DevModeTelemetryLink {
  param(
    [System.Collections.IDictionary]$Section,
    [string]$Key,
    [string]$Path
  )

  if (-not $Section -or [string]::IsNullOrWhiteSpace($Key) -or [string]::IsNullOrWhiteSpace($Path)) {
    return
  }

  try {
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  } catch {
    $resolved = $Path
  }

  if (-not $Section.Contains('telemetry')) {
    $Section['telemetry'] = @{}
  }
  $Section.telemetry[$Key] = $resolved
}

function Get-DevModeTelemetrySource {
  param($Section)

  if (-not $Section) { return $null }
  if ($Section -is [System.Collections.IDictionary]) {
    if ($Section.Contains('telemetry')) {
      return $Section['telemetry']
    }
    return $null
  }

  $prop = $Section.PSObject.Properties['telemetry']
  if ($prop) {
    return $prop.Value
  }
  return $null
}

function Complete-HostPrep {
  param(
    [string]$ResultsRoot,
    [string]$FixturePath,
    [int[]]$Versions,
    [int[]]$Bitness,
    [string]$StageName,
    [string]$Workspace,
    [string]$Operation,
    [bool]$DryRunFlag,
    [string]$LogPathValue,
    $Steps,
    $Closures,
    [bool]$Aborted = $false,
    [string]$AbortReason
  )

  if (-not $LogPathValue) {
    $envInvocationLogPathInner = [System.Environment]::GetEnvironmentVariable('INVOCATION_LOG_PATH')
    if ($envInvocationLogPathInner) { $LogPathValue = $envInvocationLogPathInner }
  }

  $summary = [pscustomobject]@{
    fixture       = $FixturePath
    versions      = $Versions
    bitness       = $Bitness
    stage         = $StageName
    workspace     = $Workspace
    dryRun        = [bool]$DryRunFlag
    operation     = $Operation
    logPath       = $LogPathValue
    steps         = $Steps
    closures      = $Closures
    aborted       = $Aborted
    abortReason   = $AbortReason
    telemetryPath = $null
    devModeTelemetry = $null
  }

  try {
    $telemetryDir = Join-Path $ResultsRoot '_agent' 'icon-editor' 'host-prep'
    if (-not (Test-Path -LiteralPath $telemetryDir -PathType Container)) {
      [void](New-Item -ItemType Directory -Path $telemetryDir -Force)
    }
    $telemetryPayload = [ordered]@{
      schema      = 'icon-editor/host-prep@v1'
      recordedAt  = (Get-Date).ToString('o')
      fixture     = $FixturePath
      versions    = $Versions
      bitness     = $Bitness
      stage       = $StageName
      workspace   = $Workspace
      dryRun      = [bool]$DryRunFlag
      operation   = $Operation
      logPath     = $LogPathValue
      steps       = $Steps
      closures    = $Closures
      aborted     = $Aborted
    }
    if ($AbortReason) {
      $telemetryPayload['abortReason'] = $AbortReason
    }
    $devModeTelemetry = @{}
    $devModeSectionTelemetry = if ($Steps) { Get-DevModeTelemetrySource -Section $Steps.devMode } else { $null }
    if ($devModeSectionTelemetry) {
      foreach ($key in $devModeSectionTelemetry.Keys) {
        $devModeTelemetry[$key] = $devModeSectionTelemetry[$key]
      }
    }
    $guardTelemetry = if ($Steps) { Get-DevModeTelemetrySource -Section $Steps.devModeCheck } else { $null }
    if ($guardTelemetry) {
      foreach ($key in $guardTelemetry.Keys) {
        $devModeTelemetry[$key] = $guardTelemetry[$key]
      }
    }
    if ($devModeTelemetry.Count -gt 0) {
      $summary.devModeTelemetry = $devModeTelemetry
      $telemetryPayload['devModeTelemetry'] = $devModeTelemetry
    }
    $telemetryPath = Join-Path $telemetryDir ("host-prep-{0}.json" -f (Get-Date -Format 'yyyyMMddTHHmmssfff'))
    $telemetryPayload | ConvertTo-Json -Depth 8 | Out-File -FilePath $telemetryPath -Encoding utf8
    $summary.telemetryPath = $telemetryPath
  } catch {
    Write-Warning ("[prep] Failed to write host-prep telemetry: {0}" -f $_.Exception.Message)
  }

  return $summary
}

function Write-HostPrepReport {
  param([hashtable]$Arguments)
  $scriptPath = $script:HostPrepReportScript
  if (-not $scriptPath) { return $null }
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    Write-Warning ("[prep] Run-report helper missing at: {0}" -f $scriptPath)
    return $null
  }
  if (-not $Arguments) { return $null }
  return & $scriptPath @Arguments
}

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    $root = git -C $StartPath rev-parse --show-toplevel 2>$null
    if ($root) {
      return (Resolve-Path -LiteralPath $root.Trim()).Path
    }
  } catch {}
  return (Resolve-Path -LiteralPath $StartPath).Path
}

function Resolve-OptionalPath {
  param(
    [string]$Path,
    [string]$BasePath
  )
  if (-not $Path) { return $null }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    try {
      return (Resolve-Path -LiteralPath $Path).Path
    } catch {
      return [System.IO.Path]::GetFullPath($Path)
    }
  }
  $base = if ($BasePath) { $BasePath } else { (Get-Location).Path }
  $candidate = Join-Path $base $Path
  try {
    return (Resolve-Path -LiteralPath $candidate).Path
  } catch {
    return [System.IO.Path]::GetFullPath($candidate)
  }
}

function Convert-ToIntList {
  param(
    [object[]]$Values,
    [int[]]$Defaults,
    [string]$Name,
    [ValidateScript({ $true })][scriptblock]$Validator
  )

  $result = @()
  $source = if ($Values -and $Values.Count -gt 0) { $Values } else { $Defaults }
  foreach ($entry in $source) {
    if ($null -eq $entry) { continue }
    if ($entry -is [System.Array]) {
      $result += Convert-ToIntList -Values $entry -Defaults @() -Name $Name -Validator $Validator
      continue
    }
    if ($entry -is [string]) {
      $normalized = $entry.Trim()
      if ($normalized -match '[,;\s]') {
        $parts = $normalized -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($parts.Count -gt 1) {
          $result += Convert-ToIntList -Values $parts -Defaults @() -Name $Name -Validator $Validator
          continue
        } else {
          $entry = $normalized
        }
      }
    }
    try {
      $value = [int]$entry
      if ($Validator -and -not (& $Validator $value)) {
        throw "Value '$value' did not pass validation for $Name."
      }
      $result += $value
    } catch {
      throw "Unable to parse $Name entry '$entry': $($_.Exception.Message)"
    }
  }
  $result = @($result | Sort-Object -Unique)
  if ($result.Count -eq 0) {
    throw "No valid values supplied for $Name."
  }
  return $result
}

function Invoke-RogueDetection {
  param(
    [string]$StageLabel,
    [string]$ScriptPath,
    [string]$ResultsDir,
    [int]$LookBackSeconds,
    [switch]$Skip
  )

  if ($Skip) { return }
  if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    Write-Warning "Detect-RogueLV.ps1 not found at '$ScriptPath'; skipping rogue scan."
    return
  }

  $outputDir = Join-Path $ResultsDir '_agent' 'icon-editor' 'rogue-lv'
  if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $outputDir -Force)
  }
  $outputPath = Join-Path $outputDir ("rogue-{0}-{1}.json" -f $StageLabel.Replace(' ', '-'), (Get-Date -Format 'yyyyMMddTHHmmssfff'))

  Write-Host ("[prep] Running rogue LV detection ({0})..." -f $StageLabel)
  & $ScriptPath `
    -ResultsDir $ResultsDir `
    -LookBackSeconds $LookBackSeconds `
    -FailOnRogue `
    -OutputPath $outputPath `
    -AppendToStepSummary:$false |
    Out-Null
}

$repoRoot = Resolve-RepoRoot
$script:HostPrepReportScript = Join-Path $repoRoot 'tools/report/Write-RunReport.ps1'
$fixtureResolved = Resolve-OptionalPath -Path $FixturePath -BasePath $repoRoot
if (-not $fixtureResolved -or -not (Test-Path -LiteralPath $fixtureResolved -PathType Leaf)) {
  throw "Fixture VIP not found at '$FixturePath'."
}

$iconEditorRootResolved = if ($IconEditorRoot) {
  Resolve-OptionalPath -Path $IconEditorRoot -BasePath $repoRoot
} else {
  Join-Path $repoRoot 'vendor/icon-editor'
}
if (-not (Test-Path -LiteralPath $iconEditorRootResolved -PathType Container)) {
  throw "Icon editor root not found at '$iconEditorRootResolved'."
}

$workspaceResolved = if ($WorkspaceRoot) {
  Resolve-OptionalPath -Path $WorkspaceRoot -BasePath $repoRoot
} else {
  Join-Path $repoRoot 'tests/results/_agent/icon-editor/snapshots'
}
if (-not (Test-Path -LiteralPath $workspaceResolved -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $workspaceResolved -Force)
}

$stageNameResolved = if ($StageName) {
  $StageName
} else {
  'host-prep-{0}' -f (Get-Date -Format 'yyyyMMddTHHmmss')
}

$versionsList = Convert-ToIntList -Values $Versions -Defaults @(2021) -Name 'Versions' -Validator { param($v) ($v -gt 2000) }
$bitnessList = Convert-ToIntList -Values $Bitness -Defaults @(32, 64) -Name 'Bitness' -Validator { param($b) ($b -in 32,64) }
$script:HostPrepVersions = $versionsList
$script:HostPrepBitness = $bitnessList

$stageScript = Join-Path $repoRoot 'tools/icon-editor/Stage-IconEditorSnapshot.ps1'
$enableScript = Join-Path $repoRoot 'tools/icon-editor/Enable-DevMode.ps1'
$disableScript = Join-Path $repoRoot 'tools/icon-editor/Disable-DevMode.ps1'
$resetScript = Join-Path $repoRoot 'tools/icon-editor/Reset-IconEditorWorkspace.ps1'
$detectScript = Join-Path $repoRoot 'tools/Detect-RogueLV.ps1'
$closeScript = Join-Path $iconEditorRootResolved '.github/actions/close-labview/Close_LabVIEW.ps1'
$globalCloseScript = Join-Path $repoRoot 'tools/Close-LabVIEW.ps1'
$devModeModulePath = Join-Path $repoRoot 'tools/icon-editor/IconEditorDevMode.psm1'

foreach ($required in @($stageScript, $enableScript, $disableScript, $resetScript, $closeScript, $globalCloseScript, $devModeModulePath)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Required helper script '$required' was not found."
  }
}

$script:HostPrepCloseScriptPath = $globalCloseScript
$script:HostPrepDryRun = [bool]$DryRun
$script:HostPrepClosureEvents = @()

$resultsRoot = Join-Path $repoRoot 'tests/results'
if (-not (Test-Path -LiteralPath $resultsRoot -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $resultsRoot -Force)
}

$stepTelemetry = [ordered]@{
  roguePre  = @{ skipped = [bool]$SkipRogueDetection; executed = $false }
  stage     = @{ skipped = [bool]$SkipStage; executed = $false }
  devMode   = @{ skipped = [bool]$SkipDevMode; executed = $false }
  close     = @{ skipped = [bool]$SkipClose; executed = $false }
  reset     = @{ skipped = [bool]$SkipReset; executed = $false }
  roguePost = @{ skipped = [bool]$SkipPostRogueDetection; executed = $false }
  devModeCheck = @{ detected = $false; disabled = @() }
}

$safetyToggles = @{
  LV_SUPPRESS_UI       = '1'
  LV_NO_ACTIVATE       = '1'
  LV_CURSOR_RESTORE    = '1'
  LV_IDLE_WAIT_SECONDS = '2'
  LV_IDLE_MAX_WAIT_SECONDS = '5'
}
foreach ($entry in $safetyToggles.GetEnumerator()) {
  $current = [Environment]::GetEnvironmentVariable($entry.Key)
  if ([string]::IsNullOrWhiteSpace($current)) {
    Set-Item -Path ("Env:{0}" -f $entry.Key) -Value $entry.Value
  }
}

if ($DryRun) {
  Write-Host "[prep] Dry-run mode enabled. Only staging will execute (with -DryRun); other steps will be logged."
}

$existingDevModeEntries = @()
try {
  Import-Module $devModeModulePath -Force
  $devModeStatus = Test-IconEditorDevelopmentMode -RepoRoot $repoRoot -IconEditorRoot $iconEditorRootResolved -Versions $versionsList -Bitness $bitnessList
  $existingDevModeEntries = @($devModeStatus.Entries | Where-Object { $_.Present -and $_.ContainsIconEditorPath })
} catch {
  Write-Warning ("[prep] Dev-mode detection failed: {0}" -f $_.Exception.Message)
}

if ($existingDevModeEntries.Count -gt 0) {
  $details = $existingDevModeEntries | ForEach-Object { '{0} ({1}-bit)' -f $_.Version, $_.Bitness }
  $stepTelemetry.devModeCheck.detected = $true
  $stepTelemetry.devModeCheck.disabled = $details
  $reason = "Detected existing icon-editor dev mode for: {0}. Disabled dev mode and aborting host prep." -f ($details -join ', ')
  Write-Warning $reason
  foreach ($entry in $existingDevModeEntries) {
    try {
      & $disableScript `
        -RepoRoot $repoRoot `
        -IconEditorRoot $iconEditorRootResolved `
        -Versions $entry.Version `
        -Bitness $entry.Bitness `
        -Operation $Operation | Out-Null
      $latestDisableRun = Get-LatestDevModeRunPath -ResultsRoot $resultsRoot
      Set-DevModeTelemetryLink -Section $stepTelemetry.devModeCheck -Key ("disable-{0}-{1}" -f $entry.Version, $entry.Bitness) -Path $latestDisableRun
    } catch {
      Write-Warning ("[prep] Failed to disable dev mode for LabVIEW {0} ({1}-bit): {2}" -f $entry.Version,$entry.Bitness,$_.Exception.Message)
    }
  }
  Invoke-ClosureCheck -Context 'final' -Versions $versionsList -Bitness $bitnessList
  $guardSummary = Complete-HostPrep -ResultsRoot $resultsRoot -FixturePath $fixtureResolved -Versions $versionsList -Bitness $bitnessList -StageName $stageNameResolved -Workspace $workspaceResolved -Operation $Operation -DryRunFlag $DryRun -LogPath $LogPath -Steps $stepTelemetry -Closures $script:HostPrepClosureEvents -Aborted:$true -AbortReason $reason
  try {
    $reportArgs = @{
      Kind          = 'host-prep'
      Label         = $stageNameResolved
      Command       = "pwsh -File tools/icon-editor/Prepare-LabVIEWHost.ps1 -FixturePath $FixturePath -SkipStage -Versions $($versionsList -join ',') -Bitness $($bitnessList -join ',') -StageName $stageNameResolved"
      Summary       = ($guardSummary | Out-String).Trim()
      Warnings      = $reason
      TranscriptPath = $LogPath
      TelemetryPath = $guardSummary.telemetryPath
      Aborted       = $true
      AbortReason   = $reason
    }
    $reportPath = Write-HostPrepReport -Arguments $reportArgs
    if ($reportPath) {
      Write-Host ("Host prep report: {0}" -f $reportPath) -ForegroundColor DarkGray
    }
  } catch {
    Write-Warning ("[prep] Failed to write host-prep report: {0}" -f $_.Exception.Message)
  }
  return $guardSummary
}

Invoke-RogueDetection -StageLabel 'pre' -ScriptPath $detectScript -ResultsDir $resultsRoot -LookBackSeconds $RogueLookBackSeconds -Skip:$SkipRogueDetection
if (-not $SkipRogueDetection) {
  $stepTelemetry.roguePre.executed = $true
}

if (-not $SkipStage) {
  $stageArgs = @{
    FixturePath     = $fixtureResolved
    WorkspaceRoot   = $workspaceResolved
    StageName       = $stageNameResolved
    DevModeVersions = $versionsList
    DevModeBitness  = $bitnessList
    DevModeOperation = $Operation
  }
  if ($IconEditorRoot) {
    $stageArgs.SourcePath = $iconEditorRootResolved
  }
  if ($DryRun) {
    $stageArgs.DryRun = $true
  }
  if ($SkipStageValidate) {
    $stageArgs.SkipValidate = $true
  }
  Write-Host "[prep] Staging icon-editor snapshot..."
  & $stageScript @stageArgs | Out-Null
  $stepTelemetry.stage.executed = $true
  Invoke-ClosureCheck -Context 'stage' -Versions $versionsList -Bitness $bitnessList
} else {
  Write-Host "[prep] Skipping snapshot staging (per flag)."
}

if (-not $SkipDevMode) {
  if ($DryRun) {
    Write-Host "[prep] (dry-run) would enable icon-editor dev mode for versions [$($versionsList -join ', ')] bitness [$($bitnessList -join ', ')]."
  } else {
    $devArgs = @{
      RepoRoot = $repoRoot
      IconEditorRoot = $iconEditorRootResolved
      Versions = $versionsList
      Bitness  = $bitnessList
      Operation = $Operation
    }
    Write-Host "[prep] Enabling icon-editor dev mode..."
    & $enableScript @devArgs | Out-Null
    $stepTelemetry.devMode.executed = $true
    $latestEnableRun = Get-LatestDevModeRunPath -ResultsRoot $resultsRoot
    Set-DevModeTelemetryLink -Section $stepTelemetry.devMode -Key 'enable' -Path $latestEnableRun
    Invoke-ClosureCheck -Context 'dev-mode' -Versions $versionsList -Bitness $bitnessList
  }
} else {
  Write-Host "[prep] Skipping dev-mode enable (per flag)."
}

if (-not $SkipClose) {
  if ($DryRun) {
    Write-Host "[prep] (dry-run) would close LabVIEW via Close_LabVIEW.ps1 for all targets."
  } else {
    foreach ($version in $versionsList) {
      foreach ($bit in $bitnessList) {
        Write-Host ("[prep] Closing LabVIEW {0} ({1}-bit)..." -f $version, $bit)
        & $closeScript `
          -MinimumSupportedLVVersion $version `
          -SupportedBitness $bit
      }
    }
    $stepTelemetry.close.executed = $true
    Invoke-ClosureCheck -Context 'close' -Versions $versionsList -Bitness $bitnessList
  }
} else {
  Write-Host "[prep] Skipping LabVIEW close (per flag)."
}

if (-not $SkipReset) {
  if ($DryRun) {
    Write-Host "[prep] (dry-run) would reset icon-editor workspace for all targets."
  } else {
    $resetArgs = @{
      RepoRoot = $repoRoot
      IconEditorRoot = $iconEditorRootResolved
      Versions = $versionsList
      Bitness = $bitnessList
    }
    Write-Host "[prep] Resetting icon-editor workspaces..."
    & $resetScript @resetArgs | Out-Null
    $stepTelemetry.reset.executed = $true
    Invoke-ClosureCheck -Context 'reset' -Versions $versionsList -Bitness $bitnessList
  }
} else {
  Write-Host "[prep] Skipping workspace reset (per flag)."
}

Invoke-RogueDetection -StageLabel 'post' -ScriptPath $detectScript -ResultsDir $resultsRoot -LookBackSeconds $RogueLookBackSeconds -Skip:$SkipPostRogueDetection
if (-not $SkipPostRogueDetection) {
  $stepTelemetry.roguePost.executed = $true
}

Invoke-ClosureCheck -Context 'final' -Versions $versionsList -Bitness $bitnessList

$hostPrepSummary = Complete-HostPrep -ResultsRoot $resultsRoot -FixturePath $fixtureResolved -Versions $versionsList -Bitness $bitnessList -StageName $stageNameResolved -Workspace $workspaceResolved -Operation $Operation -DryRunFlag $DryRun -LogPath $LogPath -Steps $stepTelemetry -Closures $script:HostPrepClosureEvents

try {
  $warningsText = $script:HostPrepClosureEvents |
    Where-Object { $_.forcedTermination -or $_.note } |
    ForEach-Object {
      if ($_.note) { $_.note } else { "Forced termination (context=$($_.context), pids=$($_.terminatedPids -join ','))" }
    } |
    Where-Object { $_ } -join [Environment]::NewLine

  $cmdString = "pwsh -File tools/icon-editor/Prepare-LabVIEWHost.ps1 -FixturePath {0} -SkipStage -Versions {1} -Bitness {2} -StageName {3}" -f `
    $FixturePath, ($versionsList -join ','), ($bitnessList -join ','), $stageNameResolved

  $reportArgs = @{
    Kind          = 'host-prep'
    Label         = $stageNameResolved
    Command       = $cmdString
    Summary       = ($hostPrepSummary | Out-String).Trim()
    Warnings      = if ($warningsText) { $warningsText } else { '' }
    TranscriptPath = $LogPath
    TelemetryPath = $hostPrepSummary.telemetryPath
    TelemetryLinks = $hostPrepSummary.devModeTelemetry
    Aborted       = [bool]$hostPrepSummary.aborted
    AbortReason   = $hostPrepSummary.abortReason
  }

  $reportPath = Write-HostPrepReport -Arguments $reportArgs
  if ($reportPath) {
    Write-Host ("Host prep report: {0}" -f $reportPath) -ForegroundColor DarkGray
  }
} catch {
  Write-Warning ("[prep] Failed to write host-prep report: {0}" -f $_.Exception.Message)
}

return $hostPrepSummary

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