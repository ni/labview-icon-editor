<#
.SYNOPSIS
  Integration test framework for Ollama executor - runs complete end-to-end scenarios.

.DESCRIPTION
  Combines mock Ollama server, simulation mode, and real file system operations
  to validate complete executor workflows including artifact creation and validation.

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-Integration.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=== Ollama Executor Integration Tests ===" -ForegroundColor Cyan
Write-Host ""

$passCount = 0
$failCount = 0

function Test-EndToEndSuccessfulBuild {
    Write-Host "Integration Test 1: End-to-End Successful Build" -ForegroundColor Yellow
    
    # Setup
    $testDir = if ($env:TEMP) { Join-Path $env:TEMP "integration-e2e-$(New-Guid)" } else { "/tmp/integration-e2e-$(New-Guid)" }
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    
    # Enable simulation with artifact creation
    $env:OLLAMA_EXECUTOR_MODE = "sim"
    $env:OLLAMA_SIM_DELAY_MS = "50"
    $env:OLLAMA_SIM_CREATE_ARTIFACTS = "true"
    $env:OLLAMA_HOST = "http://localhost:11437"
    $env:OLLAMA_MODEL_TAG = "llama3-8b-local"
    
    # Start mock server with successful build scenario
    $scenarioFile = "$PSScriptRoot/test-scenarios/successful-two-turn.json"
    $mockJob = Start-Job -ScriptBlock {
        param($Script, $Port, $Scenario)
        & $Script -Port $Port -ScenarioFile $Scenario -MaxRequests 20
    } -ArgumentList "$PSScriptRoot/MockOllamaServer.ps1", 11437, $scenarioFile
    
    try {
        Start-Sleep -Seconds 2  # Wait for server
        
        # Run executor
        $output = & "$PSScriptRoot/Drive-Ollama-Executor.ps1" `
            -Endpoint "http://localhost:11437" `
            -Model "llama3-8b-local" `
            -RepoPath $testDir `
            -Goal "Build Source Distribution LV2025 64-bit" `
            -MaxTurns 5 `
            -AllowedRuns @() `
            2>&1
        
        $outputStr = $output | Out-String
        
        # Validate: Should complete successfully
        $hasCompleted = $outputStr -match '\[executor\] Done:'
        
        # Validate: Artifact should exist
        $artifactPath = Join-Path $testDir "builds/source-distribution/LabVIEW_Icon_Editor_SourceDist_LV2025_64bit.zip"
        $artifactExists = Test-Path $artifactPath
        
        # Validate: Artifact should be valid ZIP
        $isValidZip = $false
        if ($artifactExists) {
            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $zip = [System.IO.Compression.ZipFile]::OpenRead($artifactPath)
                $isValidZip = $zip.Entries.Count -gt 0
                $zip.Dispose()
            }
            catch {
                $isValidZip = $false
            }
        }
        
        # Check results
        $pass = $hasCompleted -and $artifactExists -and $isValidZip
        
        if ($pass) {
            Write-Host "  ✓ PASS - Build completed, artifact created and valid" -ForegroundColor Green
            Write-Host "    Artifact: $artifactPath" -ForegroundColor Gray
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL" -ForegroundColor Red
            if (-not $hasCompleted) { Write-Host "    - Executor did not complete" -ForegroundColor Red }
            if (-not $artifactExists) { Write-Host "    - Artifact not created" -ForegroundColor Red }
            if (-not $isValidZip) { Write-Host "    - Artifact is not valid ZIP" -ForegroundColor Red }
            $script:failCount++
        }
    }
    finally {
        Stop-Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job $mockJob -Force -ErrorAction SilentlyContinue
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
}

function Test-MultiPlatformBuildWorkflow {
    Write-Host "Integration Test 2: Multi-Platform Build Workflow" -ForegroundColor Yellow
    
    $testDir = if ($env:TEMP) { Join-Path $env:TEMP "integration-multi-$(New-Guid)" } else { "/tmp/integration-multi-$(New-Guid)" }
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    
    $env:OLLAMA_EXECUTOR_MODE = "sim"
    $env:OLLAMA_SIM_DELAY_MS = "20"
    $env:OLLAMA_SIM_CREATE_ARTIFACTS = "true"
    $env:OLLAMA_SIM_PLATFORMS = "2021-32,2021-64,2025-32,2025-64"
    $env:OLLAMA_HOST = "http://localhost:11437"
    
    $scenarioFile = "$PSScriptRoot/test-scenarios/max-turns.json"
    $mockJob = Start-Job -ScriptBlock {
        param($Script, $Port, $Scenario)
        & $Script -Port $Port -ScenarioFile $Scenario -MaxRequests 30
    } -ArgumentList "$PSScriptRoot/MockOllamaServer.ps1", 11437, $scenarioFile
    
    try {
        Start-Sleep -Seconds 2
        
        $output = & "$PSScriptRoot/Drive-Ollama-Executor.ps1" `
            -Endpoint "http://localhost:11437" `
            -Model "llama3-8b-local" `
            -RepoPath $testDir `
            -Goal "Build for all platforms" `
            -MaxTurns 5 `
            -AllowedRuns @() `
            2>&1
        
        $outputStr = $output | Out-String
        
        # Count artifacts created
        $artifactDir = Join-Path $testDir "builds/source-distribution"
        $artifacts = @()
        if (Test-Path $artifactDir) {
            $artifacts = Get-ChildItem "$artifactDir/*.zip"
        }
        
        # Should have created multiple artifacts
        $commandMatches = [regex]::Matches($outputStr, '\[executor\] Exit=0')
        $successfulCommands = $commandMatches.Count
        
        if ($artifacts.Count -ge 3 -and $successfulCommands -ge 3) {
            Write-Host "  ✓ PASS - Multiple platforms built ($($artifacts.Count) artifacts)" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL - Expected multiple artifacts (got $($artifacts.Count), $successfulCommands successful)" -ForegroundColor Red
            $script:failCount++
        }
    }
    finally {
        Stop-Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job $mockJob -Force -ErrorAction SilentlyContinue
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_SIM_PLATFORMS -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
}

function Test-FailureRecoveryWorkflow {
    Write-Host "Integration Test 3: Failure Recovery Workflow" -ForegroundColor Yellow
    
    $testDir = if ($env:TEMP) { Join-Path $env:TEMP "integration-recovery-$(New-Guid)" } else { "/tmp/integration-recovery-$(New-Guid)" }
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null
    
    # First command fails, second succeeds
    $env:OLLAMA_EXECUTOR_MODE = "sim"
    $env:OLLAMA_SIM_DELAY_MS = "20"
    $env:OLLAMA_SIM_CREATE_ARTIFACTS = "true"
    $env:OLLAMA_HOST = "http://localhost:11437"
    
    $scenarioFile = "$PSScriptRoot/test-scenarios/command-vetoing.json"
    $mockJob = Start-Job -ScriptBlock {
        param($Script, $Port, $Scenario)
        & $Script -Port $Port -ScenarioFile $Scenario -MaxRequests 20
    } -ArgumentList "$PSScriptRoot/MockOllamaServer.ps1", 11437, $scenarioFile
    
    try {
        Start-Sleep -Seconds 2
        
        $output = & "$PSScriptRoot/Drive-Ollama-Executor.ps1" `
            -Endpoint "http://localhost:11437" `
            -Model "llama3-8b-local" `
            -RepoPath $testDir `
            -Goal "Build with recovery" `
            -MaxTurns 5 `
            -AllowedRuns @() `
            2>&1
        
        $outputStr = $output | Out-String
        
        # Should have vetoed a command and then succeeded
        $hasVeto = $outputStr -match 'Rejected:'
        $hasSuccess = $outputStr -match '\[executor\] Done:'
        $hasArtifact = Test-Path (Join-Path $testDir "builds/source-distribution/*.zip")
        
        if ($hasVeto -and $hasSuccess -and $hasArtifact) {
            Write-Host "  ✓ PASS - Recovered from vetoed command and completed" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL" -ForegroundColor Red
            if (-not $hasVeto) { Write-Host "    - No veto detected" -ForegroundColor Red }
            if (-not $hasSuccess) { Write-Host "    - Did not complete successfully" -ForegroundColor Red }
            if (-not $hasArtifact) { Write-Host "    - No artifact created" -ForegroundColor Red }
            $script:failCount++
        }
    }
    finally {
        Stop-Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job $mockJob -Force -ErrorAction SilentlyContinue
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
}

# Run all integration tests
Test-EndToEndSuccessfulBuild
Test-MultiPlatformBuildWorkflow
Test-FailureRecoveryWorkflow

# Clean up environment
Remove-Item Env:\OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_CREATE_ARTIFACTS -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_HOST -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_MODEL_TAG -ErrorAction SilentlyContinue

# Summary
Write-Host "=== Integration Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "All integration tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some integration tests failed! ✗" -ForegroundColor Red
    exit 1
}
