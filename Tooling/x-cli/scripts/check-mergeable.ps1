#!/usr/bin/env pwsh
param(
  [string]$Owner,
  [string]$Repo,
  [int]$Pr,
  [switch]$FailOnConflict = $true
)
$ErrorActionPreference = 'Stop'

function Get-EnvJson($name, $default) {
  if (Test-Path Env:$name) { return (Get-Item Env:$name).Value }
  return $default
}

if (-not $Owner -or -not $Repo -or -not $Pr) {
  try {
    $evPath = Get-EnvJson 'GITHUB_EVENT_PATH' ''
    if (-not (Test-Path $evPath)) { throw 'GITHUB_EVENT_PATH missing' }
    $ev = Get-Content -Raw $evPath | ConvertFrom-Json
    if (-not $Owner) { $Owner = $ev.repository.owner.login }
    if (-not $Repo)  { $Repo  = $ev.repository.name }
    if (-not $Pr)    { $Pr    = [int]$ev.pull_request.number }
  } catch {
    Write-Error 'Failed to infer Owner/Repo/PR from GITHUB_EVENT_PATH; pass parameters explicitly.'
    exit 3
  }
}

$token = Get-EnvJson 'GITHUB_TOKEN' ''
if (-not $token) {
  Write-Error 'GITHUB_TOKEN is required to query PR mergeability.'
  exit 4
}

$uri = "https://api.github.com/repos/$Owner/$Repo/pulls/$Pr"
try {
  $resp = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json' }
} catch {
  Write-Error "GitHub API error: $($_.Exception.Message)"
  exit 5
}

$mergeable = $resp.mergeable
$state = $resp.mergeable_state
Write-Host "PR #$Pr mergeable=$mergeable, state=$state (base=$($resp.base.ref), head=$($resp.head.ref))"

# Only fail on true conflicts; 'blocked' just means required checks not all green yet
if ($FailOnConflict -and (($mergeable -eq $false) -or ($state -eq 'dirty'))) {
  Write-Error "PR has conflicts (state=$state)."
  exit 2
}
if ($state -eq 'blocked') {
  Write-Host "Note: PR is blocked by required checks, but mergeable once checks pass."
}
exit 0
