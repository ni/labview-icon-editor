<#
.SYNOPSIS
    Run the lvlibp (Editor Packed Library) build with optional dev-mode binding.

.DESCRIPTION
    Wraps scripts/build-lvlibp/Build_lvlibp.ps1, ensuring dev-mode binding/unbinding if desired,
    and supports environments without git metadata by accepting explicit version numbers.

.PARAMETER RepositoryPath
    Path to the repo or extracted source tree containing lv_icon_editor.lvproj and scripts/.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version to use (e.g., 2021).

.PARAMETER SupportedBitness
    Bitness to build (32 or 64).

.PARAMETER Major/Minor/Patch/Build
    Version numbers to stamp into the PPL (used when git metadata is absent).

.PARAMETER Commit
    Commit hash or identifier to embed (default 'manual').

.PARAMETER DevMode
    Bind dev-mode before build (default: true). Set -DevMode:$false to skip.
#>
param(
    [Parameter(Mandatory)][string]$RepositoryPath,
    [string]$Package_LabVIEW_Version = "2021",
    [ValidateSet('32','64')][string]$SupportedBitness = "64",
    [int]$Major = 0,
    [int]$Minor = 1,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$Commit = "manual",
    [bool]$DevMode = $true,
    [bool]$DevModeUnbind = $false
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
$bindScript = Join-Path $repo 'scripts\task-devmode-bind.ps1'
$buildScript = Join-Path $repo 'scripts\build-lvlibp\Build_lvlibp.ps1'

if ($DevMode -and -not (Test-Path -LiteralPath $bindScript -PathType Leaf)) {
    throw "Dev-mode bind script not found at $bindScript"
}
if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
    throw "Build_lvlibp.ps1 not found at $buildScript"
}

if ($DevMode) {
    Write-Host ("[lvlibp] Binding dev mode ({0}-bit) to {1}" -f $SupportedBitness, $repo)
    & pwsh -NoProfile -File $bindScript -RepositoryPath $repo -Mode bind -Bitness $SupportedBitness -UseWorktree:$false | Write-Output
}

Write-Host ("[lvlibp] Running PPL build ({0}-bit) LV {1} Version {2}.{3}.{4}.{5} Commit {6}" -f $SupportedBitness, $Package_LabVIEW_Version, $Major, $Minor, $Patch, $Build, $Commit)
& pwsh -NoProfile -File $buildScript `
    -RepositoryPath $repo `
    -Package_LabVIEW_Version $Package_LabVIEW_Version `
    -SupportedBitness $SupportedBitness `
    -Major $Major -Minor $Minor -Patch $Patch -Build $Build `
    -Commit $Commit | Write-Output

if ($DevMode -and $DevModeUnbind) {
    try {
        Write-Host ("[lvlibp] Unbinding dev mode ({0}-bit) from {1}" -f $SupportedBitness, $repo)
        & pwsh -NoProfile -File $bindScript -RepositoryPath $repo -Mode unbind -Bitness $SupportedBitness -UseWorktree:$false | Write-Output
    }
    catch {
        Write-Warning ("[lvlibp] Failed to unbind dev mode: {0}" -f $_.Exception.Message)
    }
}
