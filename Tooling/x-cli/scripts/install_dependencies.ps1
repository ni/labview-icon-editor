[CmdletBinding(PositionalBinding=$false)]
Param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Optional venv activation if present
$venv = Join-Path $root '..' '.venv'
$activate = Join-Path $venv 'Scripts' 'Activate.ps1'
if (Test-Path $activate) {
  . $activate
}

# Ensure Python/pip available
python -V | Out-Null
python -m pip install -U pip | Out-Null

# Install testing/runtime tools only (avoid editable install to prevent console script warnings)
python -m pip install ruamel.yaml pytest pytest-timeout pytest-xdist pytest-cov coverage pre-commit | Out-Null

Write-Host "Dependencies installed (test tooling)."
