<#
.SYNOPSIS
    Ensures a per-repo temp directory exists and sets temp env vars to it.

.DESCRIPTION
    Picks a user-writable temp base per-OS and creates a subfolder (label).
    - Windows: %LOCALAPPDATA%\Temp\<label>
    - Others:  /tmp/<label>
    Falls back to ./\.tmp/<label> if creation fails. Throws on failure.

.PARAMETER Label
    Subfolder name to use for the temp directory (default: labview-icon-editor).

.OUTPUTS
    The full path to the temp directory.
#>
param(
    [string]$Label = 'labview-icon-editor'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function New-TempDir {
    param([string]$Path)
    if (-not $Path) { return $null }
    try {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
        return $Path
    }
    catch {
        return $null
    }
}

function Get-OneDriveRoots {
    $roots = @()
    foreach ($envVar in @('OneDrive', 'OneDriveCommercial', 'OneDriveConsumer')) {
        $val = Get-Item -Path Env:$envVar -ErrorAction SilentlyContinue
        if ($val -and $val.Value) {
            try {
                $roots += (Resolve-Path -LiteralPath $val.Value -ErrorAction Stop).Path
            }
            catch {
                $roots += $val.Value
            }
        }
    }
    return $roots | Where-Object { $_ } | Sort-Object -Unique
}

function Is-OneDrivePath {
    param([string]$Path,[string[]]$KnownRoots)
    if (-not $Path) { return $false }
    $normalized = $Path.Replace('/', '\').ToLowerInvariant()
    foreach ($root in $KnownRoots) {
        if (-not $root) { continue }
        $rootNorm = $root.Replace('/', '\').ToLowerInvariant().TrimEnd('\')
        if ($normalized.StartsWith($rootNorm + '\', [StringComparison]::OrdinalIgnoreCase) -or $normalized -eq $rootNorm) {
            return $true
        }
    }
    return $normalized -like '*\onedrive\*'
}

function Ensure-StandardTempPath {
    param([string]$Label = 'labview-icon-editor')
    $created = $null
    $baseChosen = $null
    $oneDriveRoots = Get-OneDriveRoots

    if ($IsWindows) {
        $candidates = New-Object System.Collections.Generic.List[string]
        if ($env:LOCALAPPDATA) { $candidates.Add((Join-Path $env:LOCALAPPDATA 'Temp')) }
        if ($env:TEMP) { $candidates.Add($env:TEMP) }
        if ($env:TMP) { $candidates.Add($env:TMP) }
        $candidates.Add('C:\Temp')

        foreach ($cand in $candidates) {
            if (-not $cand) { continue }
            if (Is-OneDrivePath -Path $cand -KnownRoots $oneDriveRoots) { continue }
            $target = Join-Path $cand $Label
            $created = New-TempDir -Path $target
            if ($created) { $baseChosen = $cand; break }
        }
    }
    else {
        $created = New-TempDir -Path (Join-Path '/tmp' $Label)
        $baseChosen = '/tmp'
    }

    if (-not $created) {
        $fallback = Join-Path (Get-Location).Path (Join-Path '.tmp' $Label)
        $created = New-TempDir -Path $fallback
        $baseChosen = $fallback
    }

    if (-not $created) {
        throw "Failed to create a writable temp directory for label '$Label'."
    }

    if ($IsWindows) {
        $env:TMP = $created
        $env:TEMP = $created
    } else {
        $env:TMPDIR = $created
    }

    if (Is-OneDrivePath -Path $baseChosen -KnownRoots $oneDriveRoots) {
        Write-Host ("[temp] Avoided OneDrive; using fallback temp directory: {0}" -f $created)
    }
    else {
        Write-Host ("[temp] Using temp directory: {0}" -f $created)
    }
    return $created
}

# If invoked directly, run the helper; if dot-sourced, the function is available to caller.
if ($MyInvocation.InvocationName -notin @('.', '&')) {
    Ensure-StandardTempPath -Label $Label | Out-Null
}
