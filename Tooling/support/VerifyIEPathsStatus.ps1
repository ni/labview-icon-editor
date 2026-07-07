#Requires -Version 7.0
<#
.SYNOPSIS
    Helpers for locating and parsing VerifyIEPaths status files.
#>

function Resolve-VerifyIEPathsStatusFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [string]$StatusFileName,
        [datetime]$StartTimeUtc
    )

    if (-not [string]::IsNullOrWhiteSpace($StatusFileName)) {
        if ([System.IO.Path]::IsPathRooted($StatusFileName)) {
            return $StatusFileName
        }
        return (Join-Path -Path $RepoRoot -ChildPath $StatusFileName)
    }

    if (-not $StartTimeUtc) {
        $StartTimeUtc = (Get-Date).ToUniversalTime()
    }

    $candidates = Get-ChildItem -Path $RepoRoot -File -Filter '*.txt' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -ge $StartTimeUtc } |
        Sort-Object -Property LastWriteTimeUtc -Descending

    $match = $candidates | Select-Object -First 1
    if ($match) {
        return $match.FullName
    }

    return $null
}

function Get-VerifyIEPathsStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StatusFilePath,
        [string]$SuccessPattern,
        [string]$FailurePattern
    )

    if (-not (Test-Path -Path $StatusFilePath)) {
        throw "Status file not found: $StatusFilePath"
    }

    $raw = Get-Content -Path $StatusFilePath -Raw -ErrorAction Stop
    if ($null -eq $raw) {
        $raw = ''
    }
    $trimmed = $raw.Trim()

    $isFailure = $false
    $isSuccess = $false

    if ($trimmed.Length -eq 0) {
        $isSuccess = $true
    } else {
        if (-not [string]::IsNullOrWhiteSpace($FailurePattern)) {
            $isFailure = ($trimmed -match $FailurePattern)
        }
        if (-not [string]::IsNullOrWhiteSpace($SuccessPattern)) {
            $isSuccess = ($trimmed -match $SuccessPattern)
        }

        if (-not $isFailure -and -not $isSuccess) {
            $isFailure = $true
        }
    }

    $missingPaths = @()
    if ($trimmed.Length -gt 0) {
        $missingPaths = $trimmed -split '\s*,\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    return [pscustomobject]@{
        Path      = $StatusFilePath
        RawStatus = $trimmed
        IsSuccess = $isSuccess
        IsFailure = $isFailure
        IsUnknown = (-not $isSuccess -and -not $isFailure)
        MissingPaths = $missingPaths
    }
}
