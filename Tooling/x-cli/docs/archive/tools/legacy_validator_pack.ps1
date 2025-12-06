#requires -Version 7
<#
.SYNOPSIS
Bundles specified source files/folders into a zip with a SHA256 manifest (legacy validator ingestion).
#>

param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$TaskId,

    [Parameter(Position=1, Mandatory=$false)]
    [string]$Output = "",

    [Parameter(Position=2, Mandatory=$false)]
    [string[]]$Paths = @(),

    [ValidateSet("design","full")]
    [string]$Preset = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# 1. Determine preset paths if specified, and set default output name if needed
$presetMap = @{
    "design" = @("docs", "AGENTS.md", "scripts/validate_design.py", ".github/workflows/design-lock.yml");
    "full"   = @("docs", "AGENTS.md", "scripts/validate_design.py", ".github/workflows/design-lock.yml")
}
if ($Preset) {
    if ($Paths -and $Paths.Count -gt 0) {
        throw "Cannot specify -Paths when using -Preset."
    }
    if (-not $presetMap.ContainsKey($Preset)) {
        throw "Unknown preset '$Preset'. Available presets: $(@($presetMap.Keys) -join ', ')"
    }
    $Paths = $presetMap[$Preset]
}
if (-not $Preset) {
    if (-not $Paths -or $Paths.Count -eq 0) {
        throw "Must specify -Preset or -Paths for content to pack."
    }
}
if (-not $Output) {
    $Output = "x-cli-design-pack.zip"
}

# 2. Normalize output path (ensure .zip extension and output directory exists)
if ($Output -notlike '*.zip') { $Output = "$Output.zip" }
$outDir = Split-Path -Path $Output -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -Type Directory -Path $outDir | Out-Null
}

# Derive manifest file path next to output (as MANIFEST.json)
if ($outDir) {
    $manifestPath = Join-Path $outDir 'MANIFEST.json'
} else {
    $manifestPath = 'MANIFEST.json'
}

# 3. Resolve and validate input paths
$includeList = @()
$missingList = @()
foreach ($p in $Paths) {
    if (-not (Test-Path $p)) {
        $missingList += $p
    } else {
        $full = Resolve-Path -Path $p | Select-Object -ExpandProperty Path
        $includeList += $full
    }
}
if ($missingList) {
    Write-Warning ("Skipped missing path(s): " + ($missingList -join ', '))
}
if (-not $includeList) {
    throw "No valid input paths found to include. Aborting."
}

# 4. Gather all files from any directories for manifest listing
$filesForManifest = @()
foreach ($item in $includeList) {
    if ((Get-Item $item).PSIsContainer) {
        $filesForManifest += Get-ChildItem -LiteralPath $item -Recurse -File | Select-Object -ExpandProperty FullName
    } else {
        $filesForManifest += $item
    }
}
$filesForManifest = $filesForManifest | Sort-Object -Unique

# 5. Compute SHA256 hashes and file sizes for manifest entries
$manifestEntries = @()
$baseDir = (Get-Location).Path
foreach ($file in $filesForManifest) {
    try {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash
    } catch {
        throw "Error computing hash for $file: $($_.Exception.Message)"
    }
    $size = (Get-Item $file).Length
    $relPath = (Get-Item $file | Resolve-Path -Relative)
    $relPath = $relPath -replace '\\', '/'
    $manifestEntries += [PSCustomObject]@{
        path   = $relPath
        sha256 = $hash
        size   = $size
    }
}
$manifestJson = $manifestEntries | ConvertTo-Json -Depth 2
Set-Content -Path $manifestPath -Value $manifestJson -Encoding UTF8

# 6. Create the zip archive with all files and the manifest
Compress-Archive -LiteralPath ($includeList + $manifestPath) -DestinationPath $Output -Force

# 7. Output summary
Write-Host ("`nCreated archive: $Output")
Write-Host ("Included files: {0}" -f $filesForManifest.Count)
Write-Host ("Manifest saved as: $manifestPath")
