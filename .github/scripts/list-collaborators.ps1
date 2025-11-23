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
while ($true) {
    $uri = "https://api.github.com/repos/$owner/$name/collaborators?per_page=100&page=$page"
    $resp = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    if ($resp) {
        $all += @($resp)
    }
    if (-not $resp -or @($resp).Count -lt 100) { break }
    $page++
}

if (-not $all) {
    Write-Warning "No collaborators returned for $Repo."
    exit 0
}

$rows = foreach ($c in $all) {
    [pscustomobject]@{
        Login      = $c.login
        Name       = $c.name
        Permission = Get-PermissionLabel $c.permissions
        Type       = $c.type
    }
}

$summary = @()
$summary += "### Repository collaborators"
$summary += ""
$summary += "| Login | Name | Permission | Type |"
$summary += "| --- | --- | --- | --- |"
foreach ($r in $rows | Sort-Object -Property Permission, Login) {
    $summary += ("| `{0}` | {1} | `{2}` | `{3}` |" -f $r.Login, ($r.Name ?? ''), $r.Permission, ($r.Type ?? ''))
}
$summary += ""
$summaryText = $summary -join "`n"

if ($env:GITHUB_STEP_SUMMARY) {
    $summaryText | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
}

Write-Host $summaryText
