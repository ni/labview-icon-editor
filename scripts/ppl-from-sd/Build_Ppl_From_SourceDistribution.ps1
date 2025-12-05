<#
.SYNOPSIS
    Build the Editor PPL from a Source Distribution zip without relying on git metadata.

.DESCRIPTION
    Extracts the source-distribution zip, copies required tooling/scripts into the extracted tree,
    binds dev-mode to the extracted path, and runs Build_lvlibp.ps1 for the requested bitness/version.
    Suitable for offline/self-contained PPL builds from an SD artifact.

.PARAMETER RepositoryPath
    Path to the repo that contains the source-distribution zip and tooling/scripts to copy.

.PARAMETER SourceDistZip
    Path to source-distribution.zip (default: builds/artifacts/source-distribution.zip under RepositoryPath).

.PARAMETER ExtractRoot
    Target directory to extract the SD into (default: builds/ppl-from-sd/<timestamp>).

.PARAMETER Package_LabVIEW_Version
    LabVIEW version to use (e.g., 2021).

.PARAMETER SupportedBitness
    Bitness to build (32 or 64).

.PARAMETER Major/Minor/Patch/Build
    Version numbers to stamp into the PPL when git metadata is absent.
#>
param(
    [Parameter(Mandatory)][string]$RepositoryPath,
    [string]$SourceDistZip,
    [string]$ExtractRoot,
    [string]$Package_LabVIEW_Version = "2021",
    [ValidateSet('32','64')][string]$SupportedBitness = "64",
    [int]$Major = 0,
    [int]$Minor = 1,
    [int]$Patch = 0,
    [int]$Build = 0,
    [switch]$UseExistingExtract
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
if (-not $SourceDistZip) {
    $SourceDistZip = Join-Path $repo 'builds\artifacts\source-distribution.zip'
}
if (-not (Test-Path -LiteralPath $SourceDistZip -PathType Leaf)) {
    throw "Source distribution zip not found at $SourceDistZip. Run task 20 (Build: Source Distribution) first, or pass -SourceDistZip <path>."
}

if (-not $ExtractRoot) {
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $ExtractRoot = Join-Path $repo "builds\ppl-from-sd\$stamp"
}

$skipExtract = $UseExistingExtract.IsPresent -and (Test-Path -LiteralPath $ExtractRoot -PathType Container) -and (Test-Path -LiteralPath (Join-Path $ExtractRoot 'lv_icon_editor.lvproj'))
if ($skipExtract) {
    Write-Host ("[ppl-sd] Reusing existing extract at {0}" -f $ExtractRoot)
}
else {
    if (Test-Path -LiteralPath $ExtractRoot) {
        Remove-Item -LiteralPath $ExtractRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $ExtractRoot -Force | Out-Null
    Write-Host ("[ppl-sd] Extracting {0} -> {1}" -f $SourceDistZip, $ExtractRoot)
    Expand-Archive -LiteralPath $SourceDistZip -DestinationPath $ExtractRoot -Force
}

# Locate extracted root that contains lv_icon_editor.lvproj
$candidateRoots = @($ExtractRoot) + (Get-ChildItem -Path $ExtractRoot -Directory -Recurse -Depth 2 | Select-Object -ExpandProperty FullName)
$sdRoot = $candidateRoots | Where-Object { Test-Path (Join-Path $_ 'lv_icon_editor.lvproj') } | Select-Object -First 1
if (-not $sdRoot) {
    throw "Could not locate lv_icon_editor.lvproj under extracted folder $ExtractRoot"
}

Write-Host ("[ppl-sd] Using extracted root: {0}" -f $sdRoot)

# Copy required tooling/scripts into extracted tree (flatten scripts to avoid scripts\scripts nesting)
$pathsToCopy = @(
    @{ src = Join-Path $repo 'scripts'; dest = Join-Path $sdRoot 'scripts'; copyChildren = $true },
    @{ src = Join-Path $repo 'Tooling'; dest = Join-Path $sdRoot 'Tooling'; copyChildren = $false }
)
foreach ($p in $pathsToCopy) {
    if (-not (Test-Path -LiteralPath $p.src)) {
        Write-Warning ("[ppl-sd] Skip copy; not found: {0}" -f $p.src)
        continue
    }
    Write-Host ("[ppl-sd] Copying {0} -> {1}" -f $p.src, $p.dest)
    if (-not (Test-Path -LiteralPath $p.dest)) { New-Item -ItemType Directory -Path $p.dest -Force | Out-Null }
    if ($p.copyChildren) {
        Get-ChildItem -LiteralPath $p.src -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $p.dest -Recurse -Force
        }
    }
    else {
        Copy-Item -LiteralPath $p.src -Destination $p.dest -Recurse -Force
    }
}

# Bind dev mode to extracted path (bitness-specific)
$bindScript = Join-Path $sdRoot 'scripts\task-devmode-bind.ps1'
if (-not (Test-Path -LiteralPath $bindScript -PathType Leaf)) {
    # Some packaging workflows nest scripts/scripts; search for the first match
    $candidate = Get-ChildItem -Path (Join-Path $sdRoot 'scripts') -Filter task-devmode-bind.ps1 -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { $bindScript = $candidate.FullName }
}
if (-not (Test-Path -LiteralPath $bindScript -PathType Leaf)) {
    throw "Dev-mode bind script not found in extracted tree (looked under $sdRoot\\scripts)"
}
Write-Host ("[ppl-sd] Binding dev mode {0}-bit to extracted root" -f $SupportedBitness)
& pwsh -NoProfile -File $bindScript -RepositoryPath $sdRoot -Mode bind -Bitness $SupportedBitness -UseWorktree:$false | Write-Output

# Run PPL build
$buildScript = Join-Path $sdRoot 'scripts\build-lvlibp\Build_lvlibp.ps1'
if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
    throw "Build_lvlibp.ps1 not found at $buildScript"
}
Write-Host ("[ppl-sd] Running lvlibp build for {0}-bit, LV {1}" -f $SupportedBitness, $Package_LabVIEW_Version)
& pwsh -NoProfile -File $buildScript `
    -RepositoryPath $sdRoot `
    -Package_LabVIEW_Version $Package_LabVIEW_Version `
    -SupportedBitness $SupportedBitness `
    -Major $Major -Minor $Minor -Patch $Patch -Build $Build `
    -Commit "source-distribution" | Write-Output

# Emit artifact paths
$pplPath = Join-Path $sdRoot 'resource\plugins\lv_icon.lvlibp'
if (Test-Path -LiteralPath $pplPath) {
    $rel = [System.IO.Path]::GetRelativePath($repo, $pplPath)
    Write-Host ("[artifact][ppl-from-sd] {0}" -f $rel)
}
else {
    Write-Warning "[ppl-sd] lv_icon.lvlibp not found in extracted tree."
}

# Optional unbind could be added here; keep bound for inspection.

Write-Host "[ppl-sd] Completed."
