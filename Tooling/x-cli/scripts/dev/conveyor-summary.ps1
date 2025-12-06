#!/usr/bin/env pwsh
[CmdletBinding()]
param(
  [string] $Multi,
  [string] $Monitor,
  [int] $Count = 10,
  [string] $Out,
  [string] $JsonOut,
  [ValidateSet('local','utc','relative')]
  [string] $TimeFmt = 'local'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-Defaults([string] $m, [string] $d, [string] $o) {
  $artDir = Join-Path $PSScriptRoot '../../artifacts'
  if (-not $m) { $m = Join-Path $artDir 'multi-repo-run.history.jsonl' }
  if (-not $d) { $d = Join-Path $artDir 'monitor-delegate.history.jsonl' }
  if (-not $o) { $o = Join-Path $artDir 'conveyor-summary.md' }
  return ,@([System.IO.Path]::GetFullPath($m), [System.IO.Path]::GetFullPath($d), [System.IO.Path]::GetFullPath($o))
}

$paths = Resolve-Defaults $Multi $Monitor $Out
$multi = $paths[0]
$monitor = $paths[1]
$outPath = $paths[2]
if (-not $JsonOut) { $JsonOut = Join-Path (Split-Path -Parent $outPath) 'conveyor-summary.json' }

$py = 'python'
if (-not (Get-Command $py -ErrorAction SilentlyContinue)) { throw 'python not found on PATH' }

# Make 'relative' the default for local (non-CI) runs when not explicitly set
if (-not $PSBoundParameters.ContainsKey('TimeFmt')) {
  $isCI = $false
  if ($env:GITHUB_ACTIONS -and $env:GITHUB_ACTIONS.ToString().ToLower() -eq 'true') { $isCI = $true }
  elseif ($env:CI -and $env:CI.ToString().Trim()) { $isCI = $true }
  if ($isCI) { $TimeFmt = 'utc' } else { $TimeFmt = 'relative' }
}

& $py 'scripts/dev/conveyor_summary.py' --multi $multi --monitor $monitor --count "$Count" --timefmt $TimeFmt --out $outPath

# Also emit consolidated JSON alongside the markdown
try {
  $jsonText = & $py 'scripts/dev/conveyor_summary.py' --multi $multi --monitor $monitor --count "$Count" --timefmt $TimeFmt --json
  $jsonDir = Split-Path -Parent $JsonOut
  if ($jsonDir -and -not (Test-Path -LiteralPath $jsonDir)) { New-Item -ItemType Directory -Force -Path $jsonDir | Out-Null }
  $jsonText | Out-File -FilePath $JsonOut -Encoding utf8
} catch { }
