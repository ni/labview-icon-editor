#!/usr/bin/env pwsh
param(
  [string]$Tag = 'x-cli:dev',
  [string]$Version,
  [string]$Target = 'package-image'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath | Join-Path -ChildPath '..' | Resolve-Path
Set-Location $root

if (-not $Version) {
  try {
    $sha = git rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $sha) { $Version = "dev-$sha" } else { $Version = '0.0.0' }
  } catch { $Version = '0.0.0' }
}

./scripts/pack-cli.ps1 -Version $Version | Out-Host

Write-Host "Building image $Tag (target=$Target, XCLI_VERSION=$Version)"
docker build --target $Target --build-arg XCLI_VERSION=$Version -t $Tag .
Write-Host "Built $Tag"

