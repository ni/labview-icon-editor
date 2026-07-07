#Requires -Version 7.0
<#[
.SYNOPSIS
    Shared guardrails for enforcing short-path worktree usage.

.DESCRIPTION
    Resolves the configured worktree root and validates that RepoRoot
    is under it. Allows explicit opt-out for advanced scenarios.
#>

[CmdletBinding()]
param()

function Test-WorktreeGuardSkip {
    param(
        [switch]$Skip
    )

    if ($Skip) {
        return $true
    }

    $envValue = $env:LVIE_SKIP_WORKTREE_ROOT_CHECK
    if ([string]::IsNullOrWhiteSpace($envValue)) {
        return $false
    }

    $normalized = $envValue.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

function Resolve-WorktreeRoot {
    param(
        [string]$WorktreeRoot
    )

    $ensureScript = Join-Path $PSScriptRoot '..\Ensure-WorktreeRoot.ps1'
    if (-not (Test-Path -Path $ensureScript)) {
        throw "Ensure-WorktreeRoot.ps1 not found at $ensureScript"
    }

    $resolved = & $ensureScript -WorktreeRoot $WorktreeRoot
    if ([string]::IsNullOrWhiteSpace($resolved)) {
        throw 'Worktree root could not be resolved.'
    }

    return $resolved
}

function ConvertTo-NormalizedPath {
    param(
        [string]$Path
    )

    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not $full.EndsWith('\')) {
        $full += '\'
    }

    return $full
}

function Assert-RepoRootUnderWorktreeRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [string]$WorktreeRoot,

        [switch]$Skip,

        [string]$Context
    )

    if (Test-WorktreeGuardSkip -Skip:$Skip) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        throw 'RepoRoot is required to validate worktree root.'
    }

    $resolvedWorktreeRoot = Resolve-WorktreeRoot -WorktreeRoot $WorktreeRoot
    $repoFull = ConvertTo-NormalizedPath -Path $RepoRoot
    $rootFull = ConvertTo-NormalizedPath -Path $resolvedWorktreeRoot

    if (-not $repoFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $contextLabel = if ([string]::IsNullOrWhiteSpace($Context)) { 'script' } else { $Context }
        $message = "RepoRoot '{0}' is not under worktree root '{1}' for {2}." -f $repoFull.TrimEnd('\'), $rootFull.TrimEnd('\'), $contextLabel
        $message += " Use Tooling\\New-CIWorktree.ps1 to create a short-path worktree or set LVIE_WORKTREE_ROOT."
        $message += " To bypass, pass -SkipWorktreeRootCheck or set LVIE_SKIP_WORKTREE_ROOT_CHECK=1."
        throw $message
    }

    return $resolvedWorktreeRoot
}

function Write-WorktreeContext {
    param(
        [string]$RepoRoot,
        [string]$WorktreeRoot,
        [string]$Prefix = 'Worktree'
    )

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        Write-Host ("{0} repo_root={1}" -f $Prefix, $RepoRoot)
    }

    if (-not [string]::IsNullOrWhiteSpace($WorktreeRoot)) {
        Write-Host ("{0} worktree_root={1}" -f $Prefix, $WorktreeRoot)
    }
}
