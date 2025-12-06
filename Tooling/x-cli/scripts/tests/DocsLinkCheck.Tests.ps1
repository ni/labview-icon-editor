Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Docs link check (via Docker lychee)' {
  It 'runs with zero errors' -Skip:(-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    Push-Location $repoRoot
    try {
      $ps1 = 'scripts/docs-link-check.ps1'
      & pwsh -NoProfile -File $ps1 -UseDocker -Path .
      $LASTEXITCODE | Should -Be 0
    } finally {
      Pop-Location
    }
  }
}

