<#
.SYNOPSIS
Downloads, configures, and installs the self-hosted Windows runner service for this repo.
DESCRIPTION
The script obtains a registration token from GitHub, fetches
the latest Windows runner release, configures it with the requested labels, and installs the
service so it can start automatically.
PARAMETER Repo
The owner/repository that the runner should register against (owner/name).
PARAMETER Token
A PAT/GitHub App installation token with admin:repo scope.
If omitted, the script uses $env:GITHUB_PAT or $env:GH_PAT.
PARAMETER RunnerName
Friendly name for the runner service. Defaults to 'self-hosted-windows-lv'.
PARAMETER Labels
Comma-separated labels to expose; defaults to common self-hosted/windows tags plus the runner name.
PARAMETER RunnerDir
Directory where the runner package will be unpacked.
PARAMETER WorkDirectory
Subdirectory used for _work.
PARAMETER RunnerVersion
The runner release tag to install (default 'latest').
PARAMETER RunnerGroup
Runner group name (default 'Default').
PARAMETER ApiEndpoint
GitHub API base URL (useful for GH Enterprise).
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $Repo,

    [string]
    $Token,

    [string]
    $RunnerName = 'self-hosted-windows-lv',

    [string[]]
    $Labels = @('self-hosted', 'windows', 'self-hosted-windows-lv'),

    [string]
    $RunnerDir = (Join-Path $PSScriptRoot 'runner'),

    [string]
    $WorkDirectory = '_work',

    [string]
    $RunnerVersion = 'latest',

    [string]
    $RunnerGroup = 'Default',

    [bool]
    $InstallService = $true,

    [string]
    $ApiEndpoint = 'https://api.github.com'
)

function Get-EffectiveToken {
    param (
        [string]$ExplicitToken
    )
    if ([string]::IsNullOrWhiteSpace($ExplicitToken)) {
        return $env:GITHUB_PAT ?? $env:GH_PAT
    }
    return $ExplicitToken
}

function Invoke-GitHubApi {
    param (
        [string]$Method,
        [string]$Uri,
        [object]$Body
    )
    $headers = @{
        'User-Agent' = 'labview-icon-editor-runner-setup'
    }
    $effectiveToken = Get-EffectiveToken -ExplicitToken $Token
    if ([string]::IsNullOrWhiteSpace($effectiveToken)) {
        throw 'GitHub personal access token is required. Set Token parameter or GITHUB_PAT/GH_PAT.'
    }
    $headers.Authorization = "token $effectiveToken"
    if ($Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 5) -ContentType 'application/json'
    }
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
}

$runnerDir = Resolve-Path -Path $RunnerDir -ErrorAction SilentlyContinue
if ($null -eq $runnerDir) {
    New-Item -ItemType Directory -Path $RunnerDir -Force | Out-Null
    $runnerDir = Resolve-Path $RunnerDir
}
$runnerDir = $runnerDir.ProviderPath

if (Test-Path $runnerDir) {
    Remove-Item -Path $runnerDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $runnerDir -Force | Out-Null
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$releaseUri = if ($RunnerVersion -eq 'latest') {
    "$ApiEndpoint/repos/actions/runner/releases/latest"
} else {
    "$ApiEndpoint/repos/actions/runner/releases/tags/$RunnerVersion"
}

$release = Invoke-RestMethod -Uri $releaseUri -Headers @{ 'User-Agent' = 'labview-icon-editor-runner-setup' }
$asset = $release.assets | Where-Object { $_.name -match '^actions-runner-win-x64.*\.zip$' } | Sort-Object name -Descending | Select-Object -First 1
if (-not $asset) {
    throw "Unable to locate Windows runner asset in release $($release.tag_name)."
}

$zipPath = Join-Path $runnerDir 'actions-runner.zip'
(Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath).StatusDescription | Out-Null

Expand-Archive -Path $zipPath -DestinationPath $runnerDir

$registrationTokenResp = Invoke-GitHubApi -Method Post -Uri "$ApiEndpoint/repos/$Repo/actions/runners/registration-token"
$registrationToken = $registrationTokenResp.token
if (-not $registrationToken) {
    throw 'Failed to obtain runner registration token.'
}

$configCmd = Join-Path $runnerDir 'config.cmd'
Push-Location $runnerDir
try {
    $labelArg = $Labels -join ','
    & $configCmd `
        --unattended `
        --url "https://github.com/$Repo" `
        --token $registrationToken `
        --name $RunnerName `
        --work $WorkDirectory `
        --labels $labelArg `
        --replace `
        --runnergroup $RunnerGroup | Write-Host

    if ($InstallService) {
        & (Join-Path $runnerDir 'svc.sh') install | Write-Host
        & (Join-Path $runnerDir 'svc.sh') start | Write-Host
    } else {
        Write-Host 'Skipping service install; run run.cmd manually to keep the runner active.'
    }
} finally {
    Pop-Location
}
