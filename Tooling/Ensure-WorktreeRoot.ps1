#Requires -Version 7.0
<#
.SYNOPSIS
    Resolves and validates the worktree root used for local CI parity.

.DESCRIPTION
    Resolution order:
      1) WorktreeRoot parameter override
      2) LVIE_WORKTREE_ROOT
      3) repo-derived deterministic root
      4) runner-scoped root under RUNNER_WORKSPACE/GITHUB_WORKSPACE
    Repo-derived roots are created when missing. Explicit roots fail fast when missing.

.PARAMETER WorktreeRoot
    Optional override for the worktree root.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$BasePath)

    $root = if ([string]::IsNullOrWhiteSpace($BasePath)) {
        if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    } else {
        $BasePath
    }

    try {
        $gitRoot = git -C $root rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
        }
    } catch {
        Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
    }

    return (Resolve-Path -Path (Join-Path $root '..') -ErrorAction Stop).Path
}

function Get-RepoDerivedWorktreeRoot {
    param([string]$RepoRoot)

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return $null
    }

    $normalized = [System.IO.Path]::GetFullPath($RepoRoot)
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $marker = "{0}worktrees{0}" -f $separator
    $index = $normalized.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)
    if ($index -ge 0) {
        $prefix = $normalized.Substring(0, $index)
        if ([string]::IsNullOrWhiteSpace($prefix)) {
            return "{0}worktrees" -f $separator
        }
        return Join-Path $prefix 'worktrees'
    }

    return Join-Path $normalized 'worktrees'
}

function Get-RunnerDerivedWorktreeRoot {
    $runnerRoot = $env:RUNNER_WORKSPACE
    if ([string]::IsNullOrWhiteSpace($runnerRoot) -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
        $runnerRoot = Split-Path -Path $env:GITHUB_WORKSPACE -Parent
    }

    if ([string]::IsNullOrWhiteSpace($runnerRoot)) {
        return $null
    }

    return Join-Path $runnerRoot 'lvie-worktrees'
}

$source = ''
$root = $WorktreeRoot
if (-not [string]::IsNullOrWhiteSpace($root)) {
    $source = 'override'
} else {
    $root = $env:LVIE_WORKTREE_ROOT
    if (-not [string]::IsNullOrWhiteSpace($root)) {
        $source = 'env:LVIE_WORKTREE_ROOT'
    }
}

if ([string]::IsNullOrWhiteSpace($root)) {
    $repoRoot = Resolve-RepoRoot -BasePath $PSScriptRoot
    $root = Get-RepoDerivedWorktreeRoot -RepoRoot $repoRoot
    if (-not [string]::IsNullOrWhiteSpace($root)) {
        $source = 'repo-derived'
    } else {
        $root = Get-RunnerDerivedWorktreeRoot
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            $source = 'runner-derived'
        }
    }
}

if ([string]::IsNullOrWhiteSpace($root)) {
    throw "Worktree root could not be resolved. Set LVIE_WORKTREE_ROOT or pass -WorktreeRoot."
}

$fullRoot = [System.IO.Path]::GetFullPath($root)
if (-not (Test-Path -Path $fullRoot)) {
    if ($source -eq 'repo-derived') {
        New-Item -Path $fullRoot -ItemType Directory -Force | Out-Null
    } else {
        throw "Worktree root '$fullRoot' does not exist. Create it or set LVIE_WORKTREE_ROOT."
    }
}

if (-not (Test-Path -Path $fullRoot -PathType Container)) {
    throw "Worktree root '$fullRoot' is not a directory."
}

Write-Output $fullRoot
