[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$IconEditorRoot,
    [int]$MinimumSupportedLVVersion = 2025,
    [int]$PackageMinimumSupportedLVVersion = 2026,
    [int]$PackageSupportedBitness = 64,
    [int]$Major = 1,
    [int]$Minor = 4,
    [int]$Patch = 1,
    [int]$Build,
    [string]$Commit = 'local-smoke',
    [switch]$Execute
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
$iconEditorResolved = Resolve-IconEditorRoot -RepoRoot $repoRoot -Preferred $IconEditorRoot
$buildHelper = Join-Path $repoRoot 'src/tools/icon-editor/Invoke-IconEditorBuild.ps1'
if (-not (Test-Path -LiteralPath $buildHelper -PathType Leaf)) {
    throw "Invoke-IconEditorBuild.ps1 not found at '$buildHelper'."
}

$pwshArgs = @(
    '-NoLogo','-NoProfile',
    '-File',$buildHelper,
    '-IconEditorRoot',$iconEditorResolved,
    '-MinimumSupportedLVVersion',$MinimumSupportedLVVersion,
    '-PackageMinimumSupportedLVVersion',$PackageMinimumSupportedLVVersion,
    '-PackageSupportedBitness',$PackageSupportedBitness,
    '-Major',$Major,
    '-Minor',$Minor,
    '-Patch',$Patch,
    '-Commit',$Commit,
    '-InstallDependencies:$false'
)
if ($Build) { $pwshArgs += @('-Build',$Build) }

if (-not $Execute) {
    $pwshArgs += @('-SkipPackaging','-SkipMissingInProject','-RunUnitTests:$false')
}

Write-Host "[ppl-build-smoke] RepoRoot        : $repoRoot"
Write-Host "[ppl-build-smoke] IconEditorRoot  : $iconEditorResolved"
Write-Host "[ppl-build-smoke] Minimum LV ver. : $MinimumSupportedLVVersion"
Write-Host "[ppl-build-smoke] Package target  : $PackageMinimumSupportedLVVersion ($PackageSupportedBitness-bit)"
Write-Host ("[ppl-build-smoke] Mode            : {0}" -f ($(if ($Execute) { 'execute (full Invoke-IconEditorBuild run)' } else { 'prepare-only (skip packaging/tests)' })))

& pwsh @pwshArgs
if ($LASTEXITCODE -ne 0) {
    throw "PPL build smoke failed with exit code $LASTEXITCODE."
}

Write-Host "[ppl-build-smoke] Completed successfully."
