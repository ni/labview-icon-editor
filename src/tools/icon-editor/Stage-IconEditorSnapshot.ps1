#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600,
  [string]$SourcePath,
  [string]$ResourceOverlayRoot,
  [string]$StageName,
  [string]$WorkspaceRoot,
  [string]$FixturePath,
  [string]$BaselineFixture = $env:ICON_EDITOR_BASELINE_FIXTURE_PATH,
  [string]$BaselineManifest = $env:ICON_EDITOR_BASELINE_MANIFEST_PATH,
  [string]$InvokeValidateScript,
  [switch]$SkipValidate,
  [switch]$SkipLVCompare,
  [switch]$DryRun,
  [switch]$SkipBootstrapForValidate,
  [int[]]$DevModeVersions = @(2025),
  [int[]]$DevModeBitness = @(64),
  [string]$DevModeOperation = 'Compare',
  [switch]$SkipDevMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSModuleAutoLoadingPreference = 'None'

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

function Resolve-PathOptional {
  param(
    [string]$Path,
    [string]$BasePath
  )
  if (-not $Path) { return $null }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return (Resolve-Path -LiteralPath $Path).Path
  }
  if (-not $BasePath) { $BasePath = (Get-Location).Path }
  $combined = Join-Path $BasePath $Path
  return (Resolve-Path -LiteralPath $combined).Path
}

function Resolve-DevModeSelection {
  param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int[]]$RequestedVersions,
    [int[]]$RequestedBitness,
    [bool]$VersionsSpecified,
    [bool]$BitnessSpecified,
    [string]$DevModulePath,
    [string]$Operation
  )

  function Convert-SelectionValues {
    param([int[]]$Values, [int[]]$Fallback)
    $result = @()
    if ($Values) {
      foreach ($value in $Values) {
        if ($null -ne $value) { $result += [int]$value }
      }
    }
    if (($result.Count -eq 0) -and $Fallback) {
      foreach ($value in $Fallback) {
        if ($null -ne $value) { $result += [int]$value }
      }
    }
    return $result
  }

  if (-not (Get-Command Get-IconEditorDevModePolicyEntry -ErrorAction SilentlyContinue)) {
    if ($DevModulePath -and (Test-Path -LiteralPath $DevModulePath -PathType Leaf)) {
      Import-Module $DevModulePath -Force
    }
  }

  $policyEntry = $null
  if (-not $VersionsSpecified -or -not $BitnessSpecified) {
    if (Get-Command Get-IconEditorDevModePolicyEntry -ErrorAction SilentlyContinue) {
      try {
        $policyEntry = Get-IconEditorDevModePolicyEntry -RepoRoot $RepoRoot -Operation $Operation
      } catch {
        if (-not $VersionsSpecified -and -not $BitnessSpecified) {
          throw
        }
      }
    }
  }

  $defaultTargets = if ($policyEntry) {
    $policyEntry
  } else {
    [pscustomobject]@{
      Versions = @(2025)
      Bitness  = @(64)
    }
  }

  [array]$effectiveVersions = Convert-SelectionValues -Values $RequestedVersions -Fallback $defaultTargets.Versions
  [array]$effectiveBitness  = Convert-SelectionValues -Values $RequestedBitness -Fallback $defaultTargets.Bitness

  if ($effectiveVersions.Count -eq 0 -or $effectiveBitness.Count -eq 0) {
    throw "Icon-editor dev-mode selection resolved to an empty version/bitness set for operation '$Operation'."
  }

  $enforcePresence = -not ($VersionsSpecified -or $BitnessSpecified)
  if ($enforcePresence) {
    if (-not (Get-Command Get-IconEditorDevModeLabVIEWTargets -ErrorAction SilentlyContinue)) {
      if ($DevModulePath -and (Test-Path -LiteralPath $DevModulePath -PathType Leaf)) {
        Import-Module $DevModulePath -Force
      }
    }

    $targets = @()
    if (Get-Command Get-IconEditorDevModeLabVIEWTargets -ErrorAction SilentlyContinue) {
      try {
        $targets = Get-IconEditorDevModeLabVIEWTargets -RepoRoot $RepoRoot -IconEditorRoot $IconEditorRoot -Versions $effectiveVersions -Bitness $effectiveBitness
      } catch {
        $targets = @()
      }
    }

    $missingCombos = @()
    foreach ($version in $effectiveVersions) {
      foreach ($bit in $effectiveBitness) {
        $match = $targets | Where-Object { $_.Present -and $_.Version -eq $version -and $_.Bitness -eq $bit } | Select-Object -First 1
        if (-not $match) {
          $missingCombos += [pscustomobject]@{
            Version = $version
            Bitness = $bit
          }
        }
      }
    }

    if ($missingCombos.Count -gt 0) {
      $missingText = ($missingCombos | ForEach-Object { "LabVIEW {0} {1}-bit" -f $_.Version, $_.Bitness }) -join ', '
      throw ("{0} not detected; cannot enable icon-editor development mode for operation '{1}'. Install the required LabVIEW build(s) or override with -DevModeVersions/-DevModeBitness." -f $missingText, $Operation)
    }
  }

  return [pscustomobject]@{
    Versions = ($effectiveVersions | Select-Object -Unique | ForEach-Object { [int]$_ })
    Bitness  = ($effectiveBitness | Select-Object -Unique | ForEach-Object { [int]$_ })
  }
}

$repoRoot = Resolve-RepoRoot
$scriptRoot = Split-Path -Parent $PSCommandPath

$toolsRoot = Join-Path $repoRoot 'tools'
$altToolsRoot = Join-Path $repoRoot 'src/tools'
if (-not (Test-Path -LiteralPath $toolsRoot -PathType Container) -and -not (Test-Path -LiteralPath $altToolsRoot -PathType Container)) {
  throw "Unable to locate a 'tools' directory under '$toolsRoot' or '$altToolsRoot'."
}
if (-not (Test-Path -LiteralPath $toolsRoot -PathType Container) -and (Test-Path -LiteralPath $altToolsRoot -PathType Container)) {
  $toolsRoot = $altToolsRoot
}

$iconEditorToolsRoot = Join-Path $toolsRoot 'icon-editor'
if (-not (Test-Path -LiteralPath $iconEditorToolsRoot -PathType Container)) {
  $altIconRoot = Join-Path $altToolsRoot 'icon-editor'
  if (Test-Path -LiteralPath $altIconRoot -PathType Container) {
    $iconEditorToolsRoot = $altIconRoot
  } else {
    throw "Icon editor tooling not found under '$iconEditorToolsRoot' or '$altIconRoot'."
  }
}

$devModulePath = Join-Path $iconEditorToolsRoot 'IconEditorDevMode.psm1'

$sourceResolved = Resolve-PathOptional -Path $SourcePath -BasePath $repoRoot
if (-not $sourceResolved) {
  $sourceResolved = Resolve-PathOptional -Path (Join-Path $repoRoot 'vendor/icon-editor') -BasePath $repoRoot
}
if (-not (Test-Path -LiteralPath $sourceResolved -PathType Container)) {
  throw "Icon editor source path not found at '$sourceResolved'."
}

if ($WorkspaceRoot) {
  $workspaceResolved = if ([System.IO.Path]::IsPathRooted($WorkspaceRoot)) {
    [System.IO.Path]::GetFullPath($WorkspaceRoot)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $WorkspaceRoot))
  }
} else {
  $workspaceResolved = Join-Path $repoRoot 'tests/results/_agent/icon-editor/snapshots'
}
if (-not (Test-Path -LiteralPath $workspaceResolved -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $workspaceResolved -Force)
}

$stageResolvedName = if ($StageName) { $StageName } else { 'snapshot-{0}' -f (Get-Date -Format 'yyyyMMddTHHmmss') }
$stageRoot = Join-Path $workspaceResolved $stageResolvedName
if (Test-Path -LiteralPath $stageRoot -PathType Container) {
  Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
[void](New-Item -ItemType Directory -Path $stageRoot -Force)

$overlayResolved = Resolve-PathOptional -Path $ResourceOverlayRoot -BasePath $workspaceResolved
if (-not $overlayResolved) {
  $overlayResolved = Join-Path $sourceResolved 'resource'
}
if (-not (Test-Path -LiteralPath $overlayResolved -PathType Container)) {
  throw "Resource overlay path '$overlayResolved' not found."
}

$fixtureResolved = Resolve-PathOptional -Path $FixturePath -BasePath $repoRoot
if (-not $fixtureResolved) {
  throw "FixturePath is required; supply the VIP generated by the build."
}
if (-not (Test-Path -LiteralPath $fixtureResolved -PathType Leaf)) {
  throw "Fixture VIP not found at '$fixtureResolved'."
}

$baselineFixtureResolved = Resolve-PathOptional -Path $BaselineFixture -BasePath $repoRoot
$baselineManifestResolved = Resolve-PathOptional -Path $BaselineManifest -BasePath $repoRoot

$updateReportScript = Join-Path $iconEditorToolsRoot 'Update-IconEditorFixtureReport.ps1'
if (-not (Test-Path -LiteralPath $updateReportScript -PathType Leaf)) {
  throw "Update fixture report script not found at '$updateReportScript'."
}

$reportDir = Join-Path $stageRoot 'report'
[void](New-Item -ItemType Directory -Path $reportDir -Force)
$headManifestPath = Join-Path $stageRoot 'head-manifest.json'
$updateParams = @{
  FixturePath         = $fixtureResolved
  ManifestPath        = $headManifestPath
  ResultsRoot         = $reportDir
  ResourceOverlayRoot = $overlayResolved
  SkipDocUpdate       = $true
}
$fixtureSummary = & $updateReportScript @updateParams
$headReportPath = Join-Path $reportDir 'fixture-report.json'

$selection = $null
$devModeEnabled = $false
$validateRoot = $null
if (-not $SkipValidate.IsPresent) {
  $validateRoot = Join-Path $stageRoot 'validate'
  $validateScript = if ($InvokeValidateScript) {
    Resolve-PathOptional -Path $InvokeValidateScript -BasePath $repoRoot
  } else {
    Join-Path $iconEditorToolsRoot 'Invoke-ValidateLocal.ps1'
  }
  if (-not (Test-Path -LiteralPath $validateScript -PathType Leaf)) {
    throw "Invoke-ValidateLocal.ps1 not found at '$validateScript'."
  }
  [void](New-Item -ItemType Directory -Path $validateRoot -Force)

  if (-not $SkipDevMode.IsPresent) {
    if (-not (Get-Command Enable-IconEditorDevelopmentMode -ErrorAction SilentlyContinue)) {
      if (Test-Path -LiteralPath $devModulePath -PathType Leaf) {
        Import-Module $devModulePath -Force
      }
    }
    if (Get-Command Enable-IconEditorDevelopmentMode -ErrorAction SilentlyContinue) {
      $selection = Resolve-DevModeSelection `
        -RepoRoot $repoRoot `
        -IconEditorRoot $sourceResolved `
        -RequestedVersions $DevModeVersions `
        -RequestedBitness $DevModeBitness `
        -VersionsSpecified ($PSBoundParameters.ContainsKey('DevModeVersions')) `
        -BitnessSpecified ($PSBoundParameters.ContainsKey('DevModeBitness')) `
        -DevModulePath $devModulePath `
        -Operation $DevModeOperation
      $effectiveVersions = $selection.Versions
      $effectiveBitness = $selection.Bitness
      Enable-IconEditorDevelopmentMode `
        -RepoRoot $repoRoot `
        -IconEditorRoot $sourceResolved `
        -Versions $effectiveVersions `
        -Bitness $effectiveBitness `
        -Operation $DevModeOperation | Out-Null
      $devModeEnabled = $true
    } else {
      Write-Warning 'Enable-IconEditorDevelopmentMode not available; continuing without dev-mode toggle.'
    }
  }

  try {
    $validateParams = @{
      ResourceOverlayRoot = $overlayResolved
      ResultsRoot         = $validateRoot
    }
    if ($baselineFixtureResolved) { $validateParams.BaselineFixture = $baselineFixtureResolved }
    if ($baselineManifestResolved) { $validateParams.BaselineManifest = $baselineManifestResolved }
    if ($SkipLVCompare.IsPresent -or $DryRun.IsPresent) { $validateParams.SkipLVCompare = $true }
    if ($DryRun.IsPresent) {
      $validateParams.DryRun = $true
    }
    if ($SkipBootstrapForValidate.IsPresent) {
      $validateParams.SkipBootstrap = $true
    }

    & $validateScript @validateParams | Out-Null
  }
  finally {
    if ($devModeEnabled) {
      if (-not (Get-Command Disable-IconEditorDevelopmentMode -ErrorAction SilentlyContinue)) {
        if (Test-Path -LiteralPath $devModulePath -PathType Leaf) {
          Import-Module $devModulePath -Force
        }
      }
      if (Get-Command Disable-IconEditorDevelopmentMode -ErrorAction SilentlyContinue) {
        try {
          if (-not $selection) {
          $selection = Resolve-DevModeSelection `
            -RepoRoot $repoRoot `
            -IconEditorRoot $sourceResolved `
            -RequestedVersions $DevModeVersions `
            -RequestedBitness $DevModeBitness `
            -VersionsSpecified ($PSBoundParameters.ContainsKey('DevModeVersions')) `
            -BitnessSpecified ($PSBoundParameters.ContainsKey('DevModeBitness')) `
            -DevModulePath $devModulePath `
            -Operation $DevModeOperation
        }
        Disable-IconEditorDevelopmentMode `
          -RepoRoot $repoRoot `
          -IconEditorRoot $sourceResolved `
          -Versions $selection.Versions `
          -Bitness $selection.Bitness `
          -Operation $DevModeOperation | Out-Null
        } catch {
          Write-Warning ("Failed to disable icon editor development mode: {0}" -f $_.Exception.Message)
        }
      } else {
        Write-Warning 'Disable-IconEditorDevelopmentMode not available; icon-editor dev mode may remain enabled.'
      }
    }
  }
}

$sessionIndexPath = Join-Path $stageRoot 'session-index.json'
$sessionIndex = [ordered]@{
  schema         = 'icon-editor/snapshot-session@v1'
  generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  label          = $stageResolvedName
  stage          = [ordered]@{
    root          = $stageRoot
    workspaceRoot = $workspaceResolved
    sourcePath    = $sourceResolved
  }
  fixture        = [ordered]@{
    fixturePath          = $fixtureResolved
    baselineFixturePath  = $baselineFixtureResolved
    headManifestPath     = $headManifestPath
    headReportPath       = $headReportPath
    baselineManifestPath = $baselineManifestResolved
  }
  overlay        = $overlayResolved
  validation     = [ordered]@{
    enabled    = -not $SkipValidate.IsPresent
    resultsRoot = if ($SkipValidate.IsPresent) { $null } else { $validateRoot }
  }
  devMode        = [ordered]@{
    requested = (-not $SkipDevMode.IsPresent) -and (-not $SkipValidate.IsPresent)
    enabled   = $devModeEnabled
    versions  = if ($selection) { $selection.Versions } else { @() }
    bitness   = if ($selection) { $selection.Bitness } else { @() }
    operation = $DevModeOperation
  }
  artifacts      = [ordered]@{
    stageRoot        = $stageRoot
    sessionIndexPath = $sessionIndexPath
    validateRoot     = if ($SkipValidate.IsPresent) { $null } else { $validateRoot }
    fixtureReport    = $headReportPath
    fixtureManifest  = $headManifestPath
  }
}
$sessionIndex | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $sessionIndexPath -Encoding utf8

[pscustomobject]@{
  stageRoot         = $stageRoot
  mirrorPath        = $sourceResolved
  resourceOverlay   = $overlayResolved
  headManifestPath  = $headManifestPath
  headReportPath    = $headReportPath
  validateRoot      = $validateRoot
  fixturePath       = $fixtureResolved
  baselineFixture   = $baselineFixtureResolved
  baselineManifest  = $baselineManifestResolved
  skipValidate      = $SkipValidate.IsPresent
  skipLVCompare     = $SkipLVCompare.IsPresent
  dryRun            = $DryRun.IsPresent
  stageExecuted     = $true
  sessionIndexPath  = $sessionIndexPath
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
