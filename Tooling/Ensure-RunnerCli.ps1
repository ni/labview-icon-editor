#Requires -Version 7.0
<#
.SYNOPSIS
    Ensures runner-cli is available and exports LVIE_RUNNER_CLI_PATH.

.DESCRIPTION
    Resolves runner-cli from explicit path, environment, runner temp, or repo builds.
    If missing, attempts to build with dotnet publish or download via gh run artifacts.

.PARAMETER RepoRoot
    Repository root (defaults to parent of this script).

.PARAMETER RunnerCliPath
    Explicit path to runner-cli.

.PARAMETER Require
    Fail if runner-cli cannot be resolved/built/downloaded.

.PARAMETER SkipBuild
    Skip dotnet publish.

.PARAMETER SkipDownload
    Skip gh artifact download.

.PARAMETER Repo
    GitHub repo in owner/name format (for gh download).

.PARAMETER Branch
    Git branch to query for runner-cli workflow runs.
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
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH."
}
$requireEnabled = $Require.IsPresent -or ($env:LVIE_REQUIRE_RUNNER_CLI -eq '1')
$skipBuildEnabled = $SkipBuild.IsPresent -or ($env:LVIE_RUNNER_CLI_SKIP_BUILD -eq '1')
$skipDownloadEnabled = $SkipDownload.IsPresent -or ($env:LVIE_RUNNER_CLI_SKIP_DOWNLOAD -eq '1')

function Resolve-RepoRoot {
    param([string]$PathOverride)
    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        return (Resolve-Path -Path $PathOverride -ErrorAction Stop).Path
    }
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim() -ErrorAction Stop).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }
    return (Resolve-Path -Path (Split-Path -Parent $scriptRoot) -ErrorAction Stop).Path
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

function Resolve-RepoSlug {
    param(
        [string]$RepoValue,
        [string]$RepoRootResolved
    )

    if (-not [string]::IsNullOrWhiteSpace($RepoValue)) {
        return $RepoValue
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) {
        return $env:GITHUB_REPOSITORY
    }

    try {
        $url = git -C $RepoRootResolved config --get remote.origin.url 2>$null
    } catch {
        $url = $null
    }

    if (-not [string]::IsNullOrWhiteSpace($url)) {
        if ($url -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?$') {
            return "{0}/{1}" -f $Matches['owner'], $Matches['repo']
        }
    }

    return $null
}

function Get-RunnerCliRuntime {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    if ($IsWindows) { return 'win-x64' }
    if ($IsLinux) {
        if ($arch -eq 'Arm64') { return 'linux-arm64' }
        return 'linux-x64'
    }
    if ($IsMacOS) {
        if ($arch -eq 'Arm64') { return 'osx-arm64' }
        return 'osx-x64'
    }
    return 'win-x64'
}

function Get-RunnerCliFileName {
    param([string]$Runtime)
    if ($Runtime -like 'win-*') { return 'runner-cli.exe' }
    return 'runner-cli'
}

function Publish-RunnerCli {
    param(
        [string]$RepoRootResolved,
        [string]$Runtime
    )

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

    Write-Host ("Building runner-cli (dotnet publish {0})..." -f $Runtime)
    Push-Location -Path $toolingDir
    try {
        & dotnet publish RunnerCli/RunnerCli.csproj `
            --configuration Release `
            --runtime $Runtime `
            --self-contained true `
            -p:PublishSingleFile=true `
            -p:PublishTrimmed=true `
            --output ("./publish/{0}" -f $Runtime)
        return ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null)
    } finally {
        Pop-Location
    }
}

function Get-RunnerCliArtifact {
    param(
        [string]$RepoValue,
        [string]$BranchValue,
        [string]$Runtime
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
    $cliFile = Get-RunnerCliFileName -Runtime $Runtime
    $cliPath = Join-Path $cliDir $cliFile
    if (Test-Path $cliPath) {
        Write-Host ("runner-cli already present at {0}" -f $cliPath)
        return $true
    }

    Write-Host ("Downloading runner-cli artifact for {0}@{1}..." -f $RepoValue, $branch)
    try {
        $runs = gh run list -R $RepoValue -w runner-cli.yml -b $branch -s success -L 1 --json databaseId | ConvertFrom-Json
    } catch {
        Write-Warning ("Failed to query workflow runs: {0}" -f $_.Exception.Message)
        return $false
    }

    $runId = if ($runs -is [array]) { $runs[0].databaseId } else { $runs.databaseId }
    if (-not $runId) {
        Write-Warning 'No successful runner-cli workflow run found; skipping download.'
        return $false
    }

    New-Item -Path $cliDir -ItemType Directory -Force | Out-Null
    try {
        gh run download $runId -R $RepoValue -n ("runner-cli-{0}" -f $Runtime) -D $cliDir | Out-Null
    } catch {
        Write-Warning ("Failed to download runner-cli artifact: {0}" -f $_.Exception.Message)
        return $false
    }

    if (Test-Path $cliPath) {
        Write-Host ("Downloaded runner-cli to {0}" -f $cliPath)
        return $true
    }

    Write-Warning ("runner-cli artifact downloaded but {0} not found in {1}" -f $cliFile, $cliDir)
    return $false
}

$repoRootResolved = Resolve-RepoRoot -PathOverride $RepoRoot
$runtime = Get-RunnerCliRuntime
$cliFileName = Get-RunnerCliFileName -Runtime $runtime

function Resolve-RunnerCliPath {
    param(
        [string]$ExplicitPath,
        [string]$RepoRootResolved,
        [string]$Runtime,
        [string]$CliFile
    )

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $candidates += $ExplicitPath
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_CLI_PATH)) {
        $candidates += $env:LVIE_RUNNER_CLI_PATH
    }
    if (-not [string]::IsNullOrWhiteSpace($RepoRootResolved)) {
        $candidates += (Join-Path $RepoRootResolved 'Tooling\runner-cli\publish' $Runtime $CliFile)
        $candidates += (Join-Path $RepoRootResolved 'Tooling\runner-cli\RunnerCli\bin\Release\net8.0' $Runtime 'publish' $CliFile)
        $candidates += (Join-Path $RepoRootResolved 'Tooling\runner-cli\RunnerCli\bin\Release\net8.0' $Runtime $CliFile)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
        $candidates += (Join-Path $env:RUNNER_TEMP 'runner-cli' $CliFile)
    }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (Test-Path -Path $candidate) {
            return (Resolve-Path -Path $candidate -ErrorAction Stop).Path
        }
    }

    return $null
}

$resolvedPath = $null
$buildAttempted = $false
$explicitResolved = $null
$explicitProvided = -not [string]::IsNullOrWhiteSpace($RunnerCliPath)
if ($explicitProvided) {
    try {
        if (Test-Path -Path $RunnerCliPath) {
            $explicitResolved = (Resolve-Path -Path $RunnerCliPath -ErrorAction Stop).Path
        }
    } catch {
        $explicitResolved = $null
    }
    if (-not $explicitResolved -and -not $skipBuildEnabled) {
        $buildAttempted = $true
        $built = Publish-RunnerCli -RepoRootResolved $repoRootResolved -Runtime $runtime
        if ($built -and (Test-Path -Path $RunnerCliPath)) {
            $explicitResolved = (Resolve-Path -Path $RunnerCliPath -ErrorAction SilentlyContinue).Path
        }
    }
    if ($explicitResolved) {
        $resolvedPath = $explicitResolved
    }
}

if (-not $resolvedPath) {
    $resolvedPath = Resolve-RunnerCliPath -ExplicitPath $RunnerCliPath -RepoRootResolved $repoRootResolved -Runtime $runtime -CliFile $cliFileName
}

if (-not $resolvedPath -and -not $skipBuildEnabled -and -not $buildAttempted) {
    $built = Publish-RunnerCli -RepoRootResolved $repoRootResolved -Runtime $runtime
    if ($built) {
        $resolvedPath = Resolve-RunnerCliPath -ExplicitPath $RunnerCliPath -RepoRootResolved $repoRootResolved -Runtime $runtime -CliFile $cliFileName
    }
}

if (-not $resolvedPath -and -not $skipDownloadEnabled) {
    $repoValue = Resolve-RepoSlug -RepoValue $Repo -RepoRootResolved $repoRootResolved
    $branchValue = Resolve-BranchName -RepoRootResolved $repoRootResolved -BranchOverride $Branch
    $downloaded = Get-RunnerCliArtifact -RepoValue $repoValue -BranchValue $branchValue -Runtime $runtime
    if ($downloaded) {
        $resolvedPath = Resolve-RunnerCliPath -ExplicitPath $RunnerCliPath -RepoRootResolved $repoRootResolved -Runtime $runtime -CliFile $cliFileName
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

$message = ("{0} not available. Set LVIE_RUNNER_CLI_PATH, install .NET 8 to build, or use gh to download artifacts." -f $cliFileName)
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
