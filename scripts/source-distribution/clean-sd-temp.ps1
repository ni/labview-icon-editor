[CmdletBinding()]
param(
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..')).Path
$targets = @(
    @{ Path = Join-Path $repoRoot 'artifacts/sd-bundle-extract-check'; Description = 'Extract check output'; Type = 'Directory' },
    @{ Path = Join-Path $repoRoot 'artifacts/labview-icon-editor-labview-icon-api/tmp-restore'; Description = 'Tmp restore from bundle rebuild'; Type = 'Directory' }
)

# Temp sd-bundle-* folders
$tempDirs = Get-ChildItem -Path $env:TEMP -Directory -Filter 'sd-bundle-*' -ErrorAction SilentlyContinue
foreach ($d in $tempDirs) {
    $targets += @{ Path = $d.FullName; Description = 'Temp sd-bundle folder'; Type = 'Directory' }
}

if ($targets.Count -eq 0) {
    Write-Host '[clean] Nothing to do.'
    return
}

foreach ($t in $targets) {
    $path = $t.Path
    if (-not (Test-Path -LiteralPath $path)) { continue }
    if ($ListOnly) {
        Write-Host ("[clean][preview] would remove: {0}" -f $path)
        continue
    }
    try {
        Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
        Write-Host ("[clean] removed: {0}" -f $path)
    }
    catch {
        Write-Warning ("[clean] failed to remove {0}: {1}" -f $path, $_.Exception.Message)
    }
}
