#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Workspace = (Get-Location).Path,
    [string]$OutputPath = 'Tooling/deployment/release_notes.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).ProviderPath
$releaseNotesScript = Join-Path $workspaceRoot '.github/actions/generate-release-notes/GenerateReleaseNotes.ps1'
if (-not (Test-Path -LiteralPath $releaseNotesScript -PathType Leaf)) {
    Write-Warning "Release notes script '$releaseNotesScript' not found; skipping generation."
    return
}

$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    [System.IO.Path]::GetFullPath($OutputPath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $OutputPath))
}

$releaseDir = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $releaseDir -PathType Container)) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'pwsh'
$psi.ArgumentList.Add('-NoLogo')
$psi.ArgumentList.Add('-NoProfile')
$psi.ArgumentList.Add('-File')
$psi.ArgumentList.Add($releaseNotesScript)
$psi.ArgumentList.Add('-OutputPath')
$psi.ArgumentList.Add($resolvedOutput)
$psi.WorkingDirectory = $workspaceRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$process = [System.Diagnostics.Process]::Start($psi)
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

if ($stdout) { Write-Host $stdout.TrimEnd() }
if ($stderr) { Write-Host $stderr.TrimEnd() }

if ($process.ExitCode -ne 0) {
    throw "Release notes generation script '$releaseNotesScript' failed with exit code $($process.ExitCode)."
}

Write-Host "Release notes generated at $resolvedOutput"
