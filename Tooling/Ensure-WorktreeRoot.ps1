#Requires -Version 7.0
<#
.SYNOPSIS
    Resolves and validates the worktree root used for local CI parity.

.DESCRIPTION
    Uses LVIE_WORKTREE_ROOT when set, otherwise defaults to C:\dev (if it exists),
    and falls back to a runner-scoped path under RUNNER_WORKSPACE (if available).
    Fails fast if the resolved directory does not exist.

.PARAMETER WorktreeRoot
    Optional override for the worktree root.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot
)

$ErrorActionPreference = 'Stop'

$root = $WorktreeRoot
if ([string]::IsNullOrWhiteSpace($root)) {
    $root = $env:LVIE_WORKTREE_ROOT
}
if ([string]::IsNullOrWhiteSpace($root)) {
    if (Test-Path -Path 'C:\dev') {
        $root = 'C:\dev'
    } elseif (Test-Path -Path 'C:\w') {
        $root = 'C:\w'
    } else {
        $runnerRoot = $env:RUNNER_WORKSPACE
        if ([string]::IsNullOrWhiteSpace($runnerRoot) -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
            $runnerRoot = Split-Path -Path $env:GITHUB_WORKSPACE -Parent
        }
        if (-not [string]::IsNullOrWhiteSpace($runnerRoot)) {
            $root = Join-Path $runnerRoot 'lvie-worktrees'
        }
    }
}

if ([string]::IsNullOrWhiteSpace($root)) {
    throw "Worktree root could not be resolved. Create C:\\dev or set LVIE_WORKTREE_ROOT."
}

$fullRoot = [System.IO.Path]::GetFullPath($root)
if (-not (Test-Path -Path $fullRoot)) {
    throw "Worktree root '$fullRoot' does not exist. Create it or set LVIE_WORKTREE_ROOT."
}

if (-not (Test-Path -Path $fullRoot -PathType Container)) {
    throw "Worktree root '$fullRoot' is not a directory."
}

Write-Output $fullRoot
