#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$RepoRoot,
  [Parameter(Mandatory)][string]$ConfigPath,
  [int]$LabVIEWVersion = 2023,
  [ValidateSet(32,64)][int]$Bitness = 64,
  [string]$Label,
  [string]$ResultsDir = 'tests/results/_agent/vi-analyzer/deadtime'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try {
    $root = git -C $StartPath rev-parse --show-toplevel 2>$null
    if ($root) { return (Resolve-Path -LiteralPath $root.Trim()).Path }
  } catch {}
  return (Resolve-Path -LiteralPath $StartPath).Path
}

if (-not $RepoRoot) {
  $RepoRoot = Resolve-RepoRoot
} else {
  $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

$configResolved = (Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop).Path
$resultsResolved = if ([System.IO.Path]::IsPathRooted($ResultsDir)) {
  $ResultsDir
} else {
  Join-Path $RepoRoot $ResultsDir
}
if (-not (Test-Path -LiteralPath $resultsResolved -PathType Container)) {
  New-Item -ItemType Directory -Path $resultsResolved -Force | Out-Null
}

if (-not $Label) {
  $Label = "deadtime-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmss')
}

$enableScript = Join-Path $RepoRoot 'tools' 'icon-editor' 'Enable-DevMode.ps1'
$disableScript = Join-Path $RepoRoot 'tools' 'icon-editor' 'Disable-DevMode.ps1'
$closeScript = Join-Path $RepoRoot 'tools' 'Close-LabVIEW.ps1'
$analyzerScript = Join-Path $RepoRoot 'tools' 'icon-editor' 'Invoke-VIAnalyzer.ps1'

foreach ($required in @($enableScript,$disableScript,$closeScript,$analyzerScript)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Required helper '$required' was not found."
  }
}

$scenarios = @(
  [pscustomobject]@{ name = 'dev-disabled'; ensureDevMode = $false },
  [pscustomobject]@{ name = 'dev-enabled'; ensureDevMode = $true }
)

$entries = New-Object System.Collections.Generic.List[object]

foreach ($scenario in $scenarios) {
  Write-Host ("[deadtime] Scenario '{0}' starting..." -f $scenario.name)

  if ($scenario.ensureDevMode) {
    & $enableScript -RepoRoot $RepoRoot -Versions $LabVIEWVersion -Bitness $Bitness -Operation 'MissingInProject' | Out-Null
  } else {
    & $disableScript -RepoRoot $RepoRoot -Versions $LabVIEWVersion -Bitness $Bitness -Operation 'MissingInProject' | Out-Null
  }

  try {
    & $closeScript -MinimumSupportedLVVersion $LabVIEWVersion -SupportedBitness $Bitness | Out-Null
  } catch {
    Write-Warning ("[deadtime] Close-LabVIEW failed: {0}" -f $_.Exception.Message)
  }

  $startTime = Get-Date
  $entry = [ordered]@{
    scenario        = $scenario.name
    ensureDevMode   = $scenario.ensureDevMode
    startAt         = $startTime.ToString('o')
    endAt           = $null
    durationSeconds = $null
    success         = $false
    error           = $null
    analyzer        = $null
  }

  try {
    $result = & $analyzerScript `
      -ConfigPath $configResolved `
      -LabVIEWVersion $LabVIEWVersion `
      -Bitness $Bitness `
      -PassThru
    $entry.analyzer = [ordered]@{
      reportPath     = $result.reportPath
      brokenViCount  = $result.brokenViCount
      versionMismatchCount = if ($result.PSObject.Properties['versionMismatchCount']) { $result.versionMismatchCount } else { 0 }
      labviewVersion = $LabVIEWVersion
      bitness        = $Bitness
    }
    $entry.success = $true
  } catch {
    $entry.error = $_.Exception.Message
  }

  $endTime = Get-Date
  $entry.endAt = $endTime.ToString('o')
  $entry.durationSeconds = [Math]::Round(($endTime - $startTime).TotalSeconds,3)
  $entries.Add([pscustomobject]$entry) | Out-Null
}

$payload = [ordered]@{
  schema     = 'icon-editor/vi-analyzer-deadtime@v1'
  label      = $Label
  configPath = $configResolved
  labviewVersion = $LabVIEWVersion
  bitness    = $Bitness
  generatedAt = (Get-Date).ToString('o')
  entries    = $entries
}

$outputPath = Join-Path $resultsResolved ("deadtime-{0}.json" -f $Label)
$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding utf8

Write-Host ("[deadtime] Results written to {0}" -f $outputPath) -ForegroundColor Cyan

function Test-ValidLabel {
  param([Parameter(Mandatory)][string]$Label)
  if ($Label -notmatch '^[A-Za-z0-9._-]{1,64}$') { throw "Invalid label: $Label" }
}

function Invoke-WithTimeout {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][scriptblock]$ScriptBlock,
    [Parameter()][int]$TimeoutSec = 600
  )
  $job = Start-Job -ScriptBlock $ScriptBlock
  if (-not (Wait-Job $job -Timeout $TimeoutSec)) {
    try { Stop-Job $job -Force } catch {}
    throw "Operation timed out in $TimeoutSec s"
  }
  Receive-Job $job -ErrorAction Stop
}