<#
Removes the configured self-hosted Windows runner service and deregisters the runner.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $Repo,

    [string]
    $Token,

    [string]
    $RunnerDir = (Join-Path $PSScriptRoot 'runner'),

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
        [string]$Uri
    )
    $headers = @{
        'User-Agent' = 'labview-icon-editor-runner-setup'
    }
    $effectiveToken = Get-EffectiveToken -ExplicitToken $Token
    if ([string]::IsNullOrWhiteSpace($effectiveToken)) {
        throw 'GitHub personal access token is required. Set Token parameter or GITHUB_PAT/GH_PAT.'
    }
    $headers.Authorization = "token $effectiveToken"
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
}

$runnerDir = Resolve-Path -Path $RunnerDir -ErrorAction SilentlyContinue
if (-not $runnerDir) {
    throw "Runner directory '$RunnerDir' does not exist."
}
$runnerDir = $runnerDir.ProviderPath

$svcScript = Join-Path $runnerDir 'svc.sh'
$configCmd = Join-Path $runnerDir 'config.cmd'

if (-not (Test-Path $svcScript)) {
    throw "Runner service helper not found under $runnerDir."
}

try {
    & $svcScript stop | Write-Host
} catch {
    Write-Warning "Service stop failed; it may already be stopped."
}

try {
    & $svcScript uninstall | Write-Host
} catch {
    Write-Warning "Service uninstall failed or service not registered."
}

$removeTokenResp = Invoke-GitHubApi -Method Post -Uri "$ApiEndpoint/repos/$Repo/actions/runners/remove-token"
$removeToken = $removeTokenResp.token
if (-not $removeToken) {
    throw 'Failed to obtain runner removal token.'
}

if (-not (Test-Path $configCmd)) {
    throw "Runner config command is not available under $runnerDir."
}

& $configCmd remove --unattended --token $removeToken | Write-Host

Remove-Item -Path $runnerDir -Recurse -Force
