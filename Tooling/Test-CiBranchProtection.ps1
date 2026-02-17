#Requires -Version 7.0
<#
.SYNOPSIS
    Verifies develop branch required status-check policy for CI profile rollout.

.DESCRIPTION
    Queries GitHub branch protection required status checks and validates that the
    configured required contexts match policy. If the current token cannot read
    branch protection, emits a handoff-ready status record for repository admins.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [string]$Branch = 'develop',

    [Parameter(Mandatory = $false)]
    [Alias('RequiredContext')]
    [string[]]$RequiredContexts = @(
        'CI Pipeline / PowerShell Lint',
        'CI Pipeline / Pipeline Contract'
    ),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 2147483647)]
    [int]$RequiredCheckAppId = 15368,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'TestResults/agent-logs/branch-protection-status.latest.json',

    [switch]$FailOnMismatch
)

$ErrorActionPreference = 'Stop'

function Resolve-Repository {
    param([string]$RepoInput)

    if (-not [string]::IsNullOrWhiteSpace($RepoInput)) {
        return $RepoInput.Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GH_REPO)) {
        return $env:GH_REPO.Trim()
    }

    $resolverPath = Join-Path $PSScriptRoot 'Resolve-GitHubRepo.ps1'
    if (Test-Path -Path $resolverPath -PathType Leaf) {
        try {
            $resolved = & pwsh -NoProfile -File $resolverPath
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($resolved)) {
                return $resolved.Trim()
            }
        } catch {
            Write-Verbose ("Resolve-GitHubRepo failed: {0}" -f $_.Exception.Message)
        }
    }

    $originUrl = git remote get-url origin 2>$null
    if ($LASTEXITCODE -eq 0 -and $originUrl -match 'github\.com[:/](.+?/.+?)(?:\.git)?$') {
        return $matches[1]
    }

    throw 'Unable to resolve repository. Provide -Repo <owner/name> or set GH_REPO.'
}

function Write-StatusFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$StatusObject
    )

    $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
    }

    $parent = Split-Path -Parent $fullPath
    if (-not (Test-Path -Path $parent -PathType Container)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $StatusObject | ConvertTo-Json -Depth 8 | Out-File -FilePath $fullPath -Encoding utf8
    return $fullPath
}

$resolvedRepo = Resolve-Repository -RepoInput $Repo
$apiPath = "repos/$resolvedRepo/branches/$Branch/protection/required_status_checks"

$expectedContexts = @($RequiredContexts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
if ($expectedContexts.Count -eq 0) {
    throw 'At least one required status-check context must be provided.'
}

$rawResponse = $null
$apiError = $null
try {
    $rawResponse = gh api $apiPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $apiError = ($rawResponse | Out-String).Trim()
    }
} catch {
    $apiError = $_.Exception.Message
}

if (-not [string]::IsNullOrWhiteSpace($apiError)) {
    $status = [ordered]@{
        status = 'unknown'
        reason = 'branch-protection-api-unavailable'
        repository = $resolvedRepo
        branch = $Branch
        required_context_expected = $expectedContexts
        required_contexts_actual = @()
        strict_required_status_checks = $null
        generated_utc = (Get-Date).ToUniversalTime().ToString('o')
        message = "Unable to read required status checks. Confirm GH token permissions (repo admin or branch-protection read) and rerun."
        api_error = $apiError
    }
    $outputFile = Write-StatusFile -Path $OutputPath -StatusObject $status
    Write-Warning ($status.message)
    Write-Warning ("API error: {0}" -f $apiError)
    Write-Host ("Wrote branch protection status: {0}" -f $outputFile)
    if ($FailOnMismatch) {
        throw 'Branch protection verification failed because required status checks were not readable.'
    }
    exit 0
}

$parsed = $rawResponse | ConvertFrom-Json
$actualContexts = @()
if ($null -ne $parsed.contexts) {
    $actualContexts = @($parsed.contexts | ForEach-Object { [string]$_ } | Sort-Object -Unique)
}

$actualChecks = @()
if ($null -ne $parsed.checks) {
    foreach ($entry in $parsed.checks) {
        if ($null -eq $entry) {
            continue
        }

        $context = [string]$entry.context
        if ([string]::IsNullOrWhiteSpace($context)) {
            continue
        }

        $appId = $null
        try {
            if ($null -ne $entry.app_id -and -not [string]::IsNullOrWhiteSpace([string]$entry.app_id)) {
                $parsedAppId = 0
                if ([int]::TryParse([string]$entry.app_id, [ref]$parsedAppId)) {
                    $appId = $parsedAppId
                }
            }
        } catch {
            $appId = $null
        }

        $actualChecks += [pscustomobject]@{
            context = $context
            app_id  = $appId
        }
    }
}

if ($actualContexts.Count -eq 0 -and $actualChecks.Count -gt 0) {
    $actualContexts = @($actualChecks | ForEach-Object { $_.context } | Sort-Object -Unique)
}

$missing = @($expectedContexts | Where-Object { $_ -notin $actualContexts })
$extra = @($actualContexts | Where-Object { $_ -notin $expectedContexts })
$contextsMatch = ($missing.Count -eq 0 -and $extra.Count -eq 0)

$appIdMismatches = @()
foreach ($expectedContext in $expectedContexts) {
    $matchingChecks = @($actualChecks | Where-Object { $_.context -eq $expectedContext })
    if ($matchingChecks.Count -eq 0) {
        $appIdMismatches += [ordered]@{
            context         = $expectedContext
            expected_app_id = $RequiredCheckAppId
            actual_app_id   = $null
            reason          = 'missing-check-entry'
        }
        continue
    }

    foreach ($check in $matchingChecks) {
        if ($check.app_id -ne $RequiredCheckAppId) {
            $appIdMismatches += [ordered]@{
                context         = $expectedContext
                expected_app_id = $RequiredCheckAppId
                actual_app_id   = $check.app_id
                reason          = 'app-id-mismatch'
            }
        }
    }
}

$appIdMatch = ($appIdMismatches.Count -eq 0)
$exactMatch = ($contextsMatch -and $appIdMatch)

$status = [ordered]@{
    status = if ($exactMatch) { 'pass' } else { 'mismatch' }
    reason = if ($exactMatch) { 'required-status-checks-match' } else { 'required-status-checks-differ' }
    repository = $resolvedRepo
    branch = $Branch
    strict_required_status_checks = $parsed.strict
    required_check_app_id_expected = $RequiredCheckAppId
    required_context_expected = $expectedContexts
    required_contexts_actual = $actualContexts
    required_checks_actual = $actualChecks
    missing_contexts = $missing
    extra_contexts = $extra
    app_id_mismatches = $appIdMismatches
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
}

$outputFile = Write-StatusFile -Path $OutputPath -StatusObject $status
Write-Host ("Wrote branch protection status: {0}" -f $outputFile)
Write-Host ("Expected required contexts: {0}" -f ($expectedContexts -join ', '))
Write-Host ("Actual required contexts: {0}" -f ($(if ($actualContexts.Count -gt 0) { $actualContexts -join ', ' } else { '<none>' })))

if ($exactMatch) {
    Write-Host 'Branch protection required status checks match expected policy.'
    exit 0
}

Write-Warning ("Missing contexts: {0}" -f ($(if ($missing.Count -gt 0) { $missing -join ', ' } else { '<none>' })))
Write-Warning ("Extra contexts: {0}" -f ($(if ($extra.Count -gt 0) { $extra -join ', ' } else { '<none>' })))
if ($appIdMismatches.Count -gt 0) {
    Write-Warning ("App-id mismatches: {0}" -f (($appIdMismatches | ConvertTo-Json -Compress)))
}

if ($FailOnMismatch) {
    throw 'Branch protection required status-check policy does not match expected configured contexts.'
}

