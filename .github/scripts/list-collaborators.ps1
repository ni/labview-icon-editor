<#
.SYNOPSIS
Lists repository collaborators and their permissions, and writes a table to STDOUT (and GITHUB_STEP_SUMMARY if available).

.PARAMETER Repo
Full repo slug (owner/repo).

.PARAMETER Token
GitHub token. If omitted, falls back to GH_TOKEN then GITHUB_TOKEN.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Repo,
    [string]$Token
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $Token) {
    $Token = $env:GH_TOKEN
}
if (-not $Token) {
    $Token = $env:GITHUB_TOKEN
}
if (-not $Token) {
    throw "GitHub token not provided. Use -Token or set GH_TOKEN/GITHUB_TOKEN."
}

if (-not ($Repo -match '^[^/]+/[^/]+$')) {
    throw "Repo must be in 'owner/repo' form. Got '$Repo'."
}

$owner, $name = $Repo -split '/', 2
$headers = @{
    Authorization = "Bearer $Token"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "labview-icon-editor-ci-collaborators"
}

function Get-PermissionLabel {
    param($perm)
    if ($perm.admin) { "admin" }
    elseif ($perm.maintain) { "maintain" }
    elseif ($perm.push) { "write" }
    elseif ($perm.triage) { "triage" }
    elseif ($perm.pull) { "read" }
    else { "unknown" }
}

$page = 1
$all = @()
$perPage = 100
$maxPages = 50 # cap to avoid runaway loops
while ($true) {
    if ($page -gt $maxPages) {
        throw "Aborting: exceeded $maxPages pages while listing collaborators for $Repo."
    }

    $uri = "https://api.github.com/repos/$owner/$name/collaborators?per_page=$perPage&page=$page"
    try {
        $resp = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 30
    }
    catch {
        $msg = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $msg = $_.ErrorDetails.Message
        }
        throw ("GitHub API request failed for {0}: {1}" -f $uri, $msg)
    }

    if ($resp) {
        $all += @($resp)
    }

    $count = @($resp).Count
    if (-not $resp -or $count -lt $perPage) { break }
    $page++
}

if (-not $all) {
    Write-Warning "No collaborators returned for $Repo."
    exit 0
}

$rows = foreach ($c in $all) {
    $nameVal = ''
    $hasName = $c.PSObject.Properties['name']
    if ($hasName) {
        $nameVal = $c.name
    }
    $permVal = $null
    if ($c.PSObject.Properties['permissions']) {
        $permVal = $c.permissions
    }
    $permission = Get-PermissionLabel $permVal

    [pscustomobject]@{
        Login      = $c.login
        Name       = $nameVal
        Permission = $permission
        Type       = $c.type
    }
}

$summary = @()
$summary += "### Users with direct repository permissions (GitHub collaborators)"
$summary += ""
$summary += "| Login | Permission | Type |"
$summary += "| --- | --- | --- |"
foreach ($r in $rows | Sort-Object -Property Permission, Login) {
    $summary += ("| `{0}` | `{1}` | `{2}` |" -f $r.Login, $r.Permission, ($r.Type ?? ''))
}
$summary += ""
$summaryText = $summary -join "`n"

if ($env:GITHUB_STEP_SUMMARY) {
    $summaryText | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}

Write-Host $summaryText
