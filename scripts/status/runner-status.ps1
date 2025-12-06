[CmdletBinding()]
param(
    [string]$WorkflowName = "Ollama Executor Smoke Test",
    [string]$Repo,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoName {
    param([string]$Repo)
    if ($Repo) { return $Repo }

    $repoInfoJson = gh repo view --json nameWithOwner 2>$null
    if (-not $repoInfoJson) {
        throw "Repo not provided and 'gh repo view' returned no data."
    }
    $repoInfo = $repoInfoJson | ConvertFrom-Json
    if (-not $repoInfo.nameWithOwner) {
        throw "Could not resolve repository name from gh cli."
    }
    return $repoInfo.nameWithOwner
}

function Get-RunnerStatus {
    param([string]$RepoName)
    $runnerJson = gh api "/repos/$RepoName/actions/runners" 2>$null
    if (-not $runnerJson) { throw "Failed to query runners for $RepoName." }
    return $runnerJson | ConvertFrom-Json
}

function Get-LatestRunId {
    param([string]$WorkflowName)
    $runListJson = gh run list --workflow $WorkflowName --limit 1 --json databaseId 2>$null
    if (-not $runListJson -or -not $runListJson.Trim()) { return $null }
    $listObj = $runListJson | ConvertFrom-Json
    if (-not $listObj -or $listObj.Count -eq 0) { return $null }
    return $listObj[0].databaseId
}

function Get-RunDetail {
    param([string]$RunId)
    $runJson = gh run view $RunId --json status,conclusion,displayTitle,headBranch,createdAt,updatedAt,jobs 2>$null
    if (-not $runJson) { throw "Failed to fetch run $RunId." }
    return $runJson | ConvertFrom-Json
}

function Format-JobLine {
    param($Job)
    if (-not $Job) { return "n/a -> n/a | <missing job> | n/a/-" }
    $start = if ($Job.startedAt) { $Job.startedAt } else { 'n/a' }
    $end = if ($Job.completedAt) { $Job.completedAt } else { 'n/a' }
    $conclusion = if ($Job.conclusion) { $Job.conclusion } else { '-' }
    $name = if ($Job.name) { $Job.name } else { 'unnamed' }
    $status = if ($Job.status) { $Job.status } else { 'n/a' }
    return "${start} -> ${end} | ${name} | ${status}/${conclusion}"
}

$repoName = Resolve-RepoName -Repo $Repo
$runnerStatus = Get-RunnerStatus -RepoName $repoName
$latestRunId = Get-LatestRunId -WorkflowName $WorkflowName
$latestRun = if ($latestRunId) { Get-RunDetail -RunId $latestRunId } else { $null }

if ($Json) {
    $payload = [ordered]@{
        repo        = $repoName
        runner_info = $runnerStatus
        latest_run  = $latestRun
    }
    $payload | ConvertTo-Json -Depth 6
    return
}

Write-Host "Repo: $repoName"
Write-Host "Workflow: $WorkflowName"
Write-Host ""
Write-Host "Runners:"
if ($runnerStatus.runners) {
    foreach ($r in $runnerStatus.runners) {
        $labelList = ($r.labels | ForEach-Object { $_.name }) -join ','
        Write-Host ("- {0} | {1} | busy={2} | labels={3}" -f $r.name, $r.status, $r.busy, $labelList)
    }
} else {
    Write-Host "- none returned"
}

Write-Host ""
if (-not $latestRunId) {
    Write-Host "No runs found for workflow '$WorkflowName'."
    return
}

Write-Host ("Latest run: {0} | status={1} | conclusion={2} | branch={3} | title={4}" -f `
    $latestRunId, $latestRun.status, $latestRun.conclusion, $latestRun.headBranch, $latestRun.displayTitle)
Write-Host ("Created: {0} | Updated: {1}" -f $latestRun.createdAt, $latestRun.updatedAt)

Write-Host "Jobs:"
foreach ($job in $latestRun.jobs) {
    Write-Host ("- {0}" -f (Format-JobLine -Job $job))
}
