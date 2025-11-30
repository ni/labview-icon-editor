<#
.SYNOPSIS
    Run VIPM packaging (wrapper for VIP build steps).

.DESCRIPTION
    Placeholder wrapper for VIPM packaging; invoke existing VIP build logic here.
    For now, emits a warning indicating this path is not yet wired.

.PARAMETER RepositoryPath
    Path to the repo or extracted source tree.

.PARAMETER Major/Minor/Patch/Build
    Version numbers for packaging.

.PARAMETER CompanyName/AuthorName
    Metadata fields for packaging.
#>
param(
    [Parameter(Mandatory)][string]$RepositoryPath,
    [int]$Major = 0,
    [int]$Minor = 1,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$CompanyName = "LabVIEW-Community-CI-CD",
    [string]$AuthorName = "Local Developer",
    [string]$Package_LabVIEW_Version,
    [string]$LabVIEWMinorRevision = "3",
    [ValidateSet('32','64','both')][string]$SupportedBitness = "64",
    [string]$VIPBPath = "Tooling/deployment/seed.vipb",
    [string]$ReleaseNotesFile = "Tooling/deployment/release_notes.md",
    [string]$Commit = "manual",
    [string]$DisplayInformationJSON,
    [switch]$Simulate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$vipScript = Join-Path $repo 'scripts\build-vip\build_vip.ps1'
if (-not (Test-Path -LiteralPath $vipScript -PathType Leaf)) {
    throw "VIP build script not found at $vipScript"
}

# Prereqs
if (-not (Get-Command vipm -ErrorAction SilentlyContinue)) {
    throw "vipm CLI not found on PATH; cannot run VIP build."
}
if (-not (Test-Path -LiteralPath $VIPBPath)) {
    $candidate = Join-Path $repo $VIPBPath
    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "VIPB not found at $VIPBPath or $candidate"
    }
    $VIPBPath = $candidate
}

# Resolve Package_LabVIEW_Version from VIPB if not provided
if (-not $Package_LabVIEW_Version) {
    $getLv = Join-Path $repo 'scripts\get-package-lv-version.ps1'
    if (Test-Path -LiteralPath $getLv) {
        try { $Package_LabVIEW_Version = & $getLv -RepositoryPath $repo } catch { $Package_LabVIEW_Version = "2021" }
    }
    if (-not $Package_LabVIEW_Version) { $Package_LabVIEW_Version = "2021" }
}

# Minimal display info JSON if none provided
if (-not $DisplayInformationJSON) {
    $DisplayInformationJSON = @{
        "Package Version" = @{
            major = $Major
            minor = $Minor
            patch = $Patch
            build = $Build
        }
    } | ConvertTo-Json -Compress
}

Write-Host ("[vipm] Running VIP build ({0}) LV {1}.{2} version {3}.{4}.{5}.{6}" -f $SupportedBitness, $Package_LabVIEW_Version, $LabVIEWMinorRevision, $Major, $Minor, $Patch, $Build)
if ($Simulate) {
    Write-Warning "[vipm] Simulate enabled: skipping vipm build."
    exit 0
}

& pwsh -NoProfile -File $vipScript `
    -SupportedBitness $SupportedBitness `
    -RepositoryPath $repo `
    -VIPBPath $VIPBPath `
    -Package_LabVIEW_Version $Package_LabVIEW_Version `
    -LabVIEWMinorRevision $LabVIEWMinorRevision `
    -Major $Major -Minor $Minor -Patch $Patch -Build $Build `
    -Commit $Commit `
    -ReleaseNotesFile $ReleaseNotesFile `
    -DisplayInformationJSON $DisplayInformationJSON
