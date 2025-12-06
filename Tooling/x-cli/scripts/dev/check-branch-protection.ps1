$ErrorActionPreference = 'Stop'
$repo = 'LabVIEW-Community-CI-CD/x-cli'
$root = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
$pesterScript = Join-Path $root 'scripts/tests/BranchProtection.Tests.ps1'

Write-Host "[branch-protection] Running tests..." -ForegroundColor Cyan
try {
    $pesterArgs = @{ Script = $pesterScript; Output = 'Detailed' }
    Invoke-Pester @pesterArgs
} catch {
    throw
}

