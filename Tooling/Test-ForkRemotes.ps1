#Requires -Version 7.0
<##
.SYNOPSIS
    Checks local git remotes for fork vs upstream configuration.

.DESCRIPTION
    Warns when origin points to upstream and a fork is expected. Suggests
    commands to set origin to a fork and add upstream if missing.

.PARAMETER RepoRoot
    Repository root (defaults to git root or script location).

.PARAMETER OriginRemote
    Remote name to treat as the fork (default: origin).

.PARAMETER UpstreamRemote
    Remote name to treat as upstream (default: upstream).

.PARAMETER UpstreamOwner
    Expected upstream owner (default: ni).

.PARAMETER UpstreamRepo
    Expected upstream repo name (default: labview-icon-editor).

.PARAMETER Quiet
    Suppress warnings and suggestions.

.PARAMETER SkipConnectivityCheck
    Skip non-interactive connectivity checks against origin/upstream.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$OriginRemote = 'origin',

    [Parameter(Mandatory = $false)]
    [string]$UpstreamRemote = 'upstream',

    [Parameter(Mandatory = $false)]
    [string]$UpstreamOwner = 'ni',

    [Parameter(Mandatory = $false)]
    [string]$UpstreamRepo = 'labview-icon-editor',

    [switch]$Quiet,

    [switch]$SkipConnectivityCheck
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found on PATH."
}
$skipConnectivity = $SkipConnectivityCheck.IsPresent -or ($env:LVIE_SKIP_REMOTE_CONNECTIVITY_CHECK -eq '1')

function Resolve-RepoRoot {
    param([string]$BasePath)

    if (-not [string]::IsNullOrWhiteSpace($BasePath)) {
        return (Resolve-Path -Path $BasePath -ErrorAction Stop).Path
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

function Get-RemoteUrl {
    param(
        [string]$RepoRootResolved,
        [string]$RemoteName
    )

    if ([string]::IsNullOrWhiteSpace($RemoteName)) {
        return $null
    }

    try {
        $url = git -C $RepoRootResolved config --get ("remote.{0}.url" -f $RemoteName) 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
        return $url.Trim()
    } catch {
        return $null
    }
}

function Resolve-GitHubSlug {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $null
    }

    if ($Url -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?$') {
        return "{0}/{1}" -f $Matches['owner'], $Matches['repo']
    }

    return $null
}

function Invoke-RemoteCheck {
    param(
        [string]$RepoRootResolved,
        [string]$RemoteName,
        [string]$RemoteUrl
    )

    if ([string]::IsNullOrWhiteSpace($RemoteName) -or [string]::IsNullOrWhiteSpace($RemoteUrl)) {
        return [pscustomobject]@{
            Remote = $RemoteName
            Ok = $false
            Error = 'remote-not-configured'
        }
    }

    $previousPrompt = $env:GIT_TERMINAL_PROMPT
    $previousGcm = $env:GCM_INTERACTIVE
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GCM_INTERACTIVE = 'Never'
    try {
        $output = & git -C $RepoRootResolved ls-remote $RemoteName 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        if ($null -eq $previousPrompt) { Remove-Item Env:\GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue } else { $env:GIT_TERMINAL_PROMPT = $previousPrompt }
        if ($null -eq $previousGcm) { Remove-Item Env:\GCM_INTERACTIVE -ErrorAction SilentlyContinue } else { $env:GCM_INTERACTIVE = $previousGcm }
    }

    if ($exitCode -eq 0) {
        return [pscustomobject]@{
            Remote = $RemoteName
            Ok = $true
            Error = $null
        }
    }

    $errorText = [string]::Join(' ', $output)
    return [pscustomobject]@{
        Remote = $RemoteName
        Ok = $false
        Error = $errorText.Trim()
    }
}

$repoRootResolved = Resolve-RepoRoot -BasePath $RepoRoot
$originUrl = Get-RemoteUrl -RepoRootResolved $repoRootResolved -RemoteName $OriginRemote
$upstreamUrl = Get-RemoteUrl -RepoRootResolved $repoRootResolved -RemoteName $UpstreamRemote

$originSlug = Resolve-GitHubSlug -Url $originUrl
$upstreamSlug = Resolve-GitHubSlug -Url $upstreamUrl
$expectedUpstream = "{0}/{1}" -f $UpstreamOwner, $UpstreamRepo

$originIsUpstream = (-not [string]::IsNullOrWhiteSpace($originSlug)) -and ($originSlug -eq $expectedUpstream)
$upstreamIsUpstream = (-not [string]::IsNullOrWhiteSpace($upstreamSlug)) -and ($upstreamSlug -eq $expectedUpstream)
$upstreamMissing = [string]::IsNullOrWhiteSpace($upstreamSlug)
$originMissing = [string]::IsNullOrWhiteSpace($originSlug)

$originConnectivity = $null
$upstreamConnectivity = $null
if (-not $skipConnectivity) {
    $originConnectivity = Invoke-RemoteCheck -RepoRootResolved $repoRootResolved -RemoteName $OriginRemote -RemoteUrl $originUrl
    $upstreamConnectivity = Invoke-RemoteCheck -RepoRootResolved $repoRootResolved -RemoteName $UpstreamRemote -RemoteUrl $upstreamUrl
}

if (-not $Quiet) {
    if ($originMissing -and -not [string]::IsNullOrWhiteSpace($originUrl)) {
        Write-Warning ("Remote '{0}' URL is not a GitHub URL: {1}" -f $OriginRemote, $originUrl)
    }

    if ($originIsUpstream -and ($upstreamMissing -or $upstreamIsUpstream)) {
        Write-Warning ("Remote '{0}' points to upstream ({1}). Set origin to your fork to fetch/push your fork." -f $OriginRemote, $expectedUpstream)
        Write-Host 'Suggested setup:'
        Write-Host ("  git remote set-url {0} https://github.com/<your-user>/{1}.git" -f $OriginRemote, $UpstreamRepo)
        if ($upstreamMissing) {
            Write-Host ("  git remote add {0} https://github.com/{1}/{2}.git" -f $UpstreamRemote, $UpstreamOwner, $UpstreamRepo)
        }
        Write-Host '  git remote -v'
    } elseif ($upstreamMissing -and -not $originMissing) {
        Write-Warning ("Remote '{0}' is not configured. Add upstream to track {1}." -f $UpstreamRemote, $expectedUpstream)
        Write-Host ("Suggested: git remote add {0} https://github.com/{1}/{2}.git" -f $UpstreamRemote, $UpstreamOwner, $UpstreamRepo)
    }

    if ($originConnectivity -and -not $originConnectivity.Ok) {
        Write-Warning ("Remote '{0}' is configured but not reachable (non-interactive): {1}" -f $OriginRemote, $originConnectivity.Error)
        if ($originConnectivity.Error -match 'Permission denied \(publickey\)') {
            Write-Host 'Suggested: add your SSH key to GitHub or switch origin to HTTPS.'
        } elseif ($originConnectivity.Error -match 'Authentication failed|could not read Username|fatal: Authentication') {
            Write-Host 'Suggested: run `gh auth login` or refresh your Git credential manager token.'
        } elseif ($originConnectivity.Error -match 'Repository not found') {
            Write-Host 'Suggested: confirm the fork exists and that the origin URL is correct.'
        }
    }

    if ($upstreamConnectivity -and -not $upstreamConnectivity.Ok) {
        Write-Warning ("Remote '{0}' is configured but not reachable (non-interactive): {1}" -f $UpstreamRemote, $upstreamConnectivity.Error)
        if ($upstreamConnectivity.Error -match 'Permission denied \(publickey\)') {
            Write-Host 'Suggested: add your SSH key to GitHub or switch upstream to HTTPS.'
        } elseif ($upstreamConnectivity.Error -match 'Authentication failed|could not read Username|fatal: Authentication') {
            Write-Host 'Suggested: run `gh auth login` or refresh your Git credential manager token.'
        }
    }
}

return [pscustomobject]@{
    RepoRoot         = $repoRootResolved
    OriginRemote     = $OriginRemote
    UpstreamRemote   = $UpstreamRemote
    OriginUrl        = $originUrl
    UpstreamUrl      = $upstreamUrl
    OriginSlug       = $originSlug
    UpstreamSlug     = $upstreamSlug
    ExpectedUpstream = $expectedUpstream
    OriginIsUpstream = $originIsUpstream
    UpstreamMissing  = $upstreamMissing
    OriginFetchOk    = if ($originConnectivity) { $originConnectivity.Ok } else { $null }
    UpstreamFetchOk  = if ($upstreamConnectivity) { $upstreamConnectivity.Ok } else { $null }
    OriginFetchError = if ($originConnectivity) { $originConnectivity.Error } else { $null }
    UpstreamFetchError = if ($upstreamConnectivity) { $upstreamConnectivity.Error } else { $null }
}
