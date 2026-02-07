#Requires -Version 7.0
<#
.SYNOPSIS
    Fetch the latest pylavi offenders artifact from CI and write it locally.

.DESCRIPTION
    Downloads the pylavi offenders artifact(s) from the latest CI run and
    writes redacted reports under TestResults\agent-logs so new sessions can
    read them without rerunning vi_validate.

.PARAMETER Repo
    GitHub repository in owner/name form (defaults to env:GITHUB_REPOSITORY or git remote).

.PARAMETER Token
    GitHub token (defaults to env:GH_TOKEN or env:GITHUB_TOKEN). Needs actions:read.

.PARAMETER Workflow
    Workflow file name (default: ci-composite.yml).

.PARAMETER Sha
    Commit SHA to fetch (deterministic; selects the latest run for that SHA).

.PARAMETER RunId
    Workflow run id to fetch (deterministic).

.PARAMETER Branch
    Branch name to query (default: develop).

.PARAMETER Label
    Optional label suffix to fetch a specific artifact (e.g., strict or legacy).

.PARAMETER ArtifactPrefix
    Artifact name prefix (default: pylavi-validate-offenders).

.PARAMETER RepoRoot
    Optional repository root override.

.PARAMETER OutDir
    Output directory for reports (default: TestResults\agent-logs).

.PARAMETER PreferLabel
    When multiple artifacts are fetched, choose this label for pylavi-offenders.latest.json.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string]$Workflow = 'ci-composite.yml',

    [Parameter(Mandatory = $false)]
    [string]$Sha,

    [Parameter(Mandatory = $false)]
    [int]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$Branch = 'develop',

    [Parameter(Mandatory = $false)]
    [string]$Label,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactPrefix = 'pylavi-validate-offenders',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutDir = 'TestResults\agent-logs',

    [Parameter(Mandatory = $false)]
    [string]$PreferLabel = 'strict'
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$Override)
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return (Resolve-Path -Path $Override).Path
    }
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim()).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }
    return (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
}

function Resolve-RepoSlug {
    param([string]$RepoValue)
    if (-not [string]::IsNullOrWhiteSpace($RepoValue)) { return $RepoValue }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) { return $env:GITHUB_REPOSITORY }

    try {
        $url = git config --get remote.origin.url 2>$null
    } catch {
        $url = $null
    }
    if (-not [string]::IsNullOrWhiteSpace($url)) {
        if ($url -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?$') {
            return "$($Matches['owner'])/$($Matches['repo'])"
        }
    }
    throw 'Repo not provided and could not be inferred. Set -Repo or GITHUB_REPOSITORY.'
}

function Resolve-Token {
    param([string]$TokenValue)
    if (-not [string]::IsNullOrWhiteSpace($TokenValue)) { return $TokenValue }
    if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) { return $env:GH_TOKEN }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) { return $env:GITHUB_TOKEN }
    throw 'GitHub token not provided. Set -Token, GH_TOKEN, or GITHUB_TOKEN.'
}

$repoRootResolved = Resolve-RepoRoot -Override $RepoRoot
$repoSlug = Resolve-RepoSlug -RepoValue $Repo
$tokenResolved = Resolve-Token -TokenValue $Token
$outDirResolved = if ([System.IO.Path]::IsPathRooted($OutDir)) {
    $OutDir
} else {
    Join-Path $repoRootResolved $OutDir
}
New-Item -Path $outDirResolved -ItemType Directory -Force | Out-Null

$headers = @{
    Authorization = "Bearer $tokenResolved"
    Accept        = 'application/vnd.github+json'
    'User-Agent'  = 'lvie-pylavi-offenders'
    'X-GitHub-Api-Version' = '2022-11-28'
}

$workflowUri = "https://api.github.com/repos/$repoSlug/actions/workflows/$Workflow"
$workflowInfo = Invoke-RestMethod -Method Get -Uri $workflowUri -Headers $headers
$workflowId = $workflowInfo.id

if ($RunId -gt 0 -and -not [string]::IsNullOrWhiteSpace($Sha)) {
    throw 'Provide only one of -RunId or -Sha.'
}

$run = $null
if ($RunId -gt 0) {
    $runUri = "https://api.github.com/repos/$repoSlug/actions/runs/$RunId"
    $run = Invoke-RestMethod -Method Get -Uri $runUri -Headers $headers
    if ($run.workflow_id -ne $workflowId) {
        throw "RunId $RunId does not belong to workflow $Workflow."
    }
} else {
    $query = "status=completed&per_page=20"
    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
        $query += "&branch=$Branch"
    }
    if (-not [string]::IsNullOrWhiteSpace($Sha)) {
        $query += "&head_sha=$Sha"
    }
    $runsUri = "https://api.github.com/repos/$repoSlug/actions/workflows/$workflowId/runs?$query"
    $runsInfo = Invoke-RestMethod -Method Get -Uri $runsUri -Headers $headers
    $run = $runsInfo.workflow_runs | Select-Object -First 1
    if (-not $run) {
        $detail = if ($Sha) { "sha $Sha" } elseif ($Branch) { "branch $Branch" } else { 'workflow runs' }
        throw "No completed workflow runs found for $repoSlug ($Workflow) for $detail."
    }
}

$artifactsUri = "https://api.github.com/repos/$repoSlug/actions/runs/$($run.id)/artifacts"
$artifactsInfo = Invoke-RestMethod -Method Get -Uri $artifactsUri -Headers $headers
$artifacts = $artifactsInfo.artifacts | Where-Object { $_.name -like "$ArtifactPrefix*" }
if (-not [string]::IsNullOrWhiteSpace($Label)) {
    $targetName = "$ArtifactPrefix-$Label"
    $artifacts = $artifacts | Where-Object { $_.name -eq $targetName }
}
if (-not [string]::IsNullOrWhiteSpace($Sha)) {
    $shaMatches = $artifacts | Where-Object { $_.name -like "*$Sha*" }
    if ($shaMatches -and $shaMatches.Count -gt 0) {
        $artifacts = $shaMatches
    } else {
        Write-Warning "No artifacts matched SHA '$Sha' by name; falling back to prefix match."
    }
}

if (-not $artifacts -or $artifacts.Count -eq 0) {
    throw "No pylavi offenders artifacts found for run $($run.id)."
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runSha = $run.head_sha
$downloaded = @()
foreach ($artifact in $artifacts) {
    $artifactLabel = $artifact.name.Substring($ArtifactPrefix.Length).TrimStart('-')
    if ([string]::IsNullOrWhiteSpace($artifactLabel)) {
        $artifactLabel = 'unknown'
    }

    $zipPath = Join-Path $env:TEMP ("pylavi-offenders-{0}.zip" -f $artifact.id)
    Invoke-WebRequest -Method Get -Uri $artifact.archive_download_url -Headers $headers -OutFile $zipPath | Out-Null

    $extractDir = Join-Path $env:TEMP ("pylavi-offenders-{0}" -f $artifact.id)
    if (Test-Path -Path $extractDir) {
        Remove-Item -Path $extractDir -Recurse -Force
    }
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $reportPath = Join-Path $extractDir 'vi_validate_offenders.json'
    if (-not (Test-Path -Path $reportPath)) {
        throw "Expected vi_validate_offenders.json not found in artifact $($artifact.name)."
    }

    $latestLabel = Join-Path $outDirResolved ("pylavi-offenders.latest.{0}.json" -f $artifactLabel)
    $datedLabel = Join-Path $outDirResolved ("pylavi-offenders.{0}.{1}.json" -f $artifactLabel, $timestamp)
    $shaLabel = $null
    if (-not [string]::IsNullOrWhiteSpace($runSha)) {
        $shaLabel = Join-Path $outDirResolved ("pylavi-offenders.{0}.{1}.json" -f $artifactLabel, $runSha)
    }
    Copy-Item -Path $reportPath -Destination $latestLabel -Force
    Copy-Item -Path $reportPath -Destination $datedLabel -Force
    if ($shaLabel) {
        Copy-Item -Path $reportPath -Destination $shaLabel -Force
    }

    $downloaded += [pscustomobject]@{
        Label = $artifactLabel
        Path  = $latestLabel
    }

    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue
}

$canonical = $null
if (-not [string]::IsNullOrWhiteSpace($Label)) {
    $canonical = $downloaded | Where-Object { $_.Label -eq $Label } | Select-Object -First 1
} elseif (-not [string]::IsNullOrWhiteSpace($PreferLabel)) {
    $canonical = $downloaded | Where-Object { $_.Label -eq $PreferLabel } | Select-Object -First 1
}
if (-not $canonical) {
    $canonical = $downloaded | Select-Object -First 1
}

$latestPath = Join-Path $outDirResolved 'pylavi-offenders.latest.json'
Copy-Item -Path $canonical.Path -Destination $latestPath -Force
if (-not [string]::IsNullOrWhiteSpace($runSha)) {
    $shaCanonical = Join-Path $outDirResolved ("pylavi-offenders.{0}.json" -f $runSha)
    Copy-Item -Path $canonical.Path -Destination $shaCanonical -Force
}

Write-Host ("PYLAVI_OFFENDERS_FETCHED=1")
Write-Host ("PYLAVI_OFFENDERS_FILE={0}" -f $latestPath)
Write-Host ("PYLAVI_OFFENDERS_LABEL={0}" -f $canonical.Label)
Write-Host ("PYLAVI_OFFENDERS_RUN_ID={0}" -f $run.id)
if (-not [string]::IsNullOrWhiteSpace($runSha)) {
    Write-Host ("PYLAVI_OFFENDERS_SHA={0}" -f $runSha)
}
Write-Host ("PYLAVI_OFFENDERS_WORKFLOW={0}" -f $Workflow)
Write-Host ("PYLAVI_OFFENDERS_BRANCH={0}" -f $Branch)
