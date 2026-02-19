#Requires -Version 7.0
<#
.SYNOPSIS
    Resolves the CI worktree root path used by lvie-job-setup.

.DESCRIPTION
    Precedence:
      1) Explicit worktree root override
      2) RUNNER_TEMP\lvie\w (when Mode=runner_temp and RUNNER_TEMP is available)
      3) Contract worktree root from runner bootstrap (LVIE_WORKTREE_ROOT)
#>

[CmdletBinding()]
param(
    [ValidateSet('contract', 'runner_temp')]
    [string]$Mode = 'contract',
    [string]$ExplicitWorktreeRoot,
    [string]$RunnerTemp,
    [string]$ContractWorktreeRoot
)

$ErrorActionPreference = 'Stop'

function ConvertTo-NormalizedFullPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Path must not be empty."
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.Length -gt 3 -and $fullPath.EndsWith('\')) {
        $fullPath = $fullPath.TrimEnd('\')
    }

    return $fullPath
}

function Resolve-CIWorktreeRoot {
    [CmdletBinding()]
    param(
        [ValidateSet('contract', 'runner_temp')]
        [string]$Mode = 'contract',
        [string]$ExplicitWorktreeRoot,
        [string]$RunnerTemp,
        [string]$ContractWorktreeRoot
    )

    $resolvedSource = $null
    $resolvedPath = $null

    if (-not [string]::IsNullOrWhiteSpace($ExplicitWorktreeRoot)) {
        $resolvedPath = $ExplicitWorktreeRoot
        $resolvedSource = 'explicit'
    } elseif ($Mode -eq 'runner_temp' -and -not [string]::IsNullOrWhiteSpace($RunnerTemp)) {
        $resolvedPath = Join-Path $RunnerTemp 'lvie\w'
        $resolvedSource = 'runner_temp'
    } else {
        $resolvedPath = $ContractWorktreeRoot
        $resolvedSource = 'contract'
    }

    if ([string]::IsNullOrWhiteSpace($resolvedPath)) {
        throw "Unable to resolve worktree root. Provide -ExplicitWorktreeRoot, set -RunnerTemp (runner_temp mode), or set -ContractWorktreeRoot."
    }

    [pscustomobject]@{
        Path   = ConvertTo-NormalizedFullPath -Path $resolvedPath
        Source = $resolvedSource
    }
}

$isDotSourced = $MyInvocation.InvocationName -eq '.'
if (-not $isDotSourced) {
    Resolve-CIWorktreeRoot @PSBoundParameters
}
