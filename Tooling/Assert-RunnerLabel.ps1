#Requires -Version 7.0
<#
.SYNOPSIS
    Validates that the current runner is registered with expected labels.

.DESCRIPTION
    Queries the GitHub Actions API for the current runner name and verifies
    required labels are present. Intended for self-hosted runners.

.PARAMETER ExpectedLabel
    Primary label expected for this workflow run. Defaults to LVIE_EXPECTED_RUNNER_LABEL.

.PARAMETER ExpectedLabels
    Additional labels to require.

.PARAMETER CanonicalLabel
    Canonical label that must always be present. Defaults to self-hosted-windows-lv
    or LVIE_CANONICAL_RUNNER_LABEL when provided.

.PARAMETER RequireCanonicalLabel
    Force canonical label requirement (default: true).

.PARAMETER RequireLabel
    Fail if labels cannot be validated (default: true).

.PARAMETER Repo
    GitHub repository in owner/name format. Defaults to GITHUB_REPOSITORY.

.PARAMETER RunnerName
    Runner name to match. Defaults to RUNNER_NAME.

.PARAMETER Token
    GitHub token for API access. Defaults to GITHUB_TOKEN.
#>

[CmdletBinding()]
param(
    [string]$ExpectedLabel,
    [string[]]$ExpectedLabels,
    [string]$CanonicalLabel,
    [switch]$RequireCanonicalLabel,
    [switch]$RequireLabel,
    [string]$Repo,
    [string]$RunnerName,
    [string]$Token
)

$ErrorActionPreference = 'Stop'
$requireLabelEnabled = $RequireLabel.IsPresent -or -not $PSBoundParameters.ContainsKey('RequireLabel')
$requireCanonicalEnabled = $RequireCanonicalLabel.IsPresent -or -not $PSBoundParameters.ContainsKey('RequireCanonicalLabel')

function Test-Truthy {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $normalized = $Value.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no'))
}

if (Test-Truthy -Value $env:LVIE_SKIP_RUNNER_LABEL_CHECK) {
    Write-Host 'Runner label check skipped (LVIE_SKIP_RUNNER_LABEL_CHECK=true).'
    return
}

$strictLabelCheck = Test-Truthy -Value $env:LVIE_STRICT_RUNNER_LABEL_CHECK

if ([string]::IsNullOrWhiteSpace($ExpectedLabel)) {
    $ExpectedLabel = $env:LVIE_EXPECTED_RUNNER_LABEL
}
if ([string]::IsNullOrWhiteSpace($CanonicalLabel)) {
    $CanonicalLabel = $env:LVIE_CANONICAL_RUNNER_LABEL
}
if ([string]::IsNullOrWhiteSpace($CanonicalLabel)) {
    $CanonicalLabel = 'self-hosted-windows-lv'
}
if ([string]::IsNullOrWhiteSpace($Repo)) {
    $Repo = $env:GITHUB_REPOSITORY
}
if ([string]::IsNullOrWhiteSpace($RunnerName)) {
    $RunnerName = $env:RUNNER_NAME
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    $Token = $env:GITHUB_TOKEN
}

$expected = @()
if ($ExpectedLabels) { $expected += $ExpectedLabels }
if ($ExpectedLabel) { $expected += $ExpectedLabel }
if ($requireCanonicalEnabled -and $CanonicalLabel) { $expected += $CanonicalLabel }
$expected = $expected | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique

if (-not $expected -or $expected.Count -eq 0) {
    Write-Host 'Runner label check: no expected labels provided; skipping.'
    return
}

if ($env:GITHUB_ACTIONS -ne 'true') {
    $message = 'Runner label check: not running in GitHub Actions.'
    if ($requireLabelEnabled) {
        throw $message
    }
    Write-Warning $message
    return
}

if ([string]::IsNullOrWhiteSpace($Repo)) {
    $message = 'Runner label check: repository not available (GITHUB_REPOSITORY not set).'
    if ($requireLabelEnabled) { throw $message }
    Write-Warning $message
    return
}

if ([string]::IsNullOrWhiteSpace($RunnerName)) {
    $message = 'Runner label check: runner name not available (RUNNER_NAME not set).'
    if ($requireLabelEnabled) { throw $message }
    Write-Warning $message
    return
}

function Get-ContractLabelSet {
    $candidatePaths = @()
    $contractHelper = Join-Path $PSScriptRoot 'support\RunnerContract.ps1'
    if (-not (Test-Path -Path $contractHelper)) {
        return $null
    }

    . $contractHelper
    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_CONTRACT_PATH)) {
        $candidatePaths += $env:LVIE_RUNNER_CONTRACT_PATH
    }

    $resolvedPath = Resolve-RunnerContractPath -ContractPath $env:LVIE_RUNNER_CONTRACT_PATH -RunnerRoot $env:LVIE_RUNNER_ROOT -WorkRoot $env:LVIE_RUNNER_WORK_ROOT
    if (-not [string]::IsNullOrWhiteSpace($resolvedPath)) {
        $candidatePaths += $resolvedPath
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_WORKTREE_ROOT)) {
        try {
            $worktreeRoot = [System.IO.Path]::GetFullPath($env:LVIE_WORKTREE_ROOT)
            $workRoot = Split-Path -Parent $worktreeRoot
            if (-not [string]::IsNullOrWhiteSpace($workRoot)) {
                $candidatePaths += (Join-Path $workRoot 'runner-contract.json')
            }
        } catch {
            Write-Verbose ("Runner label check: unable to resolve LVIE_WORKTREE_ROOT '{0}'." -f $env:LVIE_WORKTREE_ROOT)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
        try {
            $repoRoot = (Resolve-Path -Path $env:GITHUB_WORKSPACE -ErrorAction Stop).Path
            $workRoot = Split-Path -Parent (Split-Path -Parent $repoRoot)
            if (-not [string]::IsNullOrWhiteSpace($workRoot)) {
                $candidatePaths += (Join-Path $workRoot 'lvie\runner-contract.json')
            }
        } catch {
            Write-Verbose ("Runner label check: unable to resolve GITHUB_WORKSPACE '{0}'." -f $env:GITHUB_WORKSPACE)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_WORKSPACE)) {
        $candidatePaths += (Join-Path $env:RUNNER_WORKSPACE 'lvie\runner-contract.json')
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_WORK_ROOT)) {
        $candidatePaths += (Join-Path $env:LVIE_RUNNER_WORK_ROOT 'lvie\runner-contract.json')
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_ROOT)) {
        $candidatePaths += (Join-Path $env:LVIE_RUNNER_ROOT '_work\lvie\runner-contract.json')
    }

    $candidatePaths = $candidatePaths | Where-Object { $_ } | Select-Object -Unique
    $contract = $null
    $contractPath = $null
    foreach ($candidate in $candidatePaths) {
        if (-not (Test-Path -Path $candidate)) {
            continue
        }
        $contract = Get-RunnerContract -ContractPath $candidate -RunnerRoot $env:LVIE_RUNNER_ROOT -WorkRoot $env:LVIE_RUNNER_WORK_ROOT
        if ($contract) {
            $contractPath = $candidate
            break
        }
    }
    if (-not $contract) {
        return $null
    }

    $labels = @()
    if ($contract.runner_labels) { $labels += $contract.runner_labels }
    if ($contract.runner_label) { $labels += $contract.runner_label }
    if ($contract.canonical_runner_label) { $labels += $contract.canonical_runner_label }
    $labels = $labels | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique
    return [pscustomobject]@{
        Labels    = $labels
        Source    = $contractPath
        HasLabels = ($labels.Count -gt 0)
    }
}

function Test-LabelSet {
    param(
        [string[]]$ExpectedLabels,
        [string[]]$ActualLabels,
        [string]$SourceLabel
    )

    $expectedNorm = $ExpectedLabels | ForEach-Object { $_.Trim().ToLowerInvariant() } | Select-Object -Unique
    $actualNorm = $ActualLabels | ForEach-Object { $_.Trim().ToLowerInvariant() } | Select-Object -Unique

    $missing = @()
    foreach ($label in $expectedNorm) {
        if (-not $actualNorm -or ($actualNorm -notcontains $label)) {
            $missing += $label
        }
    }

    Write-Host ("Runner label check: expected={0}" -f ($ExpectedLabels -join ', '))
    Write-Host ("Runner label check: actual={0}" -f ($ActualLabels -join ', '))

    if ($missing.Count -gt 0) {
        throw ("Runner label check failed: missing {0}." -f ($missing -join ', '))
    }

    if ($SourceLabel) {
        Write-Host ("Runner label check: OK ({0})." -f $SourceLabel)
    } else {
        Write-Host 'Runner label check: OK.'
    }
}

$contractFallback = Get-ContractLabelSet
if ($contractFallback -and -not $contractFallback.HasLabels) {
    Write-Warning ("Runner label check: runner contract at {0} has no labels. Run Tooling\Setup-Runner.ps1 to refresh it." -f $contractFallback.Source)
    if ($strictLabelCheck) {
        throw "Runner label check: strict mode enabled and contract is missing labels."
    }
    $contractFallback = $null
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    $fallback = $contractFallback
    if ($fallback -and $fallback.Labels -and $fallback.Labels.Count -gt 0) {
        Write-Warning ("Runner label check: GitHub token not available; validating against runner contract at {0}." -f $fallback.Source)
        Test-LabelSet -ExpectedLabels $expected -ActualLabels $fallback.Labels -SourceLabel 'contract fallback'
        return
    }

    $message = 'Runner label check: GitHub token not available (GITHUB_TOKEN not set).'
    if ($requireLabelEnabled -and $strictLabelCheck) { throw $message }
    Write-Warning $message
    return
}

function Get-RunnerInfo {
    param(
        [string]$RepoName,
        [string]$RunnerName,
        [string]$TokenValue
    )

    $headers = @{
        Authorization = "token $TokenValue"
        Accept        = 'application/vnd.github+json'
        'User-Agent'  = 'LVIE-RunnerLabel'
    }

    $perPage = 100
    $page = 1
    do {
        $uri = "https://api.github.com/repos/$RepoName/actions/runners?per_page=$perPage&page=$page"
        try {
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
        } catch {
            throw ("Runner label check: failed to query runner list: {0}" -f $_.Exception.Message)
        }

        if ($response -and $response.runners) {
            $match = $response.runners | Where-Object { $_.name -eq $RunnerName } | Select-Object -First 1
            if ($match) {
                return $match
            }
        }

        $count = if ($response -and $response.runners) { $response.runners.Count } else { 0 }
        $page += 1
    } while ($count -eq $perPage -and $page -le 10)

    return $null
}

$runnerInfo = $null
try {
    $runnerInfo = Get-RunnerInfo -RepoName $Repo -RunnerName $RunnerName -TokenValue $Token
} catch {
    $message = $_.Exception.Message
    if ($contractFallback -and $contractFallback.Labels -and $contractFallback.Labels.Count -gt 0) {
        Write-Warning ("Runner label check: API lookup failed ({0}). Falling back to runner contract at {1}." -f $message, $contractFallback.Source)
        Test-LabelSet -ExpectedLabels $expected -ActualLabels $contractFallback.Labels -SourceLabel 'contract fallback'
        return
    }
    if ($requireLabelEnabled -and $strictLabelCheck) { throw }
    Write-Warning ("Runner label check: API lookup failed ({0})." -f $message)
    return
}

if (-not $runnerInfo) {
    $message = ("Runner label check: runner '{0}' not found in repo {1}." -f $RunnerName, $Repo)
    if ($contractFallback -and $contractFallback.Labels -and $contractFallback.Labels.Count -gt 0) {
        Write-Warning ("{0} Using contract fallback at {1}." -f $message, $contractFallback.Source)
        Test-LabelSet -ExpectedLabels $expected -ActualLabels $contractFallback.Labels -SourceLabel 'contract fallback'
        return
    }
    if ($requireLabelEnabled -and $strictLabelCheck) { throw $message }
    Write-Warning $message
    return
}

$actualLabels = @()
if ($runnerInfo.labels) {
    $actualLabels = $runnerInfo.labels | ForEach-Object { $_.name }
}

Write-Host ("Runner label check: runner={0}" -f $RunnerName)
Test-LabelSet -ExpectedLabels $expected -ActualLabels $actualLabels -SourceLabel 'api'
