#!/usr/bin/env pwsh
[CmdletBinding(SupportsShouldProcess=$true, PositionalBinding=$false)]
Param(
  [switch]$RestoreArtifacts,
  [switch]$Hard,
  [string[]]$ExtraPaths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Remove-PathSafe {
  Param([Parameter(Mandatory=$true)][string]$Path)
  if (Test-Path -LiteralPath $Path) {
    try {
      if ($PSCmdlet.ShouldProcess($Path, 'Remove-Item')) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
      }
    } catch {
      Write-Warning "Failed to remove: $Path ($($_.Exception.Message))"
    }
  }
}

$repoRoot = Split-Path -Parent $PSCommandPath | Join-Path -ChildPath '..' | Resolve-Path
Set-Location $repoRoot

Write-Host "Cleaning temp artifacts under $repoRoot" -ForegroundColor Cyan

# Common temp locations
$paths = @(
  '.pytest_tmp',
  '.pytest_cache',
  'dist',
  'out',
  'artifacts/release',
  'temp_hist',
  'temp_telemetry'
)
if ($ExtraPaths) { $paths += $ExtraPaths }

foreach ($p in $paths) { Remove-PathSafe -Path $p }

# Python __pycache__ folders
Get-ChildItem -Recurse -Directory -Filter '__pycache__' -ErrorAction SilentlyContinue | ForEach-Object {
  Remove-PathSafe -Path $_.FullName
}

# Logs under artifacts/logs
Get-ChildItem 'artifacts/logs' -File -ErrorAction SilentlyContinue | ForEach-Object {
  Remove-PathSafe -Path $_.FullName
}

if ($RestoreArtifacts -or $Hard) {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host 'Restoring tracked QA artifacts to baseline via git restore' -ForegroundColor Yellow
    $restore = @(
      'artifacts/qa-telemetry.jsonl',
      'artifacts/logs/test-python.log',
      'telemetry/summary.json',
      'telemetry/qa-summary-history.jsonl'
    )
    foreach ($r in $restore) {
      try { git restore -- $r 2>$null } catch {}
    }
    if ($Hard) {
      Write-Host 'Hard reset: restoring all tracked files and cleaning untracked (except some dev dirs)' -ForegroundColor Red
      try { git restore -- . } catch {}
      try { git clean -xdf -e .vscode/ -e .secrets/ } catch {}
    }
  } else {
    Write-Warning 'git not found; skipping artifact restore/reset.'
  }
}

Write-Host 'Done.' -ForegroundColor Green

