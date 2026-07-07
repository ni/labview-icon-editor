#Requires -Version 7.0
<#
.SYNOPSIS
    Trigger CI Pipeline (Composite) for a specific commit by creating a temp branch.

.DESCRIPTION
    Creates (or reuses) a short-lived branch on the remote that points to the
    specified commit, then triggers workflow_dispatch for that ref.

.PARAMETER Sha
    Commit SHA (or any rev-parse-able ref). Required.

.PARAMETER BranchPrefix
    Prefix for the temporary branch name. Default: ci-run.

.PARAMETER Remote
    Remote name to push to. Default: origin.

.PARAMETER WorkflowName
    Workflow display name for gh workflow run. Default: CI Pipeline (Composite).

.PARAMETER Force
    Force-update the remote branch if it already exists.

.PARAMETER CleanupRemote
    If set, delete the remote branch after dispatching the workflow.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Sha,

    [Parameter(Mandatory = $false)]
    [string]$BranchPrefix = 'ci-run',

    [Parameter(Mandatory = $false)]
    [string]$Remote = 'origin',

    [Parameter(Mandatory = $false)]
    [string]$WorkflowName = 'CI Pipeline (Composite)',

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$CleanupRemote
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([string[]]$GitArgs)
    $output = & git @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed: $output"
    }
    return $output
}

function Confirm-GhReady {
    $null = & gh --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI (gh) not found or not authenticated."
    }
}

$repoRoot = Invoke-Git @('rev-parse', '--show-toplevel')
Set-Location $repoRoot

Confirm-GhReady

$fullSha = Invoke-Git @('rev-parse', '--verify', "$Sha^{commit}")
$shortSha = Invoke-Git @('rev-parse', '--short', $fullSha)

$branchName = "{0}/{1}" -f $BranchPrefix.TrimEnd('/'), $shortSha.Trim()

$existing = Invoke-Git @('ls-remote', '--heads', $Remote, $branchName)
if (-not [string]::IsNullOrWhiteSpace($existing) -and -not $Force) {
    $suffix = Get-Date -Format 'yyyyMMdd-HHmmss'
    $branchName = "{0}/{1}-{2}" -f $BranchPrefix.TrimEnd('/'), $shortSha.Trim(), $suffix
}

$refSpec = "{0}:refs/heads/{1}" -f $fullSha.Trim(), $branchName
if ($Force) {
    $refSpec = "+$refSpec"
}

Write-Host ("Pushing {0} to {1}/{2}" -f $fullSha.Trim(), $Remote, $branchName)
Invoke-Git @('push', $Remote, $refSpec) | Out-Host

Write-Host ("Triggering workflow '{0}' on ref '{1}'..." -f $WorkflowName, $branchName)
& gh workflow run $WorkflowName --ref $branchName | Out-Host

if ($CleanupRemote) {
    Write-Host ("Deleting remote branch {0}/{1}" -f $Remote, $branchName)
    Invoke-Git @('push', $Remote, '--delete', $branchName) | Out-Host
}

Write-Host ("Done. Ref: {0}" -f $branchName)

