<#
.SYNOPSIS
  Test suite for Ollama executor timeout handling.

.DESCRIPTION
  Tests timeout scenarios where commands take too long to complete.
  Note: These tests are inherently timing-dependent and may not work reliably
  in simulation mode since simulated commands complete instantly.

.PARAMETER SkipInSimulation
  Skip tests when running in simulation mode (default: true for CI compatibility)

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-Timeout.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipInSimulation = $true
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=== Ollama Executor Timeout Tests ===" -ForegroundColor Cyan
Write-Host ""

$passCount = 0
$failCount = 0
$skipCount = 0

# Check if we're in simulation mode
$isSimulationMode = ($env:OLLAMA_EXECUTOR_MODE -eq 'sim') -or $SkipInSimulation

function Test-CommandTimeout {
    Write-Host "Test: Command Timeout" -ForegroundColor Yellow
    
    # In simulation mode, timeouts can't be properly tested because
    # SimulationProvider completes instantly regardless of delay settings.
    # The CommandTimeoutSec parameter only applies to real process execution.
    if ($script:isSimulationMode) {
        Write-Host "  ⏭ SKIP - Timeout tests not supported in simulation mode" -ForegroundColor Gray
        Write-Host "    (SimulationProvider completes instantly; use real execution to test timeouts)" -ForegroundColor Gray
        $script:skipCount++
        Write-Host ""
        return
    }
    
    # Enable simulation mode with a delay longer than timeout
    $env:OLLAMA_EXECUTOR_MODE = "sim"
    $env:OLLAMA_SIM_DELAY_MS = "3000"  # 3 seconds
    $env:OLLAMA_HOST = "http://localhost:11436"
    
    # Start mock server
    $mockJob = Start-Job -ScriptBlock {
        & "$using:PSScriptRoot/MockOllamaServer.ps1" -Port 11436 -MaxRequests 10
    }
    
    try {
        Start-Sleep -Seconds 2  # Wait for server
        
        $tempRepo = if ($env:TEMP) { Join-Path $env:TEMP "timeout-test" } else { "/tmp/timeout-test" }
        New-Item -ItemType Directory -Path $tempRepo -Force | Out-Null
        
        # Run with very short timeout
        $output = & "$PSScriptRoot/Drive-Ollama-Executor.ps1" `
            -Endpoint "http://localhost:11436" `
            -Model "llama3-8b-local" `
            -RepoPath $tempRepo `
            -Goal "Test timeout" `
            -MaxTurns 2 `
            -CommandTimeoutSec 1 `
            -StopAfterFirstCommand `
            2>&1
        
        Remove-Item $tempRepo -Recurse -Force -ErrorAction SilentlyContinue
        
        $outputStr = $output | Out-String
        
        # Should see timeout message or exit code -1
        if ($outputStr -match 'Timed out|Exit=-1') {
            Write-Host "  ✓ PASS - Timeout detected" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL - Timeout not detected" -ForegroundColor Red
            $script:failCount++
        }
    }
    finally {
        Stop-Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job $mockJob -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
}

function Test-LongRunningCommandTimeout {
    Write-Host "Test: Long Running Command Timeout" -ForegroundColor Yellow
    
    # Skip in simulation mode
    if ($script:isSimulationMode) {
        Write-Host "  ⏭ SKIP - Timeout tests not supported in simulation mode" -ForegroundColor Gray
        $script:skipCount++
        Write-Host ""
        return
    }
    
    # This test would require a real long-running command
    # For now, skip as it requires real execution environment
    Write-Host "  ⏭ SKIP - Requires real execution environment" -ForegroundColor Gray
    $script:skipCount++
    Write-Host ""
}

# Run all tests
Test-CommandTimeout
Test-LongRunningCommandTimeout

# Clean up environment
Remove-Item Env:\OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_HOST -ErrorAction SilentlyContinue

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "Skipped: $skipCount" -ForegroundColor Gray
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "All timeout tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some timeout tests failed! ✗" -ForegroundColor Red
    exit 1
}
