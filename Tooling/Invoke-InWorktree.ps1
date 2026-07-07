#Requires -Version 7.0
<#[
.SYNOPSIS
    Runs a command or script from a short-path worktree.

.DESCRIPTION
    Creates a worktree under the configured worktree root and invokes the
    provided command or script from that path. This helps keep build/test
    artifacts isolated from the main repo path.
#>

[CmdletBinding(DefaultParameterSetName = 'Command')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Command')]
    [string]$Command,

    [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
    [string]$ScriptPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'Script', ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArguments,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [string]$WorktreeName,

    [Parameter(Mandatory = $false)]
    [string]$Ref = 'HEAD'
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

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$ensureScript = Join-Path $repoRoot 'Tooling\Ensure-WorktreeRoot.ps1'
if (-not (Test-Path -Path $ensureScript)) {
    throw "Ensure-WorktreeRoot.ps1 not found at $ensureScript"
}

$newWorktreeScript = Join-Path $repoRoot 'Tooling\New-CIWorktree.ps1'
if (-not (Test-Path -Path $newWorktreeScript)) {
    throw "New-CIWorktree.ps1 not found at $newWorktreeScript"
}

$resolvedWorktreeRoot = & $ensureScript -WorktreeRoot $WorktreeRoot
$env:LVIE_WORKTREE_ROOT = $resolvedWorktreeRoot

function Test-TruthyEnv {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $normalized = $Value.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

$envName = $env:LVIE_WORKTREE_NAME
$envPrefix = $env:LVIE_WORKTREE_NAME_PREFIX
$noRepoPrefix = Test-TruthyEnv -Value $env:LVIE_WORKTREE_NO_REPO_PREFIX

if ([string]::IsNullOrWhiteSpace($WorktreeName)) {
    if (-not [string]::IsNullOrWhiteSpace($envName)) {
        $suffix = $envName
    } else {
        $prefix = if ([string]::IsNullOrWhiteSpace($envPrefix)) { 'ci-guard' } else { $envPrefix.Trim() }
        $suffix = "{0}-{1}" -f $prefix, (Get-Date -Format 'yyyyMMdd-HHmmss')
    }
} else {
    $suffix = $WorktreeName
}

$worktreeArgs = @(
    '-Ref', $Ref,
    '-Name', $suffix,
    '-WorktreeRoot', $resolvedWorktreeRoot
)
if ($noRepoPrefix) {
    $worktreeArgs += '-NoRepoNamePrefix'
}
$worktreePath = & $newWorktreeScript @worktreeArgs
Write-Host ("Using worktree: {0}" -f $worktreePath)

Push-Location -Path $worktreePath
try {
    if ($PSCmdlet.ParameterSetName -eq 'Script') {
        $scriptFull = if ([System.IO.Path]::IsPathRooted($ScriptPath)) {
            $ScriptPath
        } else {
            Join-Path $worktreePath $ScriptPath
        }

        if (-not (Test-Path -Path $scriptFull)) {
            throw "Script not found at $scriptFull"
        }

        & pwsh -NoProfile -File $scriptFull @ScriptArguments
    } else {
        & pwsh -NoProfile -Command $Command
    }

    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Command failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
