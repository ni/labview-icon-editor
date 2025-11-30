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

function Ensure-StandardTempPath {
    param([string]$Label = 'labview-icon-editor')
    $base = $null
    if ($IsWindows) {
        $base = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Temp' } else { $env:TEMP }
    } else {
        $base = '/tmp'
    }

    $target = if ($base) { Join-Path $base $Label } else { $null }
    $created = New-TempDir -Path $target

    if (-not $created) {
        $fallback = Join-Path (Get-Location).Path (Join-Path '.tmp' $Label)
        $created = New-TempDir -Path $fallback
    }

    if (-not $created) {
        throw "Failed to create a writable temp directory for label '$Label'. Checked base '$base' and repo-local fallback."
    }

    if ($IsWindows) {
        $env:TMP = $created
        $env:TEMP = $created
    } else {
        $env:TMPDIR = $created
    }

    Write-Host ("[temp] Using temp directory: {0}" -f $created)
    return $created
}

# If invoked directly, run the helper; if dot-sourced, the function is available to caller.
if ($MyInvocation.InvocationName -notin @('.', '&')) {
    Ensure-StandardTempPath -Label $Label | Out-Null
}
