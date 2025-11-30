#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [Parameter(Mandatory)][string]$ScenarioPath,
    [string[]]$ProbeRoots,
    [string]$OutputRoot,
[string]$BundleOutputDirectory = '.tmp-tests/vi-compare-bundles',
[string]$LabVIEWExePath = 'C:\Program Files\National Instruments\LabVIEW 2025\LabVIEW.exe',
[string]$NoiseProfile = 'full',
    [switch]$IgnoreAttributes,
    [switch]$IgnoreFrontPanel,
    [switch]$IgnoreFrontPanelPosition,
    [switch]$IgnoreBlockDiagram,
    [switch]$IgnoreBlockDiagramCosmetics,
    [switch]$DryRun,
    [switch]$SkipBundle
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Root)
    if ([string]::IsNullOrWhiteSpace($Root)) {
        return (Resolve-Path '.').Path
    }
    return (Get-Item $Root).FullName
}

$RepoRoot = Resolve-RepoRoot -Root $RepoRoot

$probeHelperPath = Join-Path $RepoRoot 'tools/icon-editor/LabVIEWCliProbe.ps1'
if (-not (Test-Path -LiteralPath $probeHelperPath -PathType Leaf)) {
    throw "LabVIEW CLI probe helper not found at $probeHelperPath"
}
. $probeHelperPath

$labviewProbe = Invoke-LabVIEWCliProbe -LabVIEWExePath $LabVIEWExePath -MinimumVersionYear 2025 -RepoRoot $RepoRoot
if ($labviewProbe.Message) {
    $messagePrefix = '[vi-replay]'
    if ($labviewProbe.IsSupportedVersion) {
        Write-Host ("{0} {1}" -f $messagePrefix, $labviewProbe.Message)
    } else {
        Write-Warning ("{0} {1}" -f $messagePrefix, $labviewProbe.Message)
    }
}
if ($labviewProbe.DevMode -and $labviewProbe.DevMode.message) {
    $messagePrefix = '[vi-replay]'
    if ($labviewProbe.DevModeReady) {
        Write-Host ("{0} {1}" -f $messagePrefix, $labviewProbe.DevMode.message)
    } else {
        Write-Warning ("{0} {1}" -f $messagePrefix, $labviewProbe.DevMode.message)
    }
}
$labviewReady = $labviewProbe.IsAvailable -and $labviewProbe.IsSupportedVersion -and $labviewProbe.DevModeReady

if (-not (Test-Path -LiteralPath $ScenarioPath -PathType Leaf)) {
    throw "ScenarioPath not found: $ScenarioPath"
}

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $RepoRoot (Join-Path '.tmp-tests/vi-compare-replays' (Get-Date -Format 'yyyyMMdd-HHmmss'))
}

if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
}

if ($ProbeRoots) {
    $ProbeRoots = $ProbeRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

if (-not $ProbeRoots -or $ProbeRoots.Count -eq 0) {
    $ProbeRoots = @((Split-Path -Parent $ScenarioPath), $RepoRoot)
}

Write-Host "[vi-replay] Running scenario $ScenarioPath"

$cliScript = Join-Path $RepoRoot 'local-ci/windows/scripts/Invoke-ViCompareLabVIEWCli.ps1'
if (-not (Test-Path -LiteralPath $cliScript -PathType Leaf)) {
    throw "Invoke-ViCompareLabVIEWCli.ps1 not found at $cliScript"
}

$sessionRoot = Join-Path $RepoRoot '.tmp-tests/vi-compare-sessions'
$invokeArgs = @{
    RepoRoot       = $RepoRoot
    RequestsPath   = $ScenarioPath
    OutputRoot     = $OutputRoot
    ProbeRoots     = $ProbeRoots
    SessionRoot    = $sessionRoot
    LabVIEWExePath = $LabVIEWExePath
    NoiseProfile   = $NoiseProfile
}
if ($IgnoreAttributes) { $invokeArgs['IgnoreAttributes'] = $true }
if ($IgnoreFrontPanel) { $invokeArgs['IgnoreFrontPanel'] = $true }
if ($IgnoreFrontPanelPosition) { $invokeArgs['IgnoreFrontPanelPosition'] = $true }
if ($IgnoreBlockDiagram) { $invokeArgs['IgnoreBlockDiagram'] = $true }
if ($IgnoreBlockDiagramCosmetics) { $invokeArgs['IgnoreBlockDiagramCosmetics'] = $true }
if ($DryRun -or -not $labviewReady) {
    if (-not $DryRun -and -not $labviewReady) {
        $reason = $labviewProbe.Message
        if ($labviewProbe.DevMode -and -not $labviewProbe.DevModeReady -and $labviewProbe.DevMode.message) {
            $reason = $labviewProbe.DevMode.message
        }
        if (-not $reason) {
            $reason = 'LabVIEW CLI probe failed or version unsupported.'
        }
        Write-Warning "[vi-replay] $reason Replay will run in dry-run mode."
    }
    $invokeArgs['DryRun'] = $true
}

& $cliScript @invokeArgs

[string]$bundlePath = $null
if (-not $SkipBundle) {
    $bundleRoot = if ([System.IO.Path]::IsPathRooted($BundleOutputDirectory)) {
        $BundleOutputDirectory
    } else {
        Join-Path $RepoRoot $BundleOutputDirectory
    }
    if (-not (Test-Path -LiteralPath $bundleRoot -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null
    }

    $bundleName = "vi-compare-{0}.zip" -f (Split-Path -Leaf $OutputRoot)
    $bundlePath = Join-Path $bundleRoot $bundleName
    if (Test-Path -LiteralPath $bundlePath -PathType Leaf) {
        Remove-Item -LiteralPath $bundlePath -Force
    }
    Compress-Archive -Path (Join-Path $OutputRoot '*') -DestinationPath $bundlePath -Force
    Write-Host ("[vi-replay] Bundled vi-compare artifacts to {0}" -f $bundlePath)
}

[pscustomobject]@{
    ScenarioPath = $ScenarioPath
    OutputRoot   = $OutputRoot
    NoiseProfile = $NoiseProfile
    IgnoreAttributes = [bool]$IgnoreAttributes
    IgnoreFrontPanel = [bool]$IgnoreFrontPanel
    IgnoreFrontPanelPosition = [bool]$IgnoreFrontPanelPosition
    IgnoreBlockDiagram = [bool]$IgnoreBlockDiagram
    IgnoreBlockDiagramCosmetics = [bool]$IgnoreBlockDiagramCosmetics
    DryRun       = [bool]($DryRun -or -not $labviewReady)
    LabVIEWExePath = $LabVIEWExePath
    LabVIEWReady   = $labviewReady
    LabVIEWProbeStatus = $labviewProbe.Status
    LabVIEWProbeLogPath = $labviewProbe.LogPath
    LabVIEWVersion = $labviewProbe.Version
    LabVIEWDevMode = $labviewProbe.DevMode
    LabVIEWIniPath = $labviewProbe.LabVIEWIniPath
    BundlePath   = $bundlePath
}
