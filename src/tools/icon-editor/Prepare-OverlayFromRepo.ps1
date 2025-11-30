#Requires -Version 7.0

param(
  [string]$RepoPath,
  [string]$BaseRef,
  [string]$HeadRef = 'HEAD',
  [string]$OverlayRoot,
  [string[]]$IncludePatterns = @('resource/', 'Test/'),
  [string[]]$Extensions = @('.vi', '.ctl', '.lvclass', '.lvlib'),
  [switch]$Force
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
$InformationPreference = 'Continue'

function Resolve-GitPath {
  param([string]$Path)
  if (-not $Path) {
    throw 'RepoPath is required.'
  }
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Repository path '$Path' not found."
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function Invoke-Git {
  param([string[]]$Arguments)
  $psi = New-Object System.Diagnostics.ProcessStartInfo 'git'
  foreach ($arg in $Arguments) { [void]$psi.ArgumentList.Add($arg) }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $proc = [System.Diagnostics.Process]::Start($psi)
  try {
    $stdoutStream = $proc.StandardOutput
    $stderrStream = $proc.StandardError
    $stdout = $stdoutStream.ReadToEnd()
    $stderr = $stderrStream.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
      throw "git $($Arguments -join ' ') failed: $stderr"
    }
    return $stdout
  } finally {
    if ($null -ne $proc) { $proc.Dispose() }
  }
}

function Get-GitBlobBytes {
  param(
    [string]$Repo,
    [string]$Ref,
    [string]$Path
  )
  $psi = New-Object System.Diagnostics.ProcessStartInfo 'git'
  foreach ($arg in @('-C', $Repo, 'show', '--no-textconv', "$Ref`:$Path")) {
    [void]$psi.ArgumentList.Add($arg)
  }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $proc = [System.Diagnostics.Process]::Start($psi)
  $memory = New-Object System.IO.MemoryStream
  try {
    $proc.StandardOutput.BaseStream.CopyTo($memory)
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
      $stderr = $proc.StandardError.ReadToEnd()
      throw "git show ${Ref}:$Path failed: $stderr"
    }
    return $memory.ToArray()
  } finally {
    $memory.Dispose()
    if ($null -ne $proc) { $proc.Dispose() }
  }
}

$repoResolved = Resolve-GitPath -Path $RepoPath
Invoke-Git @('-C', $repoResolved, 'rev-parse', '--verify', $HeadRef) | Out-Null
if ($BaseRef) {
  Invoke-Git @('-C', $repoResolved, 'rev-parse', '--verify', $BaseRef) | Out-Null
} else {
  throw 'BaseRef is required when computing overlays.'
}

if (-not $OverlayRoot) {
  throw 'OverlayRoot must be provided.'
}
$overlayResolved = if ([System.IO.Path]::IsPathRooted($OverlayRoot)) {
  $OverlayRoot
} else {
  Join-Path (Get-Location).Path $OverlayRoot
}

if (Test-Path -LiteralPath $overlayResolved) {
  if (-not $Force.IsPresent) {
    throw "Overlay directory '$overlayResolved' already exists. Pass -Force to overwrite."
  }
  Remove-Item -LiteralPath $overlayResolved -Recurse -Force
}
[void](New-Item -ItemType Directory -Path $overlayResolved -Force)

$diffArgs = @('-C', $repoResolved, 'diff', '--name-only', '--diff-filter=ACMRT', $BaseRef, $HeadRef, '--')
if ($IncludePatterns.Count -gt 0) {
  $diffArgs += $IncludePatterns
}
$diffOutput = Invoke-Git -Arguments $diffArgs
$changedPaths = @($diffOutput -split "`n" | Where-Object { $_ -and ($_ -match '\S') })
Write-Information ("Changed path count: {0}" -f $changedPaths.Count)

$extensionsSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($ext in $Extensions) {
  if ($ext) { [void]$extensionsSet.Add(($ext.StartsWith('.') ? $ext : ".$ext")) }
}

$copied = @()
foreach ($path in $changedPaths) {
  $trimmedPath = $path.Trim()
  if (-not $trimmedPath) { continue }
  $ext = [System.IO.Path]::GetExtension($trimmedPath)
  if (-not $extensionsSet.Contains($ext)) {
    continue
  }
  try {
    $headBytes = Get-GitBlobBytes -Repo $repoResolved -Ref $HeadRef -Path $trimmedPath
  } catch {
    Write-Information "Skipping $trimmedPath (missing in head): $($_.Exception.Message)"
    continue
  }
  $isDifferent = $true
  try {
    $baseBytes = Get-GitBlobBytes -Repo $repoResolved -Ref $BaseRef -Path $trimmedPath
    if ($baseBytes.Length -eq $headBytes.Length) {
      $equal = $true
      for ($i = 0; $i -lt $headBytes.Length; $i++) {
        if ($headBytes[$i] -ne $baseBytes[$i]) {
          $equal = $false
          break
        }
      }
      if ($equal) {
        $isDifferent = $false
      }
    }
  } catch {
    # File might be new; treat as different.
    $isDifferent = $true
  }
  if (-not $isDifferent) {
    continue
  }
  $destPath = Join-Path $overlayResolved ($trimmedPath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  $destDir = Split-Path -Parent $destPath
  if (-not (Test-Path -LiteralPath $destDir -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $destDir -Force)
  }
  [System.IO.File]::WriteAllBytes($destPath, $headBytes)
  $copied += $trimmedPath
}

Write-Information ("Overlay populated with {0} file(s)." -f $copied.Count)

[pscustomobject]@{
  overlayRoot = $overlayResolved
  repo        = $repoResolved
  baseRef     = $BaseRef
  headRef     = $HeadRef
  files       = $copied
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