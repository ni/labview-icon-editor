[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int]$MinimumSupportedLVVersion = 2023,
    [int]$PackageMinimumSupportedLVVersion = 2026,
    [int]$PackageSupportedBitness = 64,
    [int]$Major = 1,
    [int]$Minor = 4,
    [int]$Patch = 1,
    [int]$Build,
    [switch]$Execute,
    [switch]$VerboseOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Resolve-RepoRoot {
    param([string]$Candidate)
    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        $Candidate = (Join-Path $PSScriptRoot '..' '..')
    }
    return (Resolve-Path -LiteralPath $Candidate -ErrorAction Stop).ProviderPath
}

function Resolve-IconEditorRoot {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$Preferred
    )
    if ($Preferred -and (Test-Path -LiteralPath $Preferred -PathType Container)) {
        return (Resolve-Path -LiteralPath $Preferred -ErrorAction Stop).ProviderPath
    }
    $candidates = @(
        Join-Path $RepoRoot 'vendor/icon-editor',
        Join-Path $RepoRoot 'vendor/labview-icon-editor'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
        }
    }
    if ($Preferred) {
        throw "Icon editor root not found at '$Preferred'. Run tools/icon-editor/Sync-IconEditorFork.ps1."
    }
    throw "Icon editor snapshot not found under 'vendor/'. Run tools/icon-editor/Sync-IconEditorFork.ps1 first."
}

$repoRoot = Resolve-RepoRoot -Candidate $RepoRoot
$iconEditorRoot = Resolve-IconEditorRoot -RepoRoot $repoRoot -Preferred $IconEditorRoot
$buildScript = Join-Path $repoRoot 'src/tools/icon-editor/Invoke-VipmCliBuild.ps1'
if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
    throw "Invoke-VipmCliBuild.ps1 not found at '$buildScript'."
}

$pwshArgs = @(
    '-NoLogo','-NoProfile',
    '-File',$buildScript,
    '-RepoRoot',$repoRoot,
    '-IconEditorRoot',$iconEditorRoot,
    '-MinimumSupportedLVVersion',$MinimumSupportedLVVersion,
    '-PackageMinimumSupportedLVVersion',$PackageMinimumSupportedLVVersion,
    '-PackageSupportedBitness',$PackageSupportedBitness,
    '-Major',$Major,
    '-Minor',$Minor,
    '-Patch',$Patch
)
if ($Build) {
    $pwshArgs += @('-Build',$Build)
}
if ($VerboseOutput) {
    $pwshArgs += '-VerboseOutput'
}

if (-not $Execute) {
    $pwshArgs += @('-SkipSync','-SkipVipcApply','-SkipBuild','-SkipRogueCheck','-SkipClose')
}

Write-Host "[vipmcli-build-smoke] RepoRoot    : $repoRoot"
Write-Host "[vipmcli-build-smoke] IconEditor  : $iconEditorRoot"
Write-Host "[vipmcli-build-smoke] Min LV      : $MinimumSupportedLVVersion"
Write-Host "[vipmcli-build-smoke] Package Min : $PackageMinimumSupportedLVVersion ($PackageSupportedBitness-bit)"
Write-Host ("[vipmcli-build-smoke] Mode        : {0}" -f ($(if ($Execute) { 'execute (runs build sequence)' } else { 'prepare-only (skip heavy steps)' })))

& pwsh @pwshArgs
if ($LASTEXITCODE -ne 0) {
    throw "vipmcli build smoke failed with exit code $LASTEXITCODE."
}

Write-Host "[vipmcli-build-smoke] Completed successfully."
