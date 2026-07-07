#Requires -Version 7.0
<#
.SYNOPSIS
    Commit local changes, create a new worktree, and run CI parity from it.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$CommitMessage,

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

function Get-GitStatusLine {
    param([string]$RepoRoot)

    $lines = & git -C $RepoRoot status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed with exit code $LASTEXITCODE."
    }
    return $lines
}

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot

$statusLines = Get-GitStatusLine -RepoRoot $repoRoot
$hasChanges = $statusLines -and $statusLines.Count -gt 0

if ($hasChanges) {
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        throw "Working tree has changes. Provide -CommitMessage to continue."
    }

    Write-Host "Staging changes..."
    & git -C $repoRoot add -A
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed with exit code $LASTEXITCODE."
    }

    Write-Host ("Committing: {0}" -f $CommitMessage)
    & git -C $repoRoot commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) {
        throw "git commit failed with exit code $LASTEXITCODE."
    }
} else {
    Write-Host "No local changes detected; skipping commit."
}

$newWorktreeScript = Join-Path $repoRoot 'Tooling/New-CIWorktree.ps1'
if (-not (Test-Path -Path $newWorktreeScript)) {
    throw "New-CIWorktree.ps1 not found at $newWorktreeScript"
}

$suffix = if ([string]::IsNullOrWhiteSpace($WorktreeName)) { "ci-parity-promote-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss') } else { $WorktreeName }
$worktreePath = & $newWorktreeScript -Ref HEAD -Name $suffix -WorktreeRoot $WorktreeRoot
Write-Host ("Using worktree: {0}" -f $worktreePath)

$invokeScript = Join-Path $repoRoot 'Tooling/Invoke-CIParity-FromVersionFile.ps1'
if (-not (Test-Path -Path $invokeScript)) {
    throw "Invoke-CIParity-FromVersionFile.ps1 not found at $invokeScript"
}

& $invokeScript `
    -RepoRoot $worktreePath `
    -UseWorktree:$false `
    -LabVIEWBitness $LabVIEWBitness `
    -EnsureCleanState:$EnsureCleanState

