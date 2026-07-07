#Requires -Version 7.0
<#
.SYNOPSIS
    Ensures runner-cli.exe is available and exports LVIE_RUNNER_CLI_PATH.

.DESCRIPTION
    Resolves runner-cli.exe from explicit path, environment, runner temp, or repo builds.
    If missing, attempts to build with dotnet publish or download via gh run artifacts.

.PARAMETER RepoRoot
    Repository root (defaults to parent of this script).

.PARAMETER RunnerCliPath
    Explicit path to runner-cli.exe.

.PARAMETER Require
    Fail if runner-cli cannot be resolved/built/downloaded.

.PARAMETER SkipBuild
    Skip dotnet publish.

.PARAMETER SkipDownload
    Skip gh artifact download.

.PARAMETER Repo
    GitHub repo in owner/name format (for gh download).

.PARAMETER Branch
    Git branch to query for build-runner-cli workflow runs.
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$RunnerCliPath,
    [switch]$Require,
    [switch]$SkipBuild,
    [switch]$SkipDownload,
    [string]$Repo,
    [string]$Branch
)

$ErrorActionPreference = 'Stop'
$requireEnabled = $Require.IsPresent -or ($env:LVIE_REQUIRE_RUNNER_CLI -eq '1')
$skipBuildEnabled = $SkipBuild.IsPresent -or ($env:LVIE_RUNNER_CLI_SKIP_BUILD -eq '1')
$skipDownloadEnabled = $SkipDownload.IsPresent -or ($env:LVIE_RUNNER_CLI_SKIP_DOWNLOAD -eq '1')

function Resolve-RepoRoot {
    param([string]$PathOverride)
    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        return (Resolve-Path -Path $PathOverride -ErrorAction Stop).Path
    }
    return (Resolve-Path -Path (Split-Path -Parent $PSScriptRoot) -ErrorAction Stop).Path
}

function Resolve-RunnerCliPath {
    param(
        [string]$ExplicitPath,
        [string]$RepoRootResolved
    )

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $candidates += $ExplicitPath
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_CLI_PATH)) {
        $candidates += $env:LVIE_RUNNER_CLI_PATH
    }
    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
        $candidates += (Join-Path $env:RUNNER_TEMP 'runner-cli\runner-cli.exe')
    }
    if (-not [string]::IsNullOrWhiteSpace($RepoRootResolved)) {
        $candidates += (Join-Path $RepoRootResolved 'Tooling\runner-cli\publish\win-x64\runner-cli.exe')
        $candidates += (Join-Path $RepoRootResolved 'Tooling\runner-cli\RunnerCli\bin\Release\net8.0\win-x64\publish\runner-cli.exe')
        $candidates += (Join-Path $RepoRootResolved 'Tooling\runner-cli\RunnerCli\bin\Release\net8.0\runner-cli.exe')
    }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (Test-Path -Path $candidate) {
            return (Resolve-Path -Path $candidate -ErrorAction Stop).Path
        }
    }

    return $null
}

function Resolve-BranchName {
    param(
        [string]$RepoRootResolved,
        [string]$BranchOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($BranchOverride)) {
        return $BranchOverride
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REF_NAME)) {
        return $env:GITHUB_REF_NAME
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GIT_BRANCH)) {
        return $env:GIT_BRANCH
    }
    try {
        $branch = & git -C $RepoRootResolved rev-parse --abbrev-ref HEAD 2>$null
        if (-not [string]::IsNullOrWhiteSpace($branch)) {
            return $branch.Trim()
        }
    } catch {
        return $null
    }
    return $null
}

function Publish-RunnerCli {
    param([string]$RepoRootResolved)

    $toolingDir = Join-Path $RepoRootResolved 'Tooling\runner-cli'
    $proj = Join-Path $toolingDir 'RunnerCli\RunnerCli.csproj'
    if (-not (Test-Path -Path $proj)) {
        Write-Warning ("runner-cli project not found at {0}" -f $proj)
        return $false
    }

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Warning 'dotnet not found; skipping runner-cli build.'
        return $false
    }

    Write-Host 'Building runner-cli (dotnet publish win-x64)...'
    Push-Location -Path $toolingDir
    try {
        & dotnet publish RunnerCli/RunnerCli.csproj `
            --configuration Release `
            --runtime win-x64 `
            --self-contained true `
            -p:PublishSingleFile=true `
            -p:PublishTrimmed=true `
            --output ./publish/win-x64
        return ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null)
    } finally {
        Pop-Location
    }
}

function Get-RunnerCliArtifact {
    param(
        [string]$RepoValue,
        [string]$BranchValue
    )

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warning 'gh CLI not found; skipping runner-cli download.'
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($RepoValue)) {
        Write-Warning 'GITHUB_REPOSITORY not set; skipping runner-cli download.'
        return $false
    }

    $branch = if ($BranchValue) { $BranchValue } else { $null }
    if ([string]::IsNullOrWhiteSpace($branch)) {
        Write-Warning 'Branch not resolved; skipping runner-cli download.'
        return $false
    }

    $tempRoot = if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { $env:RUNNER_TEMP } else { $env:TEMP }
    $cliDir = Join-Path $tempRoot 'runner-cli'
    $cliPath = Join-Path $cliDir 'runner-cli.exe'
    if (Test-Path $cliPath) {
        Write-Host ("runner-cli already present at {0}" -f $cliPath)
        return $true
    }

    Write-Host ("Downloading runner-cli artifact for {0}@{1}..." -f $RepoValue, $branch)
    try {
        $runs = gh run list -R $RepoValue -w build-runner-cli.yml -b $branch -s success -L 1 --json databaseId | ConvertFrom-Json
    } catch {
        Write-Warning ("Failed to query workflow runs: {0}" -f $_.Exception.Message)
        return $false
    }

    $runId = if ($runs -is [array]) { $runs[0].databaseId } else { $runs.databaseId }
    if (-not $runId) {
        Write-Warning 'No successful build-runner-cli run found; skipping download.'
        return $false
    }

    New-Item -Path $cliDir -ItemType Directory -Force | Out-Null
    try {
        gh run download $runId -R $RepoValue -n runner-cli-win-x64 -D $cliDir | Out-Null
    } catch {
        Write-Warning ("Failed to download runner-cli artifact: {0}" -f $_.Exception.Message)
        return $false
    }

    if (Test-Path $cliPath) {
        Write-Host ("Downloaded runner-cli to {0}" -f $cliPath)
        return $true
    }

    Write-Warning ("runner-cli artifact downloaded but runner-cli.exe not found in {0}" -f $cliDir)
    return $false
}

$repoRootResolved = Resolve-RepoRoot -PathOverride $RepoRoot
$resolvedPath = Resolve-RunnerCliPath -ExplicitPath $RunnerCliPath -RepoRootResolved $repoRootResolved

if (-not $resolvedPath -and -not $skipBuildEnabled) {
    $built = Publish-RunnerCli -RepoRootResolved $repoRootResolved
    if ($built) {
        $resolvedPath = Resolve-RunnerCliPath -ExplicitPath $RunnerCliPath -RepoRootResolved $repoRootResolved
    }
}

if (-not $resolvedPath -and -not $skipDownloadEnabled) {
    $repoValue = if ($Repo) { $Repo } else { $env:GITHUB_REPOSITORY }
    $branchValue = Resolve-BranchName -RepoRootResolved $repoRootResolved -BranchOverride $Branch
    $downloaded = Get-RunnerCliArtifact -RepoValue $repoValue -BranchValue $branchValue
    if ($downloaded) {
        $resolvedPath = Resolve-RunnerCliPath -ExplicitPath $RunnerCliPath -RepoRootResolved $repoRootResolved
    }
}

if ($resolvedPath) {
    $env:LVIE_RUNNER_CLI_PATH = $resolvedPath
    return [pscustomobject]@{
        Path       = $resolvedPath
        RepoRoot   = $repoRootResolved
        Required   = $requireEnabled
        Status     = 'resolved'
    }
}

$message = 'runner-cli.exe not available. Set LVIE_RUNNER_CLI_PATH, install .NET 8 to build, or use gh to download artifacts.'
if ($requireEnabled) {
    throw $message
}

Write-Warning $message
return [pscustomobject]@{
    Path       = $null
    RepoRoot   = $repoRootResolved
    Required   = $requireEnabled
    Status     = 'missing'
}
