#Requires -Version 7.0
<#
.SYNOPSIS
    Runs Invoke-CIParity.ps1 using the LabVIEW version from .lvversion.
#>

[CmdletBinding()]
param(
    [switch]$EnsureCleanState,
    [switch]$CleanRoom,
    [switch]$AutoLoop,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$MaxAttempts = 5,

    [Parameter(Mandatory = $false)]
    [ValidateSet('both', '32', '64', 'installed')]
    [string]$LabVIEWBitness = 'installed',

    [switch]$SkipVerifyIEPaths,
    [switch]$SkipVipc,
    [switch]$SkipMissingInProject,
    [switch]$SkipUnitTests,
    [switch]$SkipBuildPpl,
    [switch]$SkipBuildVip,

    [Parameter(Mandatory = $false)]
    [bool]$UseWorktree = $true,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeName,

    [Parameter(Mandatory = $false)]
    [string]$Ref = 'HEAD',

    [Parameter(Mandatory = $false)]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactRoot,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [switch]$SkipWorktreeRootCheck
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$PathOverride)

    if ($PathOverride) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$versionPath = Join-Path $repoRoot '.lvversion'
if (-not (Test-Path -Path $versionPath)) {
    throw ".lvversion not found at $versionPath"
}

$labviewVersion = (Get-Content -Path $versionPath -ErrorAction Stop | Select-Object -First 1)
if ($labviewVersion -isnot [string]) {
    $labviewVersion = [string]$labviewVersion
}
$labviewVersion = $labviewVersion.Trim()
if ([string]::IsNullOrWhiteSpace($labviewVersion)) {
    throw ".lvversion is empty at $versionPath"
}

$versionHelper = Join-Path $repoRoot 'Tooling\support\LabVIEWVersion.ps1'
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    try {
        $labviewInfo = Get-LabVIEWVersionInfo -VersionInput $labviewVersion -RepoRoot $repoRoot
        if ($labviewInfo -and -not [string]::IsNullOrWhiteSpace($labviewInfo.Year)) {
            $labviewVersion = $labviewInfo.Year
        }
    } catch {
        Write-Warning ("Failed to normalize LabVIEW version '{0}': {1}" -f $labviewVersion, $_.Exception.Message)
    }
}

$invokeScript = Join-Path $repoRoot 'Tooling/Invoke-CIParity.ps1'
if (-not (Test-Path -Path $invokeScript)) {
    throw "Invoke-CIParity.ps1 not found at $invokeScript"
}

$invokeParams = @{
    LabVIEWVersion = $labviewVersion
    RepoRoot       = $repoRoot
}

if ($EnsureCleanState) { $invokeParams.EnsureCleanState = $true }
if ($CleanRoom) { $invokeParams.CleanRoom = $true }
if ($AutoLoop) {
    $invokeParams.AutoLoop = $true
    $invokeParams.MaxAttempts = $MaxAttempts
}

$invokeParams.LabVIEWBitness = $LabVIEWBitness

if ($SkipVerifyIEPaths) { $invokeParams.SkipVerifyIEPaths = $true }
if ($SkipVipc) { $invokeParams.SkipVipc = $true }
if ($SkipMissingInProject) { $invokeParams.SkipMissingInProject = $true }
if ($SkipUnitTests) { $invokeParams.SkipUnitTests = $true }
if ($SkipBuildPpl) { $invokeParams.SkipBuildPpl = $true }
if ($SkipBuildVip) { $invokeParams.SkipBuildVip = $true }

if ($PSBoundParameters.ContainsKey('UseWorktree')) { $invokeParams.UseWorktree = $UseWorktree }
if ($PSBoundParameters.ContainsKey('WorktreeRoot')) { $invokeParams.WorktreeRoot = $WorktreeRoot }
if ($PSBoundParameters.ContainsKey('WorktreeName')) { $invokeParams.WorktreeName = $WorktreeName }
if ($PSBoundParameters.ContainsKey('Ref')) { $invokeParams.Ref = $Ref }
if ($PSBoundParameters.ContainsKey('RunId')) { $invokeParams.RunId = $RunId }
if ($PSBoundParameters.ContainsKey('ArtifactRoot')) { $invokeParams.ArtifactRoot = $ArtifactRoot }
if ($SkipWorktreeRootCheck) { $invokeParams.SkipWorktreeRootCheck = $true }

& $invokeScript @invokeParams
