#Requires -Version 7.0
<#
.SYNOPSIS
    Initializes the LVIE runner contract and exports LVIE_* environment variables for the current job.

.DESCRIPTION
    Designed for stateless self-hosted runners. This script writes (or refreshes) the
    runner contract under the runner work root and exports the resolved LVIE_* paths
    to the current process and (optionally) the GitHub Actions job environment.

.PARAMETER RunnerRoot
    Root folder where the runner is installed (e.g. C:\actions-runner).

.PARAMETER WorkRoot
    Runner work root (e.g. C:\actions-runner\_work).

.PARAMETER WorktreeRoot
    Worktree root override (defaults to <workroot>\lvie\w).

.PARAMETER ArtifactRoot
    Artifact root override (defaults to <workroot>\lvie\artifacts).

.PARAMETER LockRoot
    Lock root override (defaults to <workroot>\lvie\locks).

.PARAMETER LogRoot
    Log root override (defaults to <workroot>\lvie\logs).

.PARAMETER RunnerLabel
    Primary runner label to record in the contract.

.PARAMETER RunnerLabels
    Additional runner labels to record in the contract.

.PARAMETER CanonicalRunnerLabel
    Canonical runner label that must always be present (defaults to self-hosted-windows-lv).

.PARAMETER ContractPath
    Optional runner contract path override.

.PARAMETER WriteGitHubEnv
    Write resolved LVIE_* variables to the GitHub Actions job environment.
#>

[CmdletBinding()]
param(
    [string]$RunnerRoot,
    [string]$WorkRoot,
    [string]$WorktreeRoot,
    [string]$ArtifactRoot,
    [string]$LockRoot,
    [string]$LogRoot,
    [string]$RunnerLabel,
    [string[]]$RunnerLabels,
    [string]$CanonicalRunnerLabel,
    [string]$ContractPath,
    [switch]$WriteGitHubEnv
)

$ErrorActionPreference = 'Stop'

$contractHelper = Join-Path $PSScriptRoot 'support\RunnerContract.ps1'
if (-not (Test-Path -Path $contractHelper)) {
    throw "RunnerContract.ps1 not found at $contractHelper"
}
. $contractHelper

function Resolve-NormalizedPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -gt 3 -and $full.EndsWith('\')) {
        $full = $full.TrimEnd('\')
    }
    return $full
}

function Resolve-RunnerRoot {
    param(
        [string]$RunnerRoot,
        [string]$WorkRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($RunnerRoot)) {
        return (Resolve-NormalizedPath -Path $RunnerRoot)
    }

    if (-not [string]::IsNullOrWhiteSpace($WorkRoot)) {
        $workRootResolved = Resolve-NormalizedPath -Path $WorkRoot
        if ((Split-Path -Leaf $workRootResolved) -ieq '_work') {
            return (Split-Path -Parent $workRootResolved)
        }
        return (Split-Path -Parent $workRootResolved)
    }

    return $null
}

function Resolve-LabelsFromEnv {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return $Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

function Write-EnvLine {
    param(
        [string]$Name,
        [string]$Value,
        [string]$EnvPath
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    "$Name=$Value" | Out-File -FilePath $EnvPath -Append -Encoding ascii
}

$workRootResolved = Resolve-RunnerWorkRoot -RunnerRoot $RunnerRoot -WorkRoot $WorkRoot
if ([string]::IsNullOrWhiteSpace($workRootResolved)) {
    throw "Runner work root could not be resolved. Provide -RunnerRoot or -WorkRoot."
}
$workRootResolved = Resolve-NormalizedPath -Path $workRootResolved

$runnerRootResolved = Resolve-RunnerRoot -RunnerRoot $RunnerRoot -WorkRoot $workRootResolved
if (-not [string]::IsNullOrWhiteSpace($runnerRootResolved)) {
    $runnerRootResolved = Resolve-NormalizedPath -Path $runnerRootResolved
}

$worktreeRootResolved = if (-not [string]::IsNullOrWhiteSpace($WorktreeRoot)) {
    Resolve-NormalizedPath -Path $WorktreeRoot
} else {
    Resolve-NormalizedPath -Path (Join-Path $workRootResolved 'lvie\w')
}
$artifactRootResolved = if (-not [string]::IsNullOrWhiteSpace($ArtifactRoot)) {
    Resolve-NormalizedPath -Path $ArtifactRoot
} else {
    Resolve-NormalizedPath -Path (Join-Path $workRootResolved 'lvie\artifacts')
}
$lockRootResolved = if (-not [string]::IsNullOrWhiteSpace($LockRoot)) {
    Resolve-NormalizedPath -Path $LockRoot
} else {
    Resolve-NormalizedPath -Path (Join-Path $workRootResolved 'lvie\locks')
}
$logRootResolved = if (-not [string]::IsNullOrWhiteSpace($LogRoot)) {
    Resolve-NormalizedPath -Path $LogRoot
} else {
    Resolve-NormalizedPath -Path (Join-Path $workRootResolved 'lvie\logs')
}

New-Item -Path $worktreeRootResolved -ItemType Directory -Force | Out-Null
New-Item -Path $artifactRootResolved -ItemType Directory -Force | Out-Null
New-Item -Path $lockRootResolved -ItemType Directory -Force | Out-Null
New-Item -Path $logRootResolved -ItemType Directory -Force | Out-Null

$canonicalRunnerLabel = if (-not [string]::IsNullOrWhiteSpace($CanonicalRunnerLabel)) {
    $CanonicalRunnerLabel.Trim()
} elseif (-not [string]::IsNullOrWhiteSpace($env:LVIE_CANONICAL_RUNNER_LABEL)) {
    $env:LVIE_CANONICAL_RUNNER_LABEL.Trim()
} else {
    'self-hosted-windows-lv'
}

$primaryRunnerLabel = if (-not [string]::IsNullOrWhiteSpace($RunnerLabel)) {
    $RunnerLabel.Trim()
} elseif (-not [string]::IsNullOrWhiteSpace($env:LVIE_EXPECTED_RUNNER_LABEL)) {
    $env:LVIE_EXPECTED_RUNNER_LABEL.Trim()
} elseif (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_LABEL)) {
    $env:LVIE_RUNNER_LABEL.Trim()
} else {
    $canonicalRunnerLabel
}

$runnerLabelsResolved = @()
if ($RunnerLabels) {
    $runnerLabelsResolved += $RunnerLabels
}
$runnerLabelsResolved += Resolve-LabelsFromEnv -Value $env:LVIE_RUNNER_LABELS
if (-not [string]::IsNullOrWhiteSpace($primaryRunnerLabel)) {
    $runnerLabelsResolved += $primaryRunnerLabel
}
if (-not [string]::IsNullOrWhiteSpace($canonicalRunnerLabel)) {
    $runnerLabelsResolved += $canonicalRunnerLabel
}
$runnerLabelsResolved = $runnerLabelsResolved | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique

if ([string]::IsNullOrWhiteSpace($ContractPath)) {
    $ContractPath = Join-Path $workRootResolved 'lvie\runner-contract.json'
}
$contractPathResolved = Resolve-RunnerContractPath -ContractPath $ContractPath -RunnerRoot $runnerRootResolved -WorkRoot $workRootResolved
if ([string]::IsNullOrWhiteSpace($contractPathResolved)) {
    throw "Runner contract path could not be resolved. Provide -ContractPath or ensure a work root is available."
}

$timestamp = (Get-Date).ToUniversalTime().ToString('o')
$contract = [pscustomobject]@{
    version        = 1
    runner_root    = $runnerRootResolved
    work_root      = $workRootResolved
    worktree_root  = $worktreeRootResolved
    artifact_root  = $artifactRootResolved
    lock_root      = $lockRootResolved
    log_root       = $logRootResolved
    runner_label   = $primaryRunnerLabel
    runner_labels  = $runnerLabelsResolved
    canonical_runner_label = $canonicalRunnerLabel
    updated_at_utc = $timestamp
}

$existing = Get-RunnerContract -ContractPath $contractPathResolved -RunnerRoot $runnerRootResolved -WorkRoot $workRootResolved
if ($existing -and $existing.created_at_utc) {
    $contract | Add-Member -MemberType NoteProperty -Name created_at_utc -Value $existing.created_at_utc
} else {
    $contract | Add-Member -MemberType NoteProperty -Name created_at_utc -Value $timestamp
}

Set-RunnerContract -ContractPath $contractPathResolved -Contract $contract

$env:LVIE_RUNNER_ROOT = $runnerRootResolved
$env:LVIE_RUNNER_WORK_ROOT = $workRootResolved
$env:LVIE_WORKTREE_ROOT = $worktreeRootResolved
$env:LVIE_ARTIFACT_ROOT = $artifactRootResolved
$env:LVIE_LOCK_ROOT = $lockRootResolved
$env:LVIE_LOG_ROOT = $logRootResolved
$env:LVIE_RUNNER_CONTRACT_PATH = $contractPathResolved
$env:LVIE_RUNNER_LABEL = $primaryRunnerLabel
$env:LVIE_RUNNER_LABELS = ($runnerLabelsResolved -join ',')
$env:LVIE_CANONICAL_RUNNER_LABEL = $canonicalRunnerLabel

$writeGitHubEnv = $WriteGitHubEnv.IsPresent
if (-not $PSBoundParameters.ContainsKey('WriteGitHubEnv')) {
    $writeGitHubEnv = ($env:GITHUB_ACTIONS -eq 'true')
}

if ($writeGitHubEnv) {
    if ([string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
        Write-Warning 'GITHUB_ENV was not set; skipping job environment export.'
    } else {
        Write-EnvLine -Name 'LVIE_RUNNER_ROOT' -Value $env:LVIE_RUNNER_ROOT -EnvPath $env:GITHUB_ENV
        Write-EnvLine -Name 'LVIE_RUNNER_WORK_ROOT' -Value $env:LVIE_RUNNER_WORK_ROOT -EnvPath $env:GITHUB_ENV
        Write-EnvLine -Name 'LVIE_WORKTREE_ROOT' -Value $env:LVIE_WORKTREE_ROOT -EnvPath $env:GITHUB_ENV
        Write-EnvLine -Name 'LVIE_ARTIFACT_ROOT' -Value $env:LVIE_ARTIFACT_ROOT -EnvPath $env:GITHUB_ENV
        Write-EnvLine -Name 'LVIE_LOCK_ROOT' -Value $env:LVIE_LOCK_ROOT -EnvPath $env:GITHUB_ENV
        Write-EnvLine -Name 'LVIE_LOG_ROOT' -Value $env:LVIE_LOG_ROOT -EnvPath $env:GITHUB_ENV
        Write-EnvLine -Name 'LVIE_RUNNER_CONTRACT_PATH' -Value $env:LVIE_RUNNER_CONTRACT_PATH -EnvPath $env:GITHUB_ENV
        Write-EnvLine -Name 'LVIE_RUNNER_LABEL' -Value $env:LVIE_RUNNER_LABEL -EnvPath $env:GITHUB_ENV
        Write-EnvLine -Name 'LVIE_RUNNER_LABELS' -Value $env:LVIE_RUNNER_LABELS -EnvPath $env:GITHUB_ENV
        Write-EnvLine -Name 'LVIE_CANONICAL_RUNNER_LABEL' -Value $env:LVIE_CANONICAL_RUNNER_LABEL -EnvPath $env:GITHUB_ENV
    }
}

Write-Host ("Runner contract written: {0}" -f $contractPathResolved)
Write-Host ("LVIE_WORKTREE_ROOT: {0}" -f $worktreeRootResolved)
Write-Host ("LVIE_ARTIFACT_ROOT: {0}" -f $artifactRootResolved)
Write-Host ("LVIE_LOCK_ROOT: {0}" -f $lockRootResolved)
Write-Host ("LVIE_LOG_ROOT: {0}" -f $logRootResolved)

return [pscustomobject]@{
    RunnerRoot   = $runnerRootResolved
    WorkRoot     = $workRootResolved
    WorktreeRoot = $worktreeRootResolved
    ArtifactRoot = $artifactRootResolved
    LockRoot     = $lockRootResolved
    LogRoot      = $logRootResolved
    ContractPath = $contractPathResolved
    RunnerLabel  = $primaryRunnerLabel
}
