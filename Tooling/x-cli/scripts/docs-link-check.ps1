#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Run Markdown link + anchor checks using lychee.

.DESCRIPTION
  Prefers a native `lychee` executable if available on PATH; otherwise wraps
  the official Docker image. Uses repository `.lychee.toml` by default.

.PARAMETER Path
  Scan path (default: '.')

.PARAMETER Config
  Path to lychee TOML config (default: '.lychee.toml')

.PARAMETER UseDocker
  Force using Docker even if native lychee is installed.

.EXAMPLE
  pwsh ./scripts/docs-link-check.ps1

.EXAMPLE
  pwsh ./scripts/docs-link-check.ps1 -Path docs

#>

[CmdletBinding()]
param(
  [string]$Path = '.',
  [string]$Config = '.lychee.toml',
  [switch]$UseDocker
)

$ErrorActionPreference = 'Stop'

$argsList = @()
if ($Config) { $argsList += @('--config', $Config) }
$argsList += @('--no-progress', '--offline', '--include-fragments')
$argsList += $Path

$hasLychee = $false
try { $hasLychee = [bool](Get-Command lychee -ErrorAction SilentlyContinue) } catch { $hasLychee = $false }

if (-not $UseDocker -and $hasLychee) {
  Write-Host "Running native lychee..." -ForegroundColor Cyan
  & lychee @argsList
  exit $LASTEXITCODE
}

$repo = (Get-Location).Path
Write-Host "Running lychee via Docker..." -ForegroundColor Cyan
docker run --rm -v "${repo}:/data" -w /data lycheeverse/lychee:latest @argsList
exit $LASTEXITCODE

