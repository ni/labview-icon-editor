[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CliName,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$Rid = 'win-x64'
)

<#
.SYNOPSIS
    Clears a specific repo CLI cache entry and verifies republish-on-miss behaviour on next run.

.DESCRIPTION
    Deletes the tooling cache directory for the given <CLI>/<version>/<rid> under the OS-specific root:
      - Windows: %LOCALAPPDATA%\labview-icon-editor\tooling-cache\<CLI>\<version>\<rid>\publish\
      - POSIX:   $HOME/.cache/labview-icon-editor/tooling-cache/<CLI>/<version>/<rid>/publish/
    After removal, the next invocation of the CLI helper should republish on cache miss and recreate the directory.
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-CacheRoot {
    param([string]$Cli, [string]$Ver, [string]$Runtime)
    if ($env:LOCALAPPDATA) {
        return Join-Path $env:LOCALAPPDATA "labview-icon-editor\tooling-cache\$Cli\$Ver\$Runtime\publish"
    }
    elseif ($env:HOME) {
        return Join-Path $env:HOME ".cache/labview-icon-editor/tooling-cache/$Cli/$Ver/$Runtime/publish"
    }
    else {
        throw "Neither LOCALAPPDATA nor HOME is set; cannot determine cache root."
    }
}

$cachePath = Get-CacheRoot -Cli $CliName -Ver $Version -Runtime $Rid
Write-Host ("Target cache key        : {0}/{1}/{2}" -f $CliName, $Version, $Rid) -ForegroundColor Cyan
Write-Host ("Cache publish directory : {0}" -f $cachePath) -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $cachePath -PathType Container)) {
    Write-Host "Nothing to clear; cache directory not found." -ForegroundColor Yellow
    exit 0
}

$parent = Split-Path -Parent $cachePath
Write-Host ("Removing cache directory: {0}" -f $cachePath) -ForegroundColor Yellow
Remove-Item -LiteralPath $cachePath -Recurse -Force -ErrorAction Stop

# If parent is empty, leave it; safest not to remove higher levels automatically.
Write-Host "Cleared. Next CLI run should republish on cache miss." -ForegroundColor Green
