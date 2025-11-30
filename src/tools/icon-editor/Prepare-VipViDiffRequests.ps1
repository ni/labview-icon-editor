#Requires -Version 7.0

param(
  [Parameter(Mandatory)][string]$ExtractRoot,
  [string]$RepoRoot,
  [string]$SourceRoot = 'vendor/icon-editor',
  [string]$OutputDir,
  [string]$RequestsPath,
  [string]$Category = 'vip'
)

Set-StrictMode -Version Latest
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
param(
  [Parameter()][ValidateSet('2021','2023','2025')][string]$LabVIEWVersion = '2023',
  [Parameter()][ValidateSet(32,64)][int]$Bitness = 64,
  [Parameter()][ValidateNotNullOrEmpty()][string]$Workspace = (Get-Location).Path,
  [Parameter()][int]$TimeoutSec = 600
)
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  try { return (git -C $StartPath rev-parse --show-toplevel 2>$null).Trim() } catch { return $StartPath }
}

if (-not (Test-Path -LiteralPath $ExtractRoot -PathType Container)) {
  throw "Extract root '$ExtractRoot' not found."
}

$repoRootResolved = if ($RepoRoot) { (Resolve-Path -LiteralPath $RepoRoot).Path } else { Resolve-RepoRoot }
$sourceRootPath = Join-Path $repoRootResolved $SourceRoot
if (-not (Test-Path -LiteralPath $sourceRootPath -PathType Container)) {
  throw "Icon editor source root '$sourceRootPath' not found."
}

if (-not $OutputDir) {
  $OutputDir = Join-Path $ExtractRoot '..' 'vip-vi-diff'
}
$outputDirResolved = (Resolve-Path -LiteralPath (New-Item -ItemType Directory -Path $OutputDir -Force)).Path
$headRoot = (Resolve-Path -LiteralPath (New-Item -ItemType Directory -Path (Join-Path $outputDirResolved 'head') -Force)).Path

$requestsPathEffective = if ($RequestsPath) { $RequestsPath } else { Join-Path $outputDirResolved 'vi-diff-requests.json' }
$requestsDir = Split-Path -Parent $requestsPathEffective
if ($requestsDir) { [void](New-Item -ItemType Directory -Path $requestsDir -Force) }

function Get-RelativeIconEditorPath {
  param([string]$FullPath, [string]$RootPath)
  $relative = [System.IO.Path]::GetRelativePath($RootPath, $FullPath)
  return $relative
}

function Normalize-RelativePath {
  param([string]$Value)
  if (-not $Value) { return $null }
  return ($Value -replace '[\\/]+', '/')
}

$requests = @()

$extractResolved = (Resolve-Path -LiteralPath $ExtractRoot).Path
$viFiles = Get-ChildItem -LiteralPath $extractResolved -Recurse -Filter '*.vi' -File
foreach ($vi in $viFiles) {
  $relFromExtract = [System.IO.Path]::GetRelativePath($extractResolved, $vi.FullName)
  $marker = 'National Instruments\LabVIEW Icon Editor\'
  $index = $relFromExtract.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)
  if ($index -lt 0) {
    continue
  }
  $relativeTail = $relFromExtract.Substring($index + $marker.Length)
  if ([string]::IsNullOrWhiteSpace($relativeTail)) {
    continue
  }

  $basePath = Join-Path $sourceRootPath $relativeTail
  $baseExists = Test-Path -LiteralPath $basePath -PathType Leaf

  $headDest = Join-Path $headRoot $relativeTail
  $headDir = Split-Path -Parent $headDest
  if (-not (Test-Path -LiteralPath $headDir -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $headDir -Force)
  }
  Copy-Item -LiteralPath $vi.FullName -Destination $headDest -Force

  $requests += [ordered]@{
    name     = $vi.Name
    relPath  = Normalize-RelativePath $relativeTail
    category = $Category
    base     = if ($baseExists) { (Resolve-Path -LiteralPath $basePath).Path } else { $null }
    head     = (Resolve-Path -LiteralPath $headDest).Path
  }
}

$summary = [ordered]@{
  schema      = 'icon-editor/vi-diff-requests@v1'
  generatedAt = (Get-Date).ToString('o')
  count       = $requests.Count
  requests    = $requests
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $requestsPathEffective -Encoding utf8

return [pscustomobject]@{
  schema        = $summary.schema
  generatedAt   = $summary.generatedAt
  count         = $requests.Count
  requestsPath  = (Resolve-Path -LiteralPath $requestsPathEffective).Path
  headRoot      = $headRoot
  sourceRoot    = $sourceRootPath
}


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