#Requires -Version 7.0
<#
.SYNOPSIS
    Validates runner contract and Git safe.directory configuration.

.DESCRIPTION
    Ensures the runner contract exists and required paths resolve to existing
    directories. Optionally verifies Git safe.directory includes the work root
    pattern to avoid dubious ownership errors.
#>

[CmdletBinding()]
param(
    [string]$ContractPath,
    [bool]$FailOnMissingSafeDirectory = $true
)

$ErrorActionPreference = 'Stop'

function Resolve-ContractPath {
    param([string]$Path)
    if ($Path) { return $Path }
    if ($env:LVIE_RUNNER_CONTRACT_PATH) { return $env:LVIE_RUNNER_CONTRACT_PATH }
    return $null
}

function Test-Directory {
    param([string]$Path, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw ("Runner contract missing {0}." -f $Label)
    }
    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw ("Runner contract path not found: {0} => {1}" -f $Label, $Path)
    }
}

function Get-GitSafeDirectoryEntry {
    $entries = @()
    try {
        $entries = & git config --system --get-all safe.directory 2>$null
    } catch {
        $entries = @()
    }
    return $entries | Where-Object { $_ -and $_.Trim().Length -gt 0 }
}

$resolvedContract = Resolve-ContractPath -Path $ContractPath
if (-not $resolvedContract) {
    throw "Runner contract path not provided and LVIE_RUNNER_CONTRACT_PATH is not set."
}
if (-not (Test-Path -Path $resolvedContract)) {
    throw ("Runner contract file not found: {0}" -f $resolvedContract)
}

$contract = Get-Content -Path $resolvedContract -Raw | ConvertFrom-Json
Test-Directory -Path $contract.runner_root -Label 'runner_root'
Test-Directory -Path $contract.work_root -Label 'work_root'
Test-Directory -Path $contract.worktree_root -Label 'worktree_root'
Test-Directory -Path $contract.artifact_root -Label 'artifact_root'
Test-Directory -Path $contract.lock_root -Label 'lock_root'
Test-Directory -Path $contract.log_root -Label 'log_root'

$workRootPattern = ($contract.work_root -replace '\\', '/') + '/*'
$safeEntries = Get-GitSafeDirectoryEntry
$safeOk = $false
if ($safeEntries) {
    $safeOk = $safeEntries | Where-Object { $_ -eq '*' -or $_ -eq $workRootPattern }
}

if (-not $safeOk) {
    $message = "Git safe.directory missing for work root pattern: $workRootPattern"
    if ($FailOnMissingSafeDirectory) {
        throw $message
    } else {
        Write-Warning $message
    }
} else {
    Write-Host ("Git safe.directory OK: {0}" -f $workRootPattern)
}

Write-Host ("Runner contract OK: {0}" -f $resolvedContract)
