#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$LabVIEWVersion,

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64', 'any')]
    [string]$Bitness = 'any',

    [Parameter(Mandatory = $false)]
    [string[]]$CachePath = @(),

    [Parameter(Mandatory = $false)]
    [switch]$FailIfMissing,

    [Parameter(Mandatory = $false)]
    [string]$SummaryPath = 'builds/status/appbuilder-cache-cleanup.json'
)

$ErrorActionPreference = 'Stop'

function Resolve-LabVIEWYearToken {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }
    $raw = $Value.Trim().ToLowerInvariant()
    if ($raw -match '^\d{4}$') {
        return $raw
    }
    if ($raw -match '^(\d{2})\.\d+$') {
        return ('20{0}' -f $Matches[1])
    }
    if ($raw -match '^(\d{4})q[1-4]') {
        return $Matches[1]
    }
    return ''
}

function Get-DefaultRoot {
    $roots = @()
    $documents = [Environment]::GetFolderPath('MyDocuments')
    if (-not [string]::IsNullOrWhiteSpace($documents)) {
        $roots += (Join-Path $documents 'LabVIEW Data')
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $roots += (Join-Path $env:LOCALAPPDATA 'National Instruments')
    }
    if (-not [string]::IsNullOrWhiteSpace($env:PROGRAMDATA)) {
        $roots += (Join-Path $env:PROGRAMDATA 'National Instruments')
    }
    return @($roots | Select-Object -Unique)
}

function Test-PathMatchesHint {
    param(
        [Parameter(Mandatory = $true)][string]$PathValue,
        [Parameter(Mandatory = $false)][string]$YearToken,
        [Parameter(Mandatory = $false)][string]$BitnessValue
    )

    $normalized = $PathValue.ToLowerInvariant()
    if ($normalized -notmatch 'appbuilder' -or $normalized -notmatch 'cache') {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($YearToken)) {
        if ($normalized -notmatch [regex]::Escape($YearToken)) {
            return $false
        }
    }

    if ($BitnessValue -eq '32') {
        if ($normalized -notmatch '32') {
            return $false
        }
    } elseif ($BitnessValue -eq '64') {
        if ($normalized -notmatch '64') {
            return $false
        }
    }

    return $true
}

$yearToken = Resolve-LabVIEWYearToken -Value $LabVIEWVersion

$candidates = New-Object System.Collections.Generic.List[string]
if ($CachePath.Count -gt 0) {
    foreach ($item in $CachePath) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $candidates.Add([System.IO.Path]::GetFullPath($item)) | Out-Null
        }
    }
} else {
    foreach ($root in (Get-DefaultRoot)) {
        if (-not (Test-Path -Path $root -PathType Container)) {
            continue
        }
        $dirs = @(Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue)
        foreach ($dir in $dirs) {
            if (Test-PathMatchesHint -PathValue $dir.FullName -YearToken $yearToken -BitnessValue $Bitness) {
                $candidates.Add($dir.FullName) | Out-Null
            }
        }
    }
}

$candidates = @($candidates | Select-Object -Unique)
$removed = New-Object System.Collections.Generic.List[string]
$failed = New-Object System.Collections.Generic.List[object]
$missing = New-Object System.Collections.Generic.List[string]

foreach ($path in $candidates) {
    if (-not (Test-Path -Path $path -PathType Container)) {
        $missing.Add($path) | Out-Null
        continue
    }
    if ($PSCmdlet.ShouldProcess($path, 'Clear AppBuilder cache directory')) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            $removed.Add($path) | Out-Null
        } catch {
            $failed.Add([pscustomobject]@{
                    path = $path
                    error = $_.Exception.Message
                }) | Out-Null
        }
    }
}

$summary = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
    requested_version = $LabVIEWVersion
    resolved_year = $yearToken
    bitness = $Bitness
    candidates = @($candidates)
    removed = @($removed)
    missing = @($missing)
    failed = @($failed)
}

$summaryTarget = $SummaryPath
if (-not [System.IO.Path]::IsPathRooted($summaryTarget)) {
    $summaryTarget = Join-Path (Get-Location).Path $summaryTarget
}
$summaryDir = Split-Path -Parent $summaryTarget
if (-not (Test-Path -Path $summaryDir -PathType Container)) {
    New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryTarget -Encoding utf8
Write-Host ("Wrote AppBuilder cache summary: {0}" -f $summaryTarget)

if ($FailIfMissing -and $candidates.Count -eq 0) {
    throw 'No AppBuilder cache directories were discovered.'
}
if ($failed.Count -gt 0) {
    throw ("AppBuilder cache cleanup completed with {0} failures." -f $failed.Count)
}
