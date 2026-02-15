#Requires -Version 7.0
<#
.SYNOPSIS
    Runs only the pylavi vi_validate gate.

.DESCRIPTION
    Convenience wrapper around Run-CICompositeLocal.ps1 -ViValidateOnly.
    Uses .lvversion as the canonical LabVIEW version.

.PARAMETER RepoRoot
    Optional repository root override.

.PARAMETER ViValidateConfigPath
    Path to pylavi vi_validate config file (relative to repo root).

.PARAMETER ViValidateProfile
    vi_validate profile: strict, legacy, or both (default: strict).

.PARAMETER ViValidateReportOnly
    Emit vi_validate warnings but do not fail the run.

.PARAMETER ViValidateSkipVersionGate
    Skip passing --eq to vi_validate (useful for legacy cleanup runs).

.PARAMETER WorktreeRoot
    Optional override for the worktree root used by guardrails.

.PARAMETER SkipWorktreeRootCheck
    Skip enforcing that RepoRoot is under the worktree root.

.PARAMETER AutoWorktree
    Auto-create a short-path worktree and re-run from there when needed.

.PARAMETER RunId
    Optional run identifier used for artifact isolation.

.PARAMETER ArtifactRoot
    Optional override for the artifact output root.

.PARAMETER CleanRoom
    If set, purge known output folders before and after the run.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$ViValidateConfigPath = 'Tooling/pylavi/vi-validate.yml',

    [Parameter(Mandatory = $false)]
    [ValidateSet('strict', 'legacy', 'both')]
    [string]$ViValidateProfile = 'strict',

    [switch]$ViValidateReportOnly,

    [switch]$ViValidateSkipVersionGate,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [switch]$SkipWorktreeRootCheck,

    [switch]$AutoWorktree,

    [Parameter(Mandatory = $false)]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactRoot,

    [switch]$CleanRoom
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH."
}
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
$repoRootResolved = if ($RepoRoot) {
    (Resolve-Path -Path $RepoRoot).Path
} else {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                (Resolve-Path -Path $gitRoot.Trim()).Path
            } else {
                (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
            }
        } catch {
            (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
        }
    } else {
        (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
    }
}
$runScript = Join-Path $repoRootResolved 'Tooling/Run-CICompositeLocal.ps1'
if (-not (Test-Path -Path $runScript)) {
    throw "Run-CICompositeLocal.ps1 not found at $runScript"
}

& $runScript `
    -ViValidateOnly `
    -ViValidateConfigPath $ViValidateConfigPath `
    -ViValidateProfile $ViValidateProfile `
    -ViValidateReportOnly:$ViValidateReportOnly `
    -ViValidateSkipVersionGate:$ViValidateSkipVersionGate `
    -RepoRoot $repoRootResolved `
    -WorktreeRoot $WorktreeRoot `
    -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
    -AutoWorktree:$AutoWorktree `
    -RunId $RunId `
    -ArtifactRoot $ArtifactRoot `
    -CleanRoom:$CleanRoom
