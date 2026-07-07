#Requires -Version 7.0
<#
.SYNOPSIS
    Enforces the LabVIEW version contract against .lvversion.

.DESCRIPTION
    Reads .lvversion from the repo and compares it with any declared or expected
    LabVIEW version inputs (parameters or environment variables). Throws when
    a mismatch is detected unless AllowMismatch is specified.

.PARAMETER RepoRoot
    Repository root that contains .lvversion.

.PARAMETER ExpectedVersion
    Optional expected version (year or numeric, e.g. 2021 or 21.0) to compare
    against .lvversion.

.PARAMETER AllowMismatch
    If set, mismatches are reported as warnings instead of errors.

.PARAMETER Context
    Optional context label used in messages.

.PARAMETER WriteSummary
    When set, write a summary entry to the GitHub Step Summary file.

.PARAMETER SummaryPath
    Optional override path for summary output (defaults to GITHUB_STEP_SUMMARY).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$ExpectedVersion,

    [switch]$AllowMismatch,

    [Parameter(Mandatory = $false)]
    [string]$Context,

    [switch]$WriteSummary,

    [Parameter(Mandatory = $false)]
    [string]$SummaryPath
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'RepoRoot is required.'
    }

    return (Resolve-Path -Path $Path -ErrorAction Stop).Path
}

function Resolve-VersionInput {
    param([string]$Year, [string]$Minor)

    if ([string]::IsNullOrWhiteSpace($Year)) {
        if (-not [string]::IsNullOrWhiteSpace($Minor)) {
            throw "LabVIEW version year is required when a minor revision is provided."
        }
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($Minor)) {
        return $Year
    }

    return "$Year.$Minor"
}

function Add-DeclaredVersion {
    param(
        [string]$Source,
        [string]$VersionInput,
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($VersionInput)) {
        return $null
    }

    $info = Get-LabVIEWVersionInfo -VersionInput $VersionInput -RepoRoot $RepoRoot
    return [pscustomobject]@{
        Source        = $Source
        Raw           = $info.Raw
        Year          = $info.Year
        MinorRevision = [int]$info.MinorRevision
    }
}

function Resolve-SummaryPath {
    param([string]$OverridePath)

    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return $OverridePath
    }

    return $env:GITHUB_STEP_SUMMARY
}

function Write-VersionSummary {
    param(
        [string]$Path,
        [string]$ContextLabel,
        [string]$Status,
        [pscustomobject]$RepoInfo,
        [string[]]$Mismatches,
        [string]$Guidance
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $lines = @()
    $lines += "## LabVIEW Version Contract"
    if (-not [string]::IsNullOrWhiteSpace($ContextLabel)) {
        $lines += "- Context: $ContextLabel"
    }
    $lines += ("- .lvversion: {0} (year {1}, minor {2})" -f $RepoInfo.Raw, $RepoInfo.Year, $RepoInfo.MinorRevision)
    $lines += ("- Status: {0}" -f $Status)
    if ($Mismatches -and $Mismatches.Count -gt 0) {
        $lines += ("- Mismatches: {0}" -f ($Mismatches -join '; '))
    }
    if (-not [string]::IsNullOrWhiteSpace($Guidance)) {
        $lines += ("- Guidance: {0}" -f $Guidance)
    }
    $lines += ""

    $lines | Out-File -FilePath $Path -Append -Encoding utf8
}

$repoRootResolved = Resolve-RepoRoot -Path $RepoRoot
$versionHelper = Join-Path $repoRootResolved 'Tooling/support/LabVIEWVersion.ps1'
if (-not (Test-Path -Path $versionHelper)) {
    throw "LabVIEW version helper not found at $versionHelper"
}

. $versionHelper

$repoInfo = Get-LabVIEWVersionInfo -RepoRoot $repoRootResolved
$repoYear = [string]$repoInfo.Year
$repoMinor = [int]$repoInfo.MinorRevision

$declared = @()

if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
    $declared += Add-DeclaredVersion -Source 'expected' -VersionInput $ExpectedVersion -RepoRoot $repoRootResolved
}

$requiredVersion = $env:LVIE_REQUIRED_LABVIEW_VERSION
if (-not [string]::IsNullOrWhiteSpace($requiredVersion)) {
    $declared += Add-DeclaredVersion -Source 'LVIE_REQUIRED_LABVIEW_VERSION' -VersionInput $requiredVersion -RepoRoot $repoRootResolved
}

$requiredFromParts = Resolve-VersionInput -Year $env:LVIE_REQUIRED_LABVIEW_VERSION_YEAR -Minor $env:LVIE_REQUIRED_LABVIEW_MINOR_REVISION
if ($requiredFromParts) {
    $declared += Add-DeclaredVersion -Source 'LVIE_REQUIRED_LABVIEW_VERSION_YEAR/MINOR' -VersionInput $requiredFromParts -RepoRoot $repoRootResolved
}

$envFromParts = Resolve-VersionInput -Year $env:LABVIEW_VERSION_YEAR -Minor $env:LABVIEW_MINOR_REVISION
if ($envFromParts) {
    $declared += Add-DeclaredVersion -Source 'LABVIEW_VERSION_YEAR/MINOR' -VersionInput $envFromParts -RepoRoot $repoRootResolved
}

$declared = $declared | Where-Object { $_ }

$mismatches = @()
foreach ($entry in $declared) {
    if ($entry.Year -ne $repoYear -or $entry.MinorRevision -ne $repoMinor) {
        $mismatches += ("{0}={1} (year {2}, minor {3})" -f $entry.Source, $entry.Raw, $entry.Year, $entry.MinorRevision)
    }
}

$contextLabel = if ([string]::IsNullOrWhiteSpace($Context)) { '' } else { " [$Context]" }
$baseMessage = "LabVIEW version contract${contextLabel}: .lvversion=$($repoInfo.Raw) (year $repoYear, minor $repoMinor)."
$guidance = "Update .lvversion or remove overrides (LVIE_REQUIRED_LABVIEW_VERSION*, LABVIEW_VERSION_YEAR/MINOR). For local runs, pass -AllowVersionMismatch to bypass."
$summaryPath = $null
if ($WriteSummary) {
    $summaryPath = Resolve-SummaryPath -OverridePath $SummaryPath
    if ([string]::IsNullOrWhiteSpace($summaryPath)) {
        Write-Warning "WriteSummary requested, but no summary path was provided and GITHUB_STEP_SUMMARY is not set."
    }
}

if ($mismatches.Count -gt 0) {
    $details = "Mismatched declarations: {0}" -f ($mismatches -join '; ')
    $message = "$baseMessage $details $guidance"
    $summaryStatus = if ($AllowMismatch) { 'warning' } else { 'failed' }
    if ($summaryPath) {
        Write-VersionSummary -Path $summaryPath -ContextLabel $Context -Status $summaryStatus -RepoInfo $repoInfo -Mismatches $mismatches -Guidance $guidance
    }
    if ($AllowMismatch) {
        Write-Warning $message
    } else {
        throw $message
    }
} else {
    if ($summaryPath) {
        Write-VersionSummary -Path $summaryPath -ContextLabel $Context -Status 'ok' -RepoInfo $repoInfo -Mismatches @() -Guidance $null
    }
    Write-Host "$baseMessage OK."
}

Write-Output $repoInfo

