Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Traceability mapping (PowerShell verifier)' {
  It 'verify-traceability.ps1 returns success for current repo' {
    $ps1 = Join-Path $PSScriptRoot '..' 'verify-traceability.ps1'
    Push-Location (Resolve-Path (Join-Path $PSScriptRoot '..' '..'))
    try {
      & pwsh -NoProfile -File $ps1
      $LASTEXITCODE | Should -Be 0
    } finally {
      Pop-Location
    }
  }
}

