#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$RunnerRoot,
    [string]$WorktreeRoot,
    [ValidateSet('Machine', 'User', 'Process')]
    [string]$Scope = 'Machine',
    [switch]$SetArtifactRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-RunnerRoot {
    param([string]$Override)

    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return $Override
    }

    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_WORKSPACE)) {
        return $env:RUNNER_WORKSPACE
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
        $root = Split-Path -Parent (Split-Path -Parent $env:GITHUB_WORKSPACE)
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            return $root
        }
    }

    throw "Runner root not provided and could not be inferred. Pass -RunnerRoot."
}

function Resolve-NormalizedPath {
    param([string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -gt 3 -and $full.EndsWith('\')) {
        $full = $full.TrimEnd('\')
    }
    return $full
}

$runnerRoot = Resolve-RunnerRoot -Override $RunnerRoot
$runnerRoot = Resolve-NormalizedPath -Path $runnerRoot

$workBase = if ((Split-Path -Leaf $runnerRoot) -ieq '_work') {
    $runnerRoot
} else {
    Join-Path $runnerRoot '_work'
}

$resolvedWorktreeRoot = if (-not [string]::IsNullOrWhiteSpace($WorktreeRoot)) {
    $WorktreeRoot
} else {
    Join-Path $workBase 'lvie\w'
}
$resolvedWorktreeRoot = Resolve-NormalizedPath -Path $resolvedWorktreeRoot

New-Item -Path $resolvedWorktreeRoot -ItemType Directory -Force | Out-Null
[Environment]::SetEnvironmentVariable('LVIE_WORKTREE_ROOT', $resolvedWorktreeRoot, $Scope)

$artifactRoot = $null
if ($SetArtifactRoot.IsPresent) {
    $artifactRoot = Join-Path $workBase 'lvie\artifacts'
    $artifactRoot = Resolve-NormalizedPath -Path $artifactRoot
    New-Item -Path $artifactRoot -ItemType Directory -Force | Out-Null
    [Environment]::SetEnvironmentVariable('LVIE_ARTIFACT_ROOT', $artifactRoot, $Scope)
}

Write-Host ("LVIE_WORKTREE_ROOT set to {0} ({1} scope)" -f $resolvedWorktreeRoot, $Scope)
if ($artifactRoot) {
    Write-Host ("LVIE_ARTIFACT_ROOT set to {0} ({1} scope)" -f $artifactRoot, $Scope)
}

Write-Host "Restart the runner service after updating Machine/User environment variables."

