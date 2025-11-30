#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Monitor a GitHub Pull Request until merged (with optional auto-merge).

.PARAMETER Pr
  PR number (required).

.PARAMETER IntervalSec
  Poll interval in seconds (default: 20).

.PARAMETER TimeoutMinutes
  Maximum minutes to wait before exiting non-zero (default: 30).

.PARAMETER AutoMerge
  If set, enables squash auto-merge for the PR.

.EXAMPLE
  pwsh ./scripts/ci/watch-pr.ps1 -Pr 756 -AutoMerge -IntervalSec 20 -TimeoutMinutes 30
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][int]$Pr,
  [int]$IntervalSec = 20,
  [int]$TimeoutMinutes = 30,
  [switch]$AutoMerge
)

$ErrorActionPreference = 'Stop'

function Get-PrStatus([int]$n) {
  try {
    $json = gh pr view $n --json state,mergeStateStatus,headRefName,baseRefName,url,title | ConvertFrom-Json
  } catch {
    return $null
  }
  return $json
}

function Show-Checks([int]$n) {
  try {
    $out = gh pr checks $n 2>$null
    if ($out) { Write-Host ($out.Trim()) }
  } catch {}
}

Write-Host "Watching PR #$Pr" -ForegroundColor Cyan
if ($AutoMerge) {
  try {
    gh pr merge $Pr --squash --auto | Out-Null
    Write-Host "Auto-merge enabled (squash) for PR #$Pr" -ForegroundColor Green
  } catch {
    Write-Host "Note: auto-merge enable failed (may already be enabled or lacks permission)." -ForegroundColor Yellow
  }
}

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ((Get-Date) -lt $deadline) {
  $s = Get-PrStatus -n $Pr
  if (-not $s) {
    Write-Host "Unable to read PR status; retrying..." -ForegroundColor Yellow
    Start-Sleep -Seconds $IntervalSec
    continue
  }
  $stamp = (Get-Date).ToString('HH:mm:ss')
  Write-Host ("[{0}] {1} -> {2} | state={3} merge={4}" -f $stamp, $s.headRefName, $s.baseRefName, $s.state, $s.mergeStateStatus)
  if ($s.state -eq 'MERGED') {
    Write-Host "PR #$Pr merged: $($s.url)" -ForegroundColor Green
    exit 0
  }
  Show-Checks -n $Pr
  Start-Sleep -Seconds $IntervalSec
}

Write-Host "Timeout waiting for PR #$Pr to merge." -ForegroundColor Red
exit 1

