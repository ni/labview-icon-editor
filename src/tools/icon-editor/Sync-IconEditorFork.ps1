#Requires -Version 7.0

param(
  [string]$RemoteName = 'icon-editor',
  [string]$RepoSlug,
  [string]$Branch = 'develop',
  [string]$WorkingPath,
  [switch]$UpdateFixture,
  [switch]$RunValidateLocal,
  [switch]$SkipBootstrap
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

$repoRoot = Resolve-RepoRoot

$remoteUrl = $null
try {
  $remoteUrl = (git -C $repoRoot remote get-url $RemoteName 2>$null)
} catch {
  $remoteUrl = $null
}

if (-not $remoteUrl) {
  if (-not $RepoSlug) {
    throw "Unable to resolve remote '$RemoteName'. Provide -RepoSlug (e.g., 'LabVIEW-Community-CI-CD/labview-icon-editor') or configure the remote."
  }
  $remoteUrl = "https://github.com/$RepoSlug.git"
}

if (-not $remoteUrl) {
  throw "Failed to resolve a clone URL for '$RemoteName' / slug '$RepoSlug'."
}

$syncRoot = Join-Path $repoRoot 'tmp/icon-editor-sync'
if (Test-Path -LiteralPath $syncRoot) {
  Remove-Item -LiteralPath $syncRoot -Recurse -Force
}

Write-Host "==> Cloning $remoteUrl ($Branch) to $syncRoot"
$clone = git -c advice.detachedHead=false clone --depth 1 --branch $Branch --single-branch $remoteUrl $syncRoot 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "git clone failed: $clone"
}

$sourcePath = $syncRoot
$targetPath = $null
if ($WorkingPath) {
  if ($UpdateFixture.IsPresent -or $RunValidateLocal.IsPresent) {
    throw "UpdateFixture/RunValidateLocal are only supported when mirroring into vendor/icon-editor. Omit -WorkingPath or run the helpers manually."
  }
  $targetPath = if ([System.IO.Path]::IsPathRooted($WorkingPath)) {
    $WorkingPath
  } else {
    Join-Path $repoRoot $WorkingPath
  }
  if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
    [void][System.IO.Directory]::CreateDirectory($targetPath)
  }
  $targetPath = (Resolve-Path -LiteralPath $targetPath).Path
} else {
  $targetPath = Join-Path $repoRoot 'vendor/icon-editor'
  if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
    throw "Target path '$targetPath' not found."
  }
}

Write-Host ("==> Synchronizing {0} with {1}:{2}" -f $targetPath, $remoteUrl, $Branch)
# Mirror the source onto the target, excluding the cloned .git directory.
$robocopyArgs = @($sourcePath, $targetPath, '/MIR', '/XD', '.git')
$robocopy = Start-Process -FilePath 'robocopy' -ArgumentList $robocopyArgs -NoNewWindow -PassThru -Wait
if ($robocopy.ExitCode -gt 3) {
  throw "robocopy failed with exit code $($robocopy.ExitCode)."
}

if (Test-Path -LiteralPath $syncRoot) {
  Remove-Item -LiteralPath $syncRoot -Recurse -Force
}

Write-Host '==> Sync complete. Review changes under vendor/icon-editor.'

if ($UpdateFixture.IsPresent) {
  Write-Host '==> Updating fixture report/manifest'
  pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot 'tools/icon-editor/Update-IconEditorFixtureReport.ps1')
}

if ($RunValidateLocal.IsPresent) {
  Write-Host '==> Running local Validate helper'
  $validateArgs = @('-File', (Join-Path $repoRoot 'tools/icon-editor/Invoke-ValidateLocal.ps1'))
  if ($SkipBootstrap.IsPresent) { $validateArgs += '--SkipBootstrap' }
  pwsh -NoLogo -NoProfile @validateArgs
}

Write-Host 'Done.'

return [pscustomobject]@{
  remote     = $remoteUrl
  branch     = $Branch
  mirrorPath = $targetPath
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