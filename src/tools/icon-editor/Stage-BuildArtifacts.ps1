#Requires -Version 7.0

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ResultsRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ResultsRoot -PathType Container)) {
  throw "Results root '$ResultsRoot' does not exist or is not a directory."
}

$resolvedRoot = (Resolve-Path -LiteralPath $ResultsRoot).Path

function New-Bucket {
  param([string]$Root, [string]$Name)
  $bucketPath = Join-Path $Root $Name
  if (-not (Test-Path -LiteralPath $bucketPath -PathType Container)) {
    New-Item -ItemType Directory -Path $bucketPath -Force | Out-Null
  }
  return (Resolve-Path -LiteralPath $bucketPath).Path
}

$buckets = [ordered]@{
  packages = New-Bucket -Root $resolvedRoot -Name 'packages'
  reports  = New-Bucket -Root $resolvedRoot -Name 'reports'
  logs     = New-Bucket -Root $resolvedRoot -Name 'logs'
}

function Move-FileToBucket {
  param(
    [System.IO.FileInfo]$Item,
    [string]$DestinationDirectory
  )
  $destination = Join-Path $DestinationDirectory $Item.Name
  Move-Item -LiteralPath $Item.FullName -Destination $destination -Force
  return (Resolve-Path -LiteralPath $destination).Path
}

function Copy-FileToBucket {
  param(
    [System.IO.FileInfo]$Item,
    [string]$DestinationDirectory
  )
  $destination = Join-Path $DestinationDirectory $Item.Name
  Copy-Item -LiteralPath $Item.FullName -Destination $destination -Force
  return (Resolve-Path -LiteralPath $destination).Path
}

$preserveFiles = @('fixture-report.json','fixture-report.md')

# Stage files located directly under the results root.
Get-ChildItem -LiteralPath $resolvedRoot -File | ForEach-Object {
  $nameLower = $_.Name.ToLowerInvariant()
  $extension = $_.Extension.ToLowerInvariant()

  if ($preserveFiles -contains $nameLower) {
    Copy-FileToBucket -Item $_ -DestinationDirectory $buckets.reports | Out-Null
    return
  }

  switch ($extension) {
    '.vip' { Move-FileToBucket -Item $_ -DestinationDirectory $buckets.packages | Out-Null }
    '.lvlibp' { Move-FileToBucket -Item $_ -DestinationDirectory $buckets.packages | Out-Null }
    '.json' { Move-FileToBucket -Item $_ -DestinationDirectory $buckets.reports | Out-Null }
    '.md' { Move-FileToBucket -Item $_ -DestinationDirectory $buckets.reports | Out-Null }
    default { Move-FileToBucket -Item $_ -DestinationDirectory $buckets.logs | Out-Null }
  }
}

function Get-FileCount {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    return 0
  }
  return (Get-ChildItem -LiteralPath $Path -File -Recurse | Measure-Object).Count
}

$summary = [ordered]@{
  root    = $resolvedRoot
  buckets = [ordered]@{
    packages = [ordered]@{
      path  = $buckets.packages
      glob  = ('{0}\**' -f $buckets.packages)
      count = Get-FileCount -Path $buckets.packages
    }
    reports = [ordered]@{
      path  = $buckets.reports
      glob  = ('{0}\**' -f $buckets.reports)
      count = Get-FileCount -Path $buckets.reports
    }
    logs = [ordered]@{
      path  = $buckets.logs
      glob  = ('{0}\**' -f $buckets.logs)
      count = Get-FileCount -Path $buckets.logs
    }
  }
}

$summary | ConvertTo-Json -Depth 5

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