[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$VipcPath = '.github/actions/apply-vipc/runner_dependencies.vipc',
    [string]$MinimumSupportedLVVersion = '2025',
    [string]$VipLabVIEWVersion,
    [int]$SupportedBitness = 64,
    [ValidateSet('g-cli')]
    [string]$Toolchain = 'g-cli',
    [switch]$PrepareOnly
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

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$TargetPath
    )
    if ([System.IO.Path]::IsPathRooted($TargetPath)) {
        return [System.IO.Path]::GetFullPath($TargetPath)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $TargetPath))
}

$repoRoot = Resolve-RepoRoot -Candidate $RepoRoot
$workspace = $repoRoot
$vipcFullPath = Resolve-AbsolutePath -BasePath $workspace -TargetPath $VipcPath
if (-not (Test-Path -LiteralPath $vipcFullPath -PathType Leaf)) {
    throw "VIPC file not found at '$vipcFullPath'. Run tools/icon-editor/Sync-IconEditorFork.ps1 or download runner_dependencies.vipc."
}

$replayScript = Join-Path $repoRoot 'src/tools/icon-editor/Replay-ApplyVipcJob.ps1'
if (-not (Test-Path -LiteralPath $replayScript -PathType Leaf)) {
    throw "Replay-ApplyVipcJob.ps1 not found at '$replayScript'."
}

$pwshArgs = @(
    '-NoLogo','-NoProfile',
    '-File', $replayScript,
    '-Workspace', $workspace,
    '-VipcPath', $vipcFullPath,
    '-Toolchain', $Toolchain
)
if ($MinimumSupportedLVVersion) {
    $pwshArgs += @('-MinimumSupportedLVVersion', $MinimumSupportedLVVersion)
}
if ($VipLabVIEWVersion) {
    $pwshArgs += @('-VipLabVIEWVersion', $VipLabVIEWVersion)
}
if ($SupportedBitness) {
    $pwshArgs += @('-SupportedBitness', $SupportedBitness.ToString())
}
if ($PrepareOnly) {
    $pwshArgs += '-SkipExecution'
}

Write-Host "[vipmcli-apply-smoke] RepoRoot        : $repoRoot"
Write-Host "[vipmcli-apply-smoke] VipcPath       : $vipcFullPath"
Write-Host "[vipmcli-apply-smoke] Toolchain      : $Toolchain"
Write-Host "[vipmcli-apply-smoke] Minimum LV ver.: $MinimumSupportedLVVersion"
Write-Host "[vipmcli-apply-smoke] Bitness        : $SupportedBitness-bit"
Write-Host ("[vipmcli-apply-smoke] Mode           : {0}" -f ($(if ($PrepareOnly) { 'prepare-only (SkipExecution)' } else { 'execute' })))

& pwsh @pwshArgs
if ($LASTEXITCODE -ne 0) {
    throw "vipmcli apply smoke failed with exit code $LASTEXITCODE."
}

Write-Host "[vipmcli-apply-smoke] Completed successfully."
