[CmdletBinding()]
param(
    [ValidateSet('vip+lvlibp','vip-single')]
    [string]$BuildMode = 'vip+lvlibp',
    [string]$WorkspacePath,
    [string]$LabVIEWMinorRevision = '3',
    [string]$LabVIEWVersion = '2021',
    [string]$CompanyName,
    [string]$AuthorName,
    [string]$LvlibpBitness = '64',
    [string]$VipbPath,
    [switch]$Simulate,
    [switch]$SkipDevMode
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-PathSafe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try { return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath } catch { return $Path }
}

function Resolve-RepoRoot {
    param([string]$BasePath)
    $resolved = Resolve-PathSafe -Path $BasePath
    if ($resolved) { return $resolved }
    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        return (Get-Location).ProviderPath
    }
    return $BasePath
}

$PackageRoot = Resolve-RepoRoot -BasePath $WorkspacePath
if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "Workspace path not found: $PackageRoot"
}

# Metadata
$metaScript = Join-Path $PSScriptRoot 'build\meta\Get-BuildMetadata.ps1'
if (-not (Test-Path -LiteralPath $metaScript -PathType Leaf)) {
    throw "Metadata helper not found at $metaScript"
}
$meta = & pwsh -NoProfile -File $metaScript `
    -RepoRoot $PackageRoot `
    -DefaultMajor 0 -DefaultMinor 1 -DefaultPatch 0 -DefaultBuild 1 `
    -CompanyName ($CompanyName ? $CompanyName : "LabVIEW-Community-CI-CD") `
    -AuthorName $AuthorName `
    -LabVIEWMinorRevision $LabVIEWMinorRevision

Write-Host ("[meta] Package root: {0}" -f $PackageRoot)
Write-Host ("[meta] Version: {0}.{1}.{2}.{3}" -f $meta.Major, $meta.Minor, $meta.Patch, $meta.Build)
Write-Host ("[meta] Commit: {0}" -f $meta.Commit)
Write-Host ("[meta] Company: {0}" -f $meta.Company)
Write-Host ("[meta] Author: {0}" -f $meta.Author)
Write-Host ("[meta] LV minor: {0}" -f $meta.LabVIEWMinorRevision)

$lvlibpScript = Join-Path $PSScriptRoot 'build\run-lvlibp-build.ps1'
$vipmScript = Join-Path $PSScriptRoot 'build\run-vipm-package.ps1'

if ($Simulate) {
    Write-Warning "[simulate] Skipping lvlibp/VIPM builds (simulate requested)."
    exit 0
}

switch ($BuildMode) {
    'vip+lvlibp' {
        if (-not (Test-Path -LiteralPath $lvlibpScript -PathType Leaf)) { throw "lvlibp wrapper not found: $lvlibpScript" }
        & pwsh -NoProfile -File $lvlibpScript `
            -RepositoryPath $PackageRoot `
            -Package_LabVIEW_Version $LabVIEWVersion `
            -SupportedBitness $LvlibpBitness `
            -Major $meta.Major -Minor $meta.Minor -Patch $meta.Patch -Build $meta.Build `
            -Commit $meta.Commit `
            -DevMode (-not $SkipDevMode)
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        if (-not (Test-Path -LiteralPath $vipmScript -PathType Leaf)) {
            Write-Warning "VIPM wrapper not found; skipping VIP build."
            exit 0
        }
        & pwsh -NoProfile -File $vipmScript `
            -RepositoryPath $PackageRoot `
            -Package_LabVIEW_Version $LabVIEWVersion `
            -LabVIEWMinorRevision $LabVIEWMinorRevision `
            -SupportedBitness $LvlibpBitness `
            -Commit $meta.Commit `
            -Major $meta.Major -Minor $meta.Minor -Patch $meta.Patch -Build $meta.Build `
            -CompanyName $meta.Company -AuthorName $meta.Author
        exit $LASTEXITCODE
    }
    'vip-single' {
        if (-not (Test-Path -LiteralPath $vipmScript -PathType Leaf)) { throw "VIPM wrapper not found: $vipmScript" }
        & pwsh -NoProfile -File $vipmScript `
            -RepositoryPath $PackageRoot `
            -Package_LabVIEW_Version $LabVIEWVersion `
            -LabVIEWMinorRevision $LabVIEWMinorRevision `
            -SupportedBitness $LvlibpBitness `
            -Commit $meta.Commit `
            -Major $meta.Major -Minor $meta.Minor -Patch $meta.Patch -Build $meta.Build `
            -CompanyName $meta.Company -AuthorName $meta.Author
        exit $LASTEXITCODE
    }
    default {
        throw "Unknown BuildMode: $BuildMode"
    }
}
