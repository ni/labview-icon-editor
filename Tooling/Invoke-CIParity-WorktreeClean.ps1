#Requires -Version 7.0
<#
.SYNOPSIS
    Creates a new worktree and runs CI parity, but fails if the repo is dirty.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('both', '32', '64', 'installed')]
    [string]$LabVIEWBitness = 'installed',

    [switch]$EnsureCleanState,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeName,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$PathOverride)

    if ($PathOverride) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
}

function Assert-RepoClean {
    param([string]$RepoRoot)

    $lines = & git -C $RepoRoot status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed with exit code $LASTEXITCODE."
    }

    if ($lines -and $lines.Count -gt 0) {
        Write-Host "Working tree is dirty:"
        & git -C $RepoRoot status -sb
        Write-Host "Diff summary (top 20 files):"
        & git -C $RepoRoot diff --stat --stat-count=20
        $sample = $lines | Select-Object -First 5
        $preview = ($sample -join '; ')
        throw "Working tree is dirty. Commit or stash changes before running. Example changes: $preview"
    }
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
Assert-RepoClean -RepoRoot $repoRoot

$newWorktreeScript = Join-Path $repoRoot 'Tooling/New-CIWorktree.ps1'
if (-not (Test-Path -Path $newWorktreeScript)) {
    throw "New-CIWorktree.ps1 not found at $newWorktreeScript"
}

$suffix = if ([string]::IsNullOrWhiteSpace($WorktreeName)) { "ci-parity-clean-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss') } else { $WorktreeName }
$worktreePath = & $newWorktreeScript -Ref HEAD -Name $suffix -WorktreeRoot $WorktreeRoot
Write-Host ("Using worktree: {0}" -f $worktreePath)

$invokeScript = Join-Path $repoRoot 'Tooling/Invoke-CIParity-FromVersionFile.ps1'
if (-not (Test-Path -Path $invokeScript)) {
    throw "Invoke-CIParity-FromVersionFile.ps1 not found at $invokeScript"
}

& $invokeScript `
    -RepoRoot $worktreePath `
    -WorktreeRoot $WorktreeRoot `
    -LabVIEWBitness $LabVIEWBitness `
    -EnsureCleanState:$EnsureCleanState
