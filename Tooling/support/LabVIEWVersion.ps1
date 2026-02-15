#Requires -Version 7.0
<#
.SYNOPSIS
    Resolve LabVIEW version details from an input string or .lvversion.

.DESCRIPTION
    Accepts a LabVIEW version input (year like "2021" or numeric like "21.0")
    and returns the corresponding year, numeric version, and minor revision.
    When VersionInput is empty, the function reads .lvversion from RepoRoot.
#>

function Get-LabVIEWVersionInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$VersionInput,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot
    )

    function ConvertFrom-LabVIEWVersion {
        param([string]$Raw)

        if ([string]::IsNullOrWhiteSpace($Raw)) {
            throw "LabVIEW version input is empty."
        }

        if (-not ($Raw -match '^(?<major>\d{2,4})(?:\.(?<minor>\d+))?$')) {
            throw "LabVIEW version '$Raw' is invalid. Expected formats like '21.0' or '2021'."
        }

        $majorRaw = [int]$Matches['major']
        $minor = if ($Matches['minor']) { [int]$Matches['minor'] } else { 0 }

        if ($majorRaw -ge 2000) {
            $year = $majorRaw
            $numericMajor = $majorRaw - 2000
        } else {
            $numericMajor = $majorRaw
            $year = 2000 + $majorRaw
        }

        if ($numericMajor -lt 0) {
            throw "LabVIEW version '$Raw' produced an invalid numeric major."
        }

        return [pscustomobject]@{
            Raw            = $Raw
            Year           = $year.ToString()
            MinorRevision  = $minor
            NumericMajor   = $numericMajor
            NumericVersion = "$numericMajor.$minor"
        }
    }

    $inputProvided = -not [string]::IsNullOrWhiteSpace($VersionInput)
    $raw = $VersionInput
    $repoRaw = $null

    if ([string]::IsNullOrWhiteSpace($raw)) {
        if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
            throw "RepoRoot is required when VersionInput is not provided."
        }

        $versionPath = Join-Path -Path $RepoRoot -ChildPath '.lvversion'
        if (-not (Test-Path -Path $versionPath)) {
            throw ".lvversion not found at $versionPath"
        }

        $repoRaw = (Get-Content -Raw -Path $versionPath).Trim()
        $raw = $repoRaw
    } elseif (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $versionPath = Join-Path -Path $RepoRoot -ChildPath '.lvversion'
        if (-not (Test-Path -Path $versionPath)) {
            throw ".lvversion not found at $versionPath"
        }
        $repoRaw = (Get-Content -Raw -Path $versionPath).Trim()
    }

    $info = ConvertFrom-LabVIEWVersion -Raw $raw

    if ($inputProvided -and -not [string]::IsNullOrWhiteSpace($repoRaw)) {
        $repoInfo = ConvertFrom-LabVIEWVersion -Raw $repoRaw
        if ($info.Year -ne $repoInfo.Year -or $info.MinorRevision -ne $repoInfo.MinorRevision) {
            throw "LabVIEW version '$($info.Raw)' does not match .lvversion '$($repoInfo.Raw)'."
        }
    }

    return $info
}
