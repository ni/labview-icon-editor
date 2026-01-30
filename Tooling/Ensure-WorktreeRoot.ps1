#Requires -Version 7.0
<#
.SYNOPSIS
    Resolves and validates the worktree root used for local CI parity.

.DESCRIPTION
    Uses LVIE_WORKTREE_ROOT when set, otherwise defaults to C:\dev.
    Fails fast if the directory does not exist.

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
    $root = 'C:\dev'
}

$fullRoot = [System.IO.Path]::GetFullPath($root)
if (-not (Test-Path -Path $fullRoot)) {
    throw "Worktree root '$fullRoot' does not exist. Create it or set LVIE_WORKTREE_ROOT."
}

if (-not (Test-Path -Path $fullRoot -PathType Container)) {
    throw "Worktree root '$fullRoot' is not a directory."
}

Write-Output $fullRoot
