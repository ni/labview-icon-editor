#Requires -Version 7.0
<#
.SYNOPSIS
    Computes CI runtime baseline metrics by ci_profile from GitHub Actions runs.

.DESCRIPTION
    Fetches CI Pipeline (Composite) workflow runs, infers ci_profile, and writes
    P50/P90 wall-clock runtime metrics to TestResults/agent-logs. Wall-clock
    duration uses createdAt -> updatedAt and includes queue + execution time.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [string]$Workflow = 'ci-composite.yml',

    [Parameter(Mandatory = $false)]
    [int]$Limit = 300,

    [Parameter(Mandatory = $false)]
    [int]$WindowDays = 30,

    [Parameter(Mandatory = $false)]
    [int]$MinSampleSize = 10,

    [Parameter(Mandatory = $false)]
    [string]$OutputRoot = 'TestResults/agent-logs',

    [switch]$IncludeNonSuccess
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

function Get-Percentile {
    param(
        [double[]]$Values,
        [double]$Percentile
    )

    if (-not $Values -or $Values.Count -eq 0) {
        return $null
    }

    $sorted = @($Values | Sort-Object)
    $rank = [Math]::Ceiling($Percentile * $sorted.Count) - 1
    if ($rank -lt 0) { $rank = 0 }
    if ($rank -ge $sorted.Count) { $rank = $sorted.Count - 1 }
    return [double]$sorted[$rank]
}

function Get-DispatchProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [long]$RunId
    )

    $raw = gh run view $RunId --repo $RepoName --json jobs 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
        return 'unknown'
    }

    $view = $raw | ConvertFrom-Json
    $jobs = @($view.jobs)
    if ($jobs.Count -eq 0) {
        return 'unknown'
    }

    $buildVipJob = $jobs | Where-Object { [string]$_.name -eq 'Build VI Package' } | Select-Object -First 1
    if ($null -eq $buildVipJob) {
        return 'unknown'
    }

    $conclusion = [string]$buildVipJob.conclusion
    if ($conclusion -eq 'skipped') {
        return 'release-priority'
    }

    if ($conclusion -in @('success', 'failure', 'cancelled', 'timed_out', 'startup_failure', 'action_required')) {
        return 'full'
    }

    return 'unknown'
}

function Get-ProfileTargetMap {
    return @{
        'release-priority' = 25.0
        'pr-fast' = 35.0
        'full' = $null
    }
}

$resolvedRepo = Resolve-Repository -RepoInput $Repo
$cutoffUtc = (Get-Date).ToUniversalTime().AddDays(-$WindowDays)

$runListRaw = gh run list `
    --repo $resolvedRepo `
    --workflow $Workflow `
    --limit $Limit `
    --json databaseId,event,status,conclusion,createdAt,updatedAt,url,displayTitle,headBranch,headSha 2>&1

if ($LASTEXITCODE -ne 0) {
    throw ("gh run list failed: {0}" -f ($runListRaw | Out-String).Trim())
}

$runList = @()
if (-not [string]::IsNullOrWhiteSpace($runListRaw)) {
    $parsed = $runListRaw | ConvertFrom-Json
    if ($parsed -is [array]) {
        $runList = @($parsed)
    } elseif ($null -ne $parsed) {
        $runList = @($parsed)
    }
}

$dispatchProfileCache = @{}
$rows = New-Object System.Collections.Generic.List[object]

foreach ($run in $runList) {
    if ($null -eq $run.databaseId) {
        continue
    }

    $created = [datetime]$run.createdAt
    $updated = [datetime]$run.updatedAt
    if ($created.ToUniversalTime() -lt $cutoffUtc) {
        continue
    }

    if (-not $IncludeNonSuccess -and [string]$run.conclusion -ne 'success') {
        continue
    }

    $eventName = [string]$run.event
    $runProfile = 'unknown'
    switch ($eventName) {
        'pull_request' { $runProfile = 'pr-fast' }
        'push' { $runProfile = 'full' }
        'workflow_dispatch' {
            $runIdKey = [string]$run.databaseId
            if ($dispatchProfileCache.ContainsKey($runIdKey)) {
                $runProfile = $dispatchProfileCache[$runIdKey]
            } else {
                $inferred = Get-DispatchProfile -RepoName $resolvedRepo -RunId ([long]$run.databaseId)
                $dispatchProfileCache[$runIdKey] = $inferred
                $runProfile = $inferred
            }
        }
        default { $runProfile = 'unknown' }
    }

    $durationMinutes = [math]::Round(($updated - $created).TotalMinutes, 2)
    $rows.Add([pscustomobject]@{
        run_id = [long]$run.databaseId
        profile = $runProfile
        event = $eventName
        status = [string]$run.status
        conclusion = [string]$run.conclusion
        created_at = $created.ToUniversalTime().ToString('o')
        updated_at = $updated.ToUniversalTime().ToString('o')
        duration_minutes = $durationMinutes
        head_branch = [string]$run.headBranch
        head_sha = [string]$run.headSha
        title = [string]$run.displayTitle
        url = [string]$run.url
    }) | Out-Null
}

$profileTargets = Get-ProfileTargetMap
$profilesToReport = @('release-priority', 'pr-fast', 'full')
$profileMetrics = New-Object System.Collections.Generic.List[object]

foreach ($profileName in $profilesToReport) {
    $profileRuns = @($rows | Where-Object { $_.profile -eq $profileName })
    $durations = @($profileRuns | ForEach-Object { [double]$_.duration_minutes })
    $count = $durations.Count
    $p50 = Get-Percentile -Values $durations -Percentile 0.50
    $p90 = Get-Percentile -Values $durations -Percentile 0.90
    $target = $profileTargets[$profileName]

    $profileMetrics.Add([pscustomobject]@{
        profile = $profileName
        sample_count = $count
        minimum_minutes = if ($count -gt 0) { [math]::Round(($durations | Measure-Object -Minimum).Minimum, 2) } else { $null }
        p50_minutes = if ($null -ne $p50) { [math]::Round($p50, 2) } else { $null }
        p90_minutes = if ($null -ne $p90) { [math]::Round($p90, 2) } else { $null }
        average_minutes = if ($count -gt 0) { [math]::Round(($durations | Measure-Object -Average).Average, 2) } else { $null }
        maximum_minutes = if ($count -gt 0) { [math]::Round(($durations | Measure-Object -Maximum).Maximum, 2) } else { $null }
        target_p90_minutes = $target
        meets_p90_target = if ($null -eq $target -or $null -eq $p90) { $null } else { ($p90 -le $target) }
        meets_min_sample = ($count -ge $MinSampleSize)
    }) | Out-Null
}

$insufficient = @($profileMetrics | Where-Object { -not $_.meets_min_sample } | ForEach-Object { $_.profile })
$unknownRuns = @($rows | Where-Object { $_.profile -eq 'unknown' })

$status = [pscustomobject]@{
    status = 'ok'
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    repository = $resolvedRepo
    workflow = $Workflow
    window_days = $WindowDays
    cutoff_utc = $cutoffUtc.ToString('o')
    min_sample_size = $MinSampleSize
    include_non_success = [bool]$IncludeNonSuccess
    run_count = $rows.Count
    unknown_profile_count = $unknownRuns.Count
    insufficient_profiles = $insufficient
    profile_metrics = @($profileMetrics.ToArray())
    assumptions = @(
        'Duration uses createdAt->updatedAt wall-clock time and includes queue delay.',
        "pull_request events map to pr-fast; push events map to full; workflow_dispatch profile is inferred from Build VI Package job conclusion."
    )
    runs = @($rows.ToArray())
}

$fullOutputRoot = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    [System.IO.Path]::GetFullPath($OutputRoot)
} else {
    [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputRoot))
}
if (-not (Test-Path -Path $fullOutputRoot -PathType Container)) {
    New-Item -Path $fullOutputRoot -ItemType Directory -Force | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$jsonPath = Join-Path $fullOutputRoot ("ci-profile-runtime-baseline.{0}.json" -f $stamp)
$latestJsonPath = Join-Path $fullOutputRoot 'ci-profile-runtime-baseline.latest.json'
$latestMdPath = Join-Path $fullOutputRoot 'ci-profile-runtime-baseline.latest.md'

$status | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding utf8
$status | ConvertTo-Json -Depth 10 | Out-File -FilePath $latestJsonPath -Encoding utf8

$lines = @()
$lines += '# CI Profile Runtime Baseline'
$lines += ''
$lines += ("- Generated UTC: {0}" -f $status.generated_utc)
$lines += ("- Repository: {0}" -f $status.repository)
$lines += ("- Workflow: {0}" -f $status.workflow)
$lines += ("- Window days: {0}" -f $status.window_days)
$lines += ("- Cutoff UTC: {0}" -f $status.cutoff_utc)
$lines += ("- Runs analyzed: {0}" -f $status.run_count)
$lines += ("- Unknown profile runs: {0}" -f $status.unknown_profile_count)
$lines += ''
$lines += '| Profile | Samples | P50 (min) | P90 (min) | Target P90 (min) | Meets Target | Meets Sample Floor |'
$lines += '|---|---:|---:|---:|---:|---|---|'
foreach ($metric in $profileMetrics) {
    $targetDisplay = if ($null -eq $metric.target_p90_minutes) { 'N/A' } else { [string]$metric.target_p90_minutes }
    $targetPass = if ($null -eq $metric.meets_p90_target) { 'N/A' } elseif ($metric.meets_p90_target) { 'Yes' } else { 'No' }
    $samplePass = if ($metric.meets_min_sample) { 'Yes' } else { 'No' }
    $lines += ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} |" -f `
        $metric.profile, `
        $metric.sample_count, `
        $(if ($null -eq $metric.p50_minutes) { 'N/A' } else { $metric.p50_minutes }), `
        $(if ($null -eq $metric.p90_minutes) { 'N/A' } else { $metric.p90_minutes }), `
        $targetDisplay, `
        $targetPass, `
        $samplePass)
}
$lines += ''
$lines += 'Notes:'
$lines += '- Wall-clock durations include queue and execution time.'
$lines += '- Use this report for trending and outlier triage, not as an isolated execution-time benchmark.'

$lines -join [Environment]::NewLine | Out-File -FilePath $latestMdPath -Encoding utf8

Write-Host ("Wrote runtime baseline JSON: {0}" -f $jsonPath)
Write-Host ("Wrote runtime baseline latest JSON: {0}" -f $latestJsonPath)
Write-Host ("Wrote runtime baseline report: {0}" -f $latestMdPath)

$profileMetrics |
    Select-Object profile, sample_count, p50_minutes, p90_minutes, target_p90_minutes, meets_p90_target, meets_min_sample |
    Format-Table -AutoSize
