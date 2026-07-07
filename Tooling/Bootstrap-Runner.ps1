#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstraps a LabVIEW runner with contract + labels.

.DESCRIPTION
    Writes the runner contract, updates environment variables, and optionally
    reconfigures the GitHub Actions runner labels/service. Designed to be the
    single entrypoint for new runner hosts.

.PARAMETER RunnerRoot
    Root folder where the runner is installed (e.g. C:\actions-runner).

.PARAMETER WorkRoot
    Runner work root (e.g. C:\actions-runner\_work).

.PARAMETER WorktreeRoot
    Worktree root for LVIE (e.g. C:\actions-runner\_work\lvie\w).

.PARAMETER ArtifactRoot
    Artifact root for LVIE.

.PARAMETER LockRoot
    Lock root for LVIE.

.PARAMETER LogRoot
    Log root for LVIE.

.PARAMETER RunnerLabel
    Primary runner label (e.g. self-hosted-windows-lv).

.PARAMETER RunnerLabels
    Additional labels to assign (e.g. self-hosted-windows-lv-ie).

.PARAMETER CanonicalRunnerLabel
    Canonical label required by CI (default self-hosted-windows-lv).

.PARAMETER Repo
    GitHub repo in owner/name format for registration token lookup.

.PARAMETER RunnerUrl
    Runner registration URL (defaults to https://github.com/<repo>).

.PARAMETER RunnerName
    Runner name (defaults to current runner name or computer name).

.PARAMETER RunnerRegistrationToken
    GitHub Actions registration token (optional; can be pulled via gh).

.PARAMETER RunnerRemoveToken
    GitHub Actions removal token (optional; can be pulled via gh).

.PARAMETER RegisterRunner
    Reconfigure the runner with labels (requires tokens).

.PARAMETER RestartRunnerService
    Restart the runner service after configuration.

.PARAMETER Scope
    Environment variable scope (Machine/User/Process).

.PARAMETER ValidateContract
    Run Tooling/Validate-RunnerContract.ps1 after setup (default true).

.PARAMETER RunnerCliPath
    Optional path to runner-cli.exe for contract validation.

.PARAMETER WriteBootstrapMarker
    Write a bootstrap marker JSON file (default true).

.PARAMETER BootstrapMarkerPath
    Explicit bootstrap marker path. Defaults to <work_root>\lvie\runner-bootstrap.json.
#>

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
    [string]$Repo,
    [string]$RunnerUrl,
    [string]$RunnerName,
    [string]$RunnerRegistrationToken,
    [string]$RunnerRemoveToken,
    [switch]$RegisterRunner,
    [switch]$RestartRunnerService,
    [ValidateSet('Machine', 'User', 'Process')]
    [string]$Scope = 'Machine',
    [switch]$ValidateContract,
    [string]$RunnerCliPath,
    [switch]$WriteBootstrapMarker,
    [string]$BootstrapMarkerPath
)

$ErrorActionPreference = 'Stop'
$validateContractEnabled = $ValidateContract.IsPresent -or -not $PSBoundParameters.ContainsKey('ValidateContract')
$writeBootstrapEnabled = $WriteBootstrapMarker.IsPresent -or -not $PSBoundParameters.ContainsKey('WriteBootstrapMarker')

function Resolve-NormalizedPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -gt 3 -and $full.EndsWith('\')) {
        $full = $full.TrimEnd('\')
    }
    return $full
}

function Resolve-RunnerRoot {
    param([string]$RunnerRootValue, [string]$WorkRootValue)

    if (-not [string]::IsNullOrWhiteSpace($RunnerRootValue)) {
        return (Resolve-NormalizedPath -Path $RunnerRootValue)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_ROOT)) {
        return (Resolve-NormalizedPath -Path $env:LVIE_RUNNER_ROOT)
    }

    if (-not [string]::IsNullOrWhiteSpace($WorkRootValue)) {
        return (Resolve-NormalizedPath -Path (Split-Path -Parent $WorkRootValue))
    }

    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_WORKSPACE)) {
        return (Resolve-NormalizedPath -Path (Split-Path -Parent $env:RUNNER_WORKSPACE))
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
        try {
            $repoRoot = (Resolve-Path -Path $env:GITHUB_WORKSPACE -ErrorAction Stop).Path
            return (Resolve-NormalizedPath -Path (Split-Path -Parent (Split-Path -Parent $repoRoot)))
        } catch {
            Write-Verbose ("Bootstrap: unable to resolve GITHUB_WORKSPACE '{0}'." -f $env:GITHUB_WORKSPACE)
        }
    }

    return $null
}

function Resolve-RepoFromRunner {
    param([string]$RunnerRootValue)
    if ([string]::IsNullOrWhiteSpace($RunnerRootValue)) {
        return $null
    }

    $runnerFile = Join-Path $RunnerRootValue '.runner'
    if (-not (Test-Path -Path $runnerFile)) {
        return $null
    }

    try {
        $content = Get-Content -Raw -Path $runnerFile | ConvertFrom-Json
        $url = $content.gitHubUrl
        if ([string]::IsNullOrWhiteSpace($url)) { return $null }
        $uri = [System.Uri]::new($url)
        $path = $uri.AbsolutePath.Trim('/')
        if ($path -match '.+/.+') { return $path }
    } catch {
        Write-Verbose ("Bootstrap: failed to parse {0}: {1}" -f $runnerFile, $_.Exception.Message)
    }

    return $null
}

function Resolve-RunnerUrl {
    param([string]$RepoValue, [string]$RunnerUrlValue)

    if (-not [string]::IsNullOrWhiteSpace($RunnerUrlValue)) {
        return $RunnerUrlValue
    }

    if (-not [string]::IsNullOrWhiteSpace($RepoValue)) {
        if ($RepoValue.StartsWith('http', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $RepoValue
        }
        return ("https://github.com/{0}" -f $RepoValue.Trim())
    }

    return $null
}

function Resolve-RunnerName {
    param([string]$RunnerRootValue, [string]$RunnerNameValue)

    if (-not [string]::IsNullOrWhiteSpace($RunnerNameValue)) {
        return $RunnerNameValue
    }

    if (-not [string]::IsNullOrWhiteSpace($RunnerRootValue)) {
        $runnerFile = Join-Path $RunnerRootValue '.runner'
        if (Test-Path -Path $runnerFile) {
            try {
                $content = Get-Content -Raw -Path $runnerFile | ConvertFrom-Json
                if ($content.agentName) { return $content.agentName }
            } catch {
                Write-Verbose ("Bootstrap: failed to parse {0}: {1}" -f $runnerFile, $_.Exception.Message)
            }
        }
    }

    if ($env:COMPUTERNAME) { return $env:COMPUTERNAME }
    return 'runner'
}

function Resolve-RunnerLabelSet {
    param(
        [string]$PrimaryLabel,
        [string[]]$ExtraLabels,
        [string]$CanonicalLabel
    )

    $labels = @()
    if ($ExtraLabels) { $labels += $ExtraLabels }
    if (-not [string]::IsNullOrWhiteSpace($PrimaryLabel)) { $labels += $PrimaryLabel }
    if (-not [string]::IsNullOrWhiteSpace($CanonicalLabel)) { $labels += $CanonicalLabel }
    return $labels | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique
}

function Invoke-GhToken {
    param([string]$RepoValue, [string]$ApiPath)
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($RepoValue)) {
        return $null
    }

    try {
        $token = gh api --method POST "/repos/$RepoValue/$ApiPath" -q .token
        if (-not [string]::IsNullOrWhiteSpace($token)) {
            return $token.Trim()
        }
    } catch {
        Write-Warning ("Bootstrap: failed to fetch token via gh: {0}" -f $_.Exception.Message)
    }
    return $null
}

function Resolve-RunnerServiceName {
    param([string]$RunnerRootValue)
    if ([string]::IsNullOrWhiteSpace($RunnerRootValue)) {
        return $null
    }
    $serviceFile = Join-Path $RunnerRootValue '.service'
    if (Test-Path -Path $serviceFile) {
        try {
            $serviceName = (Get-Content -Raw -Path $serviceFile).Trim()
            if ($serviceName) { return $serviceName }
        } catch {
            Write-Verbose ("Bootstrap: failed to read {0}: {1}" -f $serviceFile, $_.Exception.Message)
        }
    }
    return $null
}

function Resolve-RunnerCliPath {
    param([string]$ExplicitPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return $ExplicitPath
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_CLI_PATH)) {
        return $env:LVIE_RUNNER_CLI_PATH
    }

    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
        $candidate = Join-Path $env:RUNNER_TEMP 'runner-cli\runner-cli.exe'
        if (Test-Path -Path $candidate) {
            return $candidate
        }
    }

    return $null
}

$contractHelper = Join-Path $PSScriptRoot 'support\RunnerContract.ps1'
if (-not (Test-Path -Path $contractHelper)) {
    throw "RunnerContract.ps1 not found at $contractHelper"
}
. $contractHelper

$runnerRootResolved = Resolve-RunnerRoot -RunnerRootValue $RunnerRoot -WorkRootValue $WorkRoot
$workRootResolved = Resolve-RunnerWorkRoot -RunnerRoot $runnerRootResolved -WorkRoot $WorkRoot
if ([string]::IsNullOrWhiteSpace($workRootResolved)) {
    throw "Runner work root could not be resolved. Provide -RunnerRoot or -WorkRoot."
}
$runnerRootResolved = if ($runnerRootResolved) { $runnerRootResolved } else { Split-Path -Parent $workRootResolved }

$repoResolved = if ($Repo) { $Repo } else { $env:GITHUB_REPOSITORY }
if ([string]::IsNullOrWhiteSpace($repoResolved)) {
    $repoResolved = Resolve-RepoFromRunner -RunnerRootValue $runnerRootResolved
}

$runnerUrlResolved = Resolve-RunnerUrl -RepoValue $repoResolved -RunnerUrlValue $RunnerUrl
$runnerNameResolved = Resolve-RunnerName -RunnerRootValue $runnerRootResolved -RunnerNameValue $RunnerName

$canonicalLabelResolved = if ([string]::IsNullOrWhiteSpace($CanonicalRunnerLabel)) { 'self-hosted-windows-lv' } else { $CanonicalRunnerLabel.Trim() }
$primaryLabelResolved = if (-not [string]::IsNullOrWhiteSpace($RunnerLabel)) { $RunnerLabel.Trim() } elseif (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_LABEL)) { $env:LVIE_RUNNER_LABEL.Trim() } else { $canonicalLabelResolved }
$labelsResolved = Resolve-RunnerLabelSet -PrimaryLabel $primaryLabelResolved -ExtraLabels $RunnerLabels -CanonicalLabel $canonicalLabelResolved

$setupArgs = @{}
if ($runnerRootResolved) { $setupArgs.RunnerRoot = $runnerRootResolved }
if ($workRootResolved) { $setupArgs.WorkRoot = $workRootResolved }
if ($WorktreeRoot) { $setupArgs.WorktreeRoot = $WorktreeRoot }
if ($ArtifactRoot) { $setupArgs.ArtifactRoot = $ArtifactRoot }
if ($LockRoot) { $setupArgs.LockRoot = $LockRoot }
if ($LogRoot) { $setupArgs.LogRoot = $LogRoot }
$setupArgs.RunnerLabel = $primaryLabelResolved
$setupArgs.RunnerLabels = $labelsResolved
$setupArgs.CanonicalRunnerLabel = $canonicalLabelResolved
$setupArgs.Scope = $Scope

& (Join-Path $PSScriptRoot 'Setup-Runner.ps1') @setupArgs

if ($RegisterRunner) {
    if ([string]::IsNullOrWhiteSpace($runnerRootResolved)) {
        throw 'RunnerRoot is required to register the runner.'
    }

    $configCmd = Join-Path $runnerRootResolved 'config.cmd'
    if (-not (Test-Path -Path $configCmd)) {
        throw "config.cmd not found at $configCmd"
    }

    if ([string]::IsNullOrWhiteSpace($runnerUrlResolved)) {
        throw 'RunnerUrl could not be resolved. Provide -RunnerUrl or -Repo.'
    }

    if ([string]::IsNullOrWhiteSpace($RunnerRegistrationToken)) {
        $RunnerRegistrationToken = Invoke-GhToken -RepoValue $repoResolved -ApiPath 'actions/runners/registration-token'
    }
    if ([string]::IsNullOrWhiteSpace($RunnerRegistrationToken)) {
        throw 'Runner registration token not provided. Pass -RunnerRegistrationToken or authenticate gh.'
    }

    if ([string]::IsNullOrWhiteSpace($RunnerRemoveToken)) {
        $RunnerRemoveToken = Invoke-GhToken -RepoValue $repoResolved -ApiPath 'actions/runners/remove-token'
    }
    if ([string]::IsNullOrWhiteSpace($RunnerRemoveToken)) {
        Write-Warning 'Runner removal token not provided; attempting to reconfigure without removal.'
    }

    $serviceName = Resolve-RunnerServiceName -RunnerRootValue $runnerRootResolved
    if ($serviceName) {
        try {
            Stop-Service -Name $serviceName -ErrorAction Stop
            Write-Host ("Stopped runner service: {0}" -f $serviceName)
        } catch {
            Write-Warning ("Failed to stop runner service '{0}': {1}" -f $serviceName, $_.Exception.Message)
        }
    }

    if ($RunnerRemoveToken) {
        try {
            & $configCmd remove --token $RunnerRemoveToken
        } catch {
            Write-Warning ("Runner removal failed: {0}" -f $_.Exception.Message)
        }
    }

    $labelCsv = ($labelsResolved -join ',')
    & $configCmd --unattended --url $runnerUrlResolved --token $RunnerRegistrationToken --name $runnerNameResolved --labels $labelCsv --runasservice

    if ($RestartRunnerService -and $serviceName) {
        try {
            Start-Service -Name $serviceName -ErrorAction Stop
            Write-Host ("Started runner service: {0}" -f $serviceName)
        } catch {
            Write-Warning ("Failed to start runner service '{0}': {1}" -f $serviceName, $_.Exception.Message)
        }
    }
} elseif ($RestartRunnerService) {
    $serviceName = Resolve-RunnerServiceName -RunnerRootValue $runnerRootResolved
    if ($serviceName) {
        try {
            Restart-Service -Name $serviceName -ErrorAction Stop
            Write-Host ("Restarted runner service: {0}" -f $serviceName)
        } catch {
            Write-Warning ("Failed to restart runner service '{0}': {1}" -f $serviceName, $_.Exception.Message)
        }
    } else {
        Write-Warning 'Runner service name not found; skip restart.'
    }
}

if ($validateContractEnabled) {
    $contractPath = Resolve-RunnerContractPath -RunnerRoot $runnerRootResolved -WorkRoot $workRootResolved
    $cliPath = Resolve-RunnerCliPath -ExplicitPath $RunnerCliPath
    if ($cliPath -and (Test-Path -Path $cliPath) -and $contractPath) {
        Write-Host ("Validating contract with runner-cli: {0}" -f $cliPath)
        & $cliPath validate-contract --contract-path $contractPath
    }
    & (Join-Path $PSScriptRoot 'Validate-RunnerContract.ps1') -FailOnMissingSafeDirectory
}

if ($writeBootstrapEnabled) {
    $markerPath = if ($BootstrapMarkerPath) {
        $BootstrapMarkerPath
    } else {
        Join-Path $workRootResolved 'lvie\runner-bootstrap.json'
    }

    $markerDir = Split-Path -Parent $markerPath
    if (-not (Test-Path -Path $markerDir)) {
        New-Item -Path $markerDir -ItemType Directory -Force | Out-Null
    }

    $marker = [pscustomobject]@{
        version                = 1
        runner_root            = $runnerRootResolved
        work_root              = $workRootResolved
        worktree_root          = $WorktreeRoot
        artifact_root          = $ArtifactRoot
        lock_root              = $LockRoot
        log_root               = $LogRoot
        runner_label           = $primaryLabelResolved
        runner_labels          = $labelsResolved
        canonical_runner_label = $canonicalLabelResolved
        repo                   = $repoResolved
        runner_name            = $runnerNameResolved
        timestamp_utc          = (Get-Date).ToUniversalTime().ToString('o')
    }

    $marker | ConvertTo-Json -Depth 6 | Set-Content -Path $markerPath -Encoding ascii
    Write-Host ("Runner bootstrap marker written: {0}" -f $markerPath)
}

Write-Host 'Runner bootstrap complete.'
