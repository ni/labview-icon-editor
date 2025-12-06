#!/usr/bin/env pwsh
param(
  [string]$Version
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

New-Item -ItemType Directory -Force -Path package | Out-Null
dotnet pack src/XCli/XCli.csproj -c Release -o package -p:PackageVersion=$Version
Write-Host "Packed XCli version $Version to .\package"

