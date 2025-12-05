
<#
.SYNOPSIS
    Quick sanity check for a Source Distribution zip (labview-icon-api.zip).

.DESCRIPTION
    Extracts the Source Distribution zip to a temp folder, locates manifest.json,
    and verifies that each manifest entry exists and (when available) its SHA256
    matches. Emits a summary and exits 0 on success, 1 on any failure.

.PARAMETER RepositoryPath
    Repository root containing the artifacts folder (defaults to current dir).

.PARAMETER SourceDistZip
    Path to the Source Distribution zip (defaults to builds/artifacts/labview-icon-api.zip under RepositoryPath).

.PARAMETER TempRoot
    Optional override for extraction root (defaults to system temp).

.PARAMETER KeepExtract
    When set, leaves the extracted folder on disk; otherwise it is removed.
#>
[CmdletBinding()]
param(
    [string]$RepositoryPath = ".",
    [string]$SourceDistZip,
    [string]$TempRoot,
    [switch]$KeepExtract
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function New-TempDir {
    param([string]$Root, [string]$Prefix)
    $base = if ($Root) { $Root } else { [IO.Path]::GetTempPath() }
    $name = "{0}-{1}" -f $Prefix, (Get-Date -Format "yyyyMMdd-HHmmss")
    $path = Join-Path $base $name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

# Resolve repo and zip path
$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
if (-not $SourceDistZip) {
    $SourceDistZip = Join-Path $repo "builds\artifacts\labview-icon-api.zip"
}
if (-not (Test-Path -LiteralPath $SourceDistZip -PathType Leaf)) {
    throw "SourceDistZip not found: $SourceDistZip"
}

$extractPath = New-TempDir -Root $TempRoot -Prefix "sd-verify"
Write-Host ("[verify] Extracting {0} -> {1}" -f $SourceDistZip, $extractPath)
Expand-Archive -LiteralPath $SourceDistZip -DestinationPath $extractPath -Force

try {
    # Locate manifest.json
    $manifestFile = Get-ChildItem -Path $extractPath -Filter manifest.json -Recurse -File | Select-Object -First 1
    if (-not $manifestFile) {
        throw "manifest.json not found in extracted payload"
    }
    $distRoot = Split-Path -Parent $manifestFile.FullName
    Write-Host ("[verify] Using manifest: {0}" -f $manifestFile.FullName)

    $manifest = Get-Content -LiteralPath $manifestFile.FullName -Raw | ConvertFrom-Json
    if (-not $manifest) { throw "manifest.json is empty or invalid JSON" }

    $failures = @()
    $checked = 0
    foreach ($entry in $manifest) {
        $relPath = $entry.path
        if (-not $relPath) { $failures += "Missing path in manifest entry"; continue }
        $fullPath = Join-Path $distRoot $relPath
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            $failures += "Missing file: $relPath"
            continue
        }
        $hasHash = $entry.PSObject.Properties['sha256']
        if ($hasHash -and $entry.sha256) {
            try {
                $hash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
                if ($hash -ne $entry.sha256) {
                    $failures += "Hash mismatch: $relPath (expected $($entry.sha256), got $hash)"
                }
            }
            catch {
                $failures += ("Hash error for {0}: {1}" -f $relPath, $_.Exception.Message)
            }
        }
        $checked++
    }

    if ($failures.Count -gt 0) {
        Write-Host ("[verify] FAIL: {0} issue(s) found" -f $failures.Count) -ForegroundColor Red
        $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
        exit 1
    }
    else {
        Write-Host ("[verify] PASS: {0} files verified." -f $checked) -ForegroundColor Green
        exit 0
    }
}
finally {
    if (-not $KeepExtract) {
        try { Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
    else {
        Write-Host ("[verify] Keeping extract at {0}" -f $extractPath)
    }
}
