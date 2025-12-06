#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Continuous integration loop: scan open PRs to base and request auto-merge
  for those labeled for auto integration.

.PARAMETER Base
  Base branch to target (default: develop)

.PARAMETER Label
  PR label that opts a PR into auto integration (default: 'ci:autointegrate')

.PARAMETER DryRun
  Print actions without performing merges.

.EXAMPLE
  pwsh ./scripts/ci/integration-loop.ps1 -Base develop -Label 'ci:autointegrate'
#>
[CmdletBinding()]
param(
  [string]$Base = 'develop',
  [string]$Label = 'ci:autointegrate',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Get-OpenPrs([string]$base) {
  $raw = gh pr list -B $base -s open --json number,title,url,headRefName,mergeStateStatus,isDraft,labels 2>$null
  if (-not $raw) { return @() }
  ($raw | ConvertFrom-Json) | ForEach-Object {
    $labels = @()
    foreach ($l in ($_.labels | ForEach-Object { $_.name })) { $labels += $l }
    [pscustomobject]@{
      number = $_.number
      title  = $_.title
      url    = $_.url
      head   = $_.headRefName
      merge  = $_.mergeStateStatus
      draft  = $_.isDraft
      labels = $labels
    }
  }
}

function Wants-Auto([object]$pr,[string]$label) {
  return ($pr.labels -contains $label) -and (-not $pr.draft)
}

$prs = Get-OpenPrs -base $Base | Where-Object { Wants-Auto $_ $Label }
if (-not $prs) {
  Write-Host "No open PRs with label '$Label' targeting '$Base'." -ForegroundColor Yellow
  exit 0
}

foreach ($pr in $prs) {
  Write-Host ("PR #{0}: {1} ({2}) merge={3}" -f $pr.number, $pr.title, $pr.head, $pr.merge)
  if ($DryRun) { continue }
  try {
    gh pr merge $pr.number --auto --squash | Out-Null
    Write-Host ("  -> requested auto-merge (squash)") -ForegroundColor Green
  } catch {
    Write-Host ("  -> merge request failed (not ready?): {0}" -f $_.Exception.Message) -ForegroundColor Yellow
  }
}

exit 0


