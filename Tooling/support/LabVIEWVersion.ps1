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

    $raw = $VersionInput
    if ([string]::IsNullOrWhiteSpace($raw)) {
        if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
            throw "RepoRoot is required when VersionInput is not provided."
        }

        $versionPath = Join-Path -Path $RepoRoot -ChildPath '.lvversion'
        if (-not (Test-Path -Path $versionPath)) {
            throw ".lvversion not found at $versionPath"
        }

        $raw = (Get-Content -Raw -Path $versionPath).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "LabVIEW version input is empty."
    }

    if (-not ($raw -match '^(?<major>\d{2,4})(?:\.(?<minor>\d+))?$')) {
        throw "LabVIEW version '$raw' is invalid. Expected formats like '21.0' or '2021'."
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
        throw "LabVIEW version '$raw' produced an invalid numeric major."
    }

    [pscustomobject]@{
        Raw            = $raw
        Year           = $year.ToString()
        MinorRevision  = $minor
        NumericMajor   = $numericMajor
        NumericVersion = "$numericMajor.$minor"
    }
}
