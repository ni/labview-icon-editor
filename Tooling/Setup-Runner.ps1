#Requires -Version 7.0

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
    [string]$CanonicalRunnerLabel = 'self-hosted-windows-lv',
    [ValidateSet('Machine', 'User', 'Process')]
    [string]$Scope = 'Machine'
)

$ErrorActionPreference = 'Stop'

$contractHelper = Join-Path $PSScriptRoot 'support\RunnerContract.ps1'
if (-not (Test-Path -Path $contractHelper)) {
    throw "RunnerContract.ps1 not found at $contractHelper"
}
. $contractHelper

function Resolve-RunnerPath {
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

$workRootResolved = Resolve-RunnerWorkRoot -RunnerRoot $RunnerRoot -WorkRoot $WorkRoot
if ([string]::IsNullOrWhiteSpace($workRootResolved)) {
    throw "Runner work root could not be resolved. Provide -RunnerRoot or -WorkRoot."
}
$workRootResolved = Resolve-RunnerPath -Path $workRootResolved

$runnerRootResolved = if (-not [string]::IsNullOrWhiteSpace($RunnerRoot)) {
    Resolve-RunnerPath -Path $RunnerRoot
} else {
    Split-Path -Parent $workRootResolved
}

$worktreeRootResolved = if (-not [string]::IsNullOrWhiteSpace($WorktreeRoot)) {
    $WorktreeRoot
} else {
    Join-Path $workRootResolved 'lvie\w'
}
$artifactRootResolved = if (-not [string]::IsNullOrWhiteSpace($ArtifactRoot)) {
    $ArtifactRoot
} else {
    Join-Path $workRootResolved 'lvie\artifacts'
}
$lockRootResolved = if (-not [string]::IsNullOrWhiteSpace($LockRoot)) {
    $LockRoot
} else {
    Join-Path $workRootResolved 'lvie\locks'
}
$logRootResolved = if (-not [string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot
} else {
    Join-Path $workRootResolved 'lvie\logs'
}

$worktreeRootResolved = Resolve-RunnerPath -Path $worktreeRootResolved
$artifactRootResolved = Resolve-RunnerPath -Path $artifactRootResolved
$lockRootResolved = Resolve-RunnerPath -Path $lockRootResolved
$logRootResolved = Resolve-RunnerPath -Path $logRootResolved

$canonicalRunnerLabel = if ([string]::IsNullOrWhiteSpace($CanonicalRunnerLabel)) {
    'self-hosted-windows-lv'
} else {
    $CanonicalRunnerLabel.Trim()
}
$primaryRunnerLabel = if (-not [string]::IsNullOrWhiteSpace($RunnerLabel)) {
    $RunnerLabel.Trim()
} elseif (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_LABEL)) {
    $env:LVIE_RUNNER_LABEL.Trim()
} else {
    $canonicalRunnerLabel
}

$runnerLabelsResolved = @()
if ($RunnerLabels) {
    $runnerLabelsResolved += $RunnerLabels
}
if (-not [string]::IsNullOrWhiteSpace($primaryRunnerLabel)) {
    $runnerLabelsResolved += $primaryRunnerLabel
}
if (-not [string]::IsNullOrWhiteSpace($canonicalRunnerLabel)) {
    $runnerLabelsResolved += $canonicalRunnerLabel
}
$runnerLabelsResolved = $runnerLabelsResolved | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique

$canonicalRunnerLabel = if ([string]::IsNullOrWhiteSpace($CanonicalRunnerLabel)) {
    'self-hosted-windows-lv'
} else {
    $CanonicalRunnerLabel.Trim()
}
$primaryRunnerLabel = if (-not [string]::IsNullOrWhiteSpace($RunnerLabel)) {
    $RunnerLabel.Trim()
} elseif (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_LABEL)) {
    $env:LVIE_RUNNER_LABEL.Trim()
} else {
    $canonicalRunnerLabel
}

$runnerLabelsResolved = @()
if ($RunnerLabels) {
    $runnerLabelsResolved += $RunnerLabels
}
if (-not [string]::IsNullOrWhiteSpace($primaryRunnerLabel)) {
    $runnerLabelsResolved += $primaryRunnerLabel
}
if (-not [string]::IsNullOrWhiteSpace($canonicalRunnerLabel)) {
    $runnerLabelsResolved += $canonicalRunnerLabel
}
$runnerLabelsResolved = $runnerLabelsResolved | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique

New-Item -Path $worktreeRootResolved -ItemType Directory -Force | Out-Null
New-Item -Path $artifactRootResolved -ItemType Directory -Force | Out-Null
New-Item -Path $lockRootResolved -ItemType Directory -Force | Out-Null
New-Item -Path $logRootResolved -ItemType Directory -Force | Out-Null

$contractPath = Resolve-RunnerContractPath -RunnerRoot $runnerRootResolved -WorkRoot $workRootResolved
if ([string]::IsNullOrWhiteSpace($contractPath)) {
    throw "Failed to resolve runner contract path."
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

$existing = Get-RunnerContract -ContractPath $contractPath
if ($existing -and $existing.created_at_utc) {
    $contract | Add-Member -MemberType NoteProperty -Name created_at_utc -Value $existing.created_at_utc
} else {
    $contract | Add-Member -MemberType NoteProperty -Name created_at_utc -Value $timestamp
}

Set-RunnerContract -ContractPath $contractPath -Contract $contract

[Environment]::SetEnvironmentVariable('LVIE_RUNNER_ROOT', $runnerRootResolved, $Scope)
[Environment]::SetEnvironmentVariable('LVIE_RUNNER_WORK_ROOT', $workRootResolved, $Scope)
[Environment]::SetEnvironmentVariable('LVIE_WORKTREE_ROOT', $worktreeRootResolved, $Scope)
[Environment]::SetEnvironmentVariable('LVIE_ARTIFACT_ROOT', $artifactRootResolved, $Scope)
[Environment]::SetEnvironmentVariable('LVIE_LOCK_ROOT', $lockRootResolved, $Scope)
[Environment]::SetEnvironmentVariable('LVIE_LOG_ROOT', $logRootResolved, $Scope)
[Environment]::SetEnvironmentVariable('LVIE_RUNNER_CONTRACT_PATH', $contractPath, $Scope)
[Environment]::SetEnvironmentVariable('LVIE_RUNNER_LABEL', $primaryRunnerLabel, $Scope)
[Environment]::SetEnvironmentVariable('LVIE_RUNNER_LABELS', ($runnerLabelsResolved -join ','), $Scope)
[Environment]::SetEnvironmentVariable('LVIE_CANONICAL_RUNNER_LABEL', $canonicalRunnerLabel, $Scope)

Write-Host ("Runner contract written: {0}" -f $contractPath)
Write-Host ("LVIE_WORKTREE_ROOT set to {0} ({1} scope)" -f $worktreeRootResolved, $Scope)
Write-Host ("LVIE_ARTIFACT_ROOT set to {0} ({1} scope)" -f $artifactRootResolved, $Scope)
Write-Host ("LVIE_LOCK_ROOT set to {0} ({1} scope)" -f $lockRootResolved, $Scope)
Write-Host ("LVIE_LOG_ROOT set to {0} ({1} scope)" -f $logRootResolved, $Scope)
if ($primaryRunnerLabel) {
    Write-Host ("LVIE_RUNNER_LABEL set to {0} ({1} scope)" -f $primaryRunnerLabel, $Scope)
}
if ($runnerLabelsResolved) {
    Write-Host ("LVIE_RUNNER_LABELS set to {0} ({1} scope)" -f ($runnerLabelsResolved -join ','), $Scope)
}
Write-Host "Restart the runner service after updating Machine/User environment variables."

# Configure git safe.directory scoped to the runner work root to avoid dubious ownership errors
try {
    $safePattern = ($workRootResolved -replace '\\', '/') + '/*'
    & git config --system --add safe.directory $safePattern
    Write-Host ("Git safe.directory configured: {0} (system)" -f $safePattern)
} catch {
    Write-Warning ("Failed to configure git safe.directory: {0}" -f $_.Exception.Message)
}
