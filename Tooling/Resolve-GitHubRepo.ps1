#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$RemoteName = 'origin',

    [switch]$SetGhDefault
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRootPath {
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

    return (Resolve-Path -Path (Join-Path $scriptRoot '..') -ErrorAction Stop).Path
}

function ConvertTo-OwnerRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $trimmed = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        throw ("Repository value from {0} was empty." -f $Source)
    }

    $ownerRepoPattern = '^(?<owner>[A-Za-z0-9_.-]+)/(?<name>[A-Za-z0-9_.-]+)$'
    if ($trimmed -match $ownerRepoPattern) {
        return ("{0}/{1}" -f $Matches.owner, $Matches.name)
    }

    $urlPattern = '^(?:https://|ssh://git@|git@)github\.com[:/](?<owner>[A-Za-z0-9_.-]+)/(?<name>[A-Za-z0-9_.-]+?)(?:\.git)?/?$'
    if ($trimmed -match $urlPattern) {
        return ("{0}/{1}" -f $Matches.owner, $Matches.name)
    }

    throw ("Repository value from {0} was not in owner/name or GitHub URL format: {1}" -f $Source, $trimmed)
}

function Resolve-RepositoryName {
    param(
        [string]$RepoOverride,
        [string]$RootPath,
        [string]$Remote
    )

    if (-not [string]::IsNullOrWhiteSpace($RepoOverride)) {
        return ConvertTo-OwnerRepo -Value $RepoOverride -Source '-Repo'
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GH_REPO)) {
        return ConvertTo-OwnerRepo -Value $env:GH_REPO -Source 'GH_REPO'
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        throw "git is required to resolve repository from the '$Remote' remote."
    }

    $remoteUrl = git -C $RootPath remote get-url $Remote 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteUrl)) {
        throw ("Failed to resolve git remote URL for '{0}' in '{1}'." -f $Remote, $RootPath)
    }

    return ConvertTo-OwnerRepo -Value $remoteUrl.Trim() -Source ("git remote '{0}'" -f $Remote)
}

$resolvedRoot = Resolve-RepoRootPath -PathOverride $RepoRoot
$resolvedRepo = Resolve-RepositoryName -RepoOverride $Repo -RootPath $resolvedRoot -Remote $RemoteName

if ($SetGhDefault) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw "gh CLI is required for -SetGhDefault."
    }

    & gh repo set-default $resolvedRepo | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw ("Failed to set gh default repository to '{0}'." -f $resolvedRepo)
    }
}

Write-Output $resolvedRepo
