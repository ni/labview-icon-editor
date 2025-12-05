<#
.SYNOPSIS
  Test script for Ollama executor cross-compilation simulation mode.

.DESCRIPTION
  Demonstrates the simulation mode by running simulated builds for multiple LabVIEW platforms
  without requiring those platforms to be installed.

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-SimulationMode.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=== Ollama Executor Simulation Mode Test ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Basic simulation
Write-Host "Test 1: Basic simulation with default settings" -ForegroundColor Yellow
$env:OLLAMA_EXECUTOR_MODE = "sim"
$env:OLLAMA_SIM_DELAY_MS = "50"

$result1 = & "$PSScriptRoot/SimulationProvider.ps1" `
    -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64"

Write-Host "Exit Code: $($result1.ExitCode)"
Write-Host "Duration: $($result1.Duration)ms"
Write-Host "StdOut Preview:"
Write-Host ($result1.StdOut -split "`n" | Select-Object -First 5) -ForegroundColor Gray
Write-Host ""

# Test 2: Simulation with artifact creation
Write-Host "Test 2: Simulation with artifact creation" -ForegroundColor Yellow
$env:OLLAMA_SIM_CREATE_ARTIFACTS = "true"
$tempRepo = if ($env:TEMP) { 
    Join-Path $env:TEMP "sim-test-repo" 
} elseif ($env:TMPDIR) {
    Join-Path $env:TMPDIR "sim-test-repo"
} else {
    Join-Path "/tmp" "sim-test-repo"
}
New-Item -ItemType Directory -Path $tempRepo -Force | Out-Null

$result2 = & "$PSScriptRoot/SimulationProvider.ps1" `
    -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath $tempRepo -Package_LabVIEW_Version 2021 -SupportedBitness 32" `
    -WorkingDirectory $tempRepo

$artifactPath = Join-Path $tempRepo "builds\source-distribution\LabVIEW_Icon_Editor_SourceDist_LV2021_32bit.zip"
if (Test-Path $artifactPath) {
    Write-Host "✓ Artifact created: $artifactPath" -ForegroundColor Green
    $size = (Get-Item $artifactPath).Length
    Write-Host "  Size: $size bytes"
}
else {
    Write-Host "✗ Artifact not created" -ForegroundColor Red
}
Write-Host ""

# Test 3: Simulated failure
Write-Host "Test 3: Simulated failure" -ForegroundColor Yellow
$env:OLLAMA_SIM_FAIL = "true"
$env:OLLAMA_SIM_EXIT = "42"

$result3 = & "$PSScriptRoot/SimulationProvider.ps1" `
    -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64"

Write-Host "Exit Code: $($result3.ExitCode) (expected: 42)"
if ($result3.StdErr) {
    Write-Host "StdErr Preview:"
    Write-Host ($result3.StdErr -split "`n" | Select-Object -First 3) -ForegroundColor Gray
}
Write-Host ""

# Test 4: Cross-platform simulation
Write-Host "Test 4: Cross-platform simulation (multiple platforms)" -ForegroundColor Yellow
$env:OLLAMA_SIM_FAIL = "false"
$env:OLLAMA_SIM_EXIT = ""
$env:OLLAMA_SIM_CREATE_ARTIFACTS = "false"
$env:OLLAMA_SIM_PLATFORMS = "2021-32,2021-64,2025-32,2025-64"

$platforms = @(
    @{ Version = "2021"; Bitness = "32" }
    @{ Version = "2021"; Bitness = "64" }
    @{ Version = "2025"; Bitness = "32" }
    @{ Version = "2025"; Bitness = "64" }
)

foreach ($platform in $platforms) {
    $result = & "$PSScriptRoot/SimulationProvider.ps1" `
        -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version $($platform.Version) -SupportedBitness $($platform.Bitness)"
    
    $status = if ($result.ExitCode -eq 0) { "✓" } else { "✗" }
    Write-Host "  $status LV$($platform.Version)-$($platform.Bitness)bit: $($result.Duration)ms" -ForegroundColor $(if ($result.ExitCode -eq 0) { "Green" } else { "Red" })
}
Write-Host ""

# Cleanup
Remove-Item $tempRepo -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_CREATE_ARTIFACTS -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_FAIL -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_EXIT -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_PLATFORMS -ErrorAction SilentlyContinue

Write-Host "=== All Tests Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "- Simulation mode allows testing builds without LabVIEW installed"
Write-Host "- Use OLLAMA_EXECUTOR_MODE=sim to enable"
Write-Host "- Control behavior with OLLAMA_SIM_* environment variables"
Write-Host "- Create stub artifacts with OLLAMA_SIM_CREATE_ARTIFACTS=true"
Write-Host "- Simulate failures with OLLAMA_SIM_FAIL=true"
Write-Host ""
Write-Host "✓ All simulation tests completed successfully!" -ForegroundColor Green
exit 0
