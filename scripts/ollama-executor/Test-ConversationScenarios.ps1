<#
.SYNOPSIS
  Test suite for Ollama executor conversation scenarios.

.DESCRIPTION
  Tests multi-turn conversations using predefined scenarios and the mock Ollama server.
  Validates turn management, JSON parsing, error recovery, and conversation flow.

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-ConversationScenarios.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=== Ollama Executor Conversation Scenario Tests ===" -ForegroundColor Cyan
Write-Host ""

$passCount = 0
$failCount = 0
$scenarioDir = "$PSScriptRoot/test-scenarios"

function Test-Scenario {
    param(
        [string]$ScenarioFile,
        [string]$TestName
    )
    
    Write-Host "Testing: $TestName" -ForegroundColor Yellow
    
    # Load scenario
    $scenario = Get-Content $ScenarioFile | ConvertFrom-Json
    Write-Host "  Scenario: $($scenario.name)" -ForegroundColor Gray
    Write-Host "  Description: $($scenario.description)" -ForegroundColor Gray
    
    # Start mock Ollama server in background
    $mockServerScript = "$PSScriptRoot/MockOllamaServer.ps1"
    $mockPort = 11436
    
    $job = Start-Job -ScriptBlock {
        param($Script, $Port, $Scenario)
        & $Script -Port $Port -ScenarioFile $Scenario -MaxRequests 50
    } -ArgumentList $mockServerScript, $mockPort, $ScenarioFile
    
    try {
        # Wait for server to start
        Start-Sleep -Seconds 2
        
        # Set environment for simulation mode
        $env:OLLAMA_EXECUTOR_MODE = "sim"
        $env:OLLAMA_SIM_DELAY_MS = "10"
        $env:OLLAMA_SIM_CREATE_ARTIFACTS = "false"
        $env:OLLAMA_HOST = "http://localhost:$mockPort"
        $env:OLLAMA_MODEL_TAG = "llama3-8b-local"
        
        # Run executor with scenario
        $tempRepo = if ($env:TEMP) { Join-Path $env:TEMP "scenario-test-$(New-Guid)" } else { "/tmp/scenario-test-$(New-Guid)" }
        New-Item -ItemType Directory -Path $tempRepo -Force | Out-Null
        
        $executorScript = "$PSScriptRoot/Drive-Ollama-Executor.ps1"
        $maxTurns = if ($scenario.expectedTurns) { $scenario.expectedTurns + 2 } else { 10 }
        
        # Capture executor output
        $output = & $executorScript `
            -Endpoint "http://localhost:$mockPort" `
            -Model "llama3-8b-local" `
            -RepoPath $tempRepo `
            -Goal $scenario.goal `
            -MaxTurns $maxTurns `
            -AllowedRuns @() `
            -CommandTimeoutSec 5 `
            2>&1
        
        # Clean up temp directory
        Remove-Item $tempRepo -Recurse -Force -ErrorAction SilentlyContinue
        
        # Analyze results
        $outputStr = $output | Out-String
        
        # Count turns
        $turnMatches = [regex]::Matches($outputStr, '\[executor\] Turn \d+:')
        $actualTurns = $turnMatches.Count
        
        # Count commands executed
        $commandMatches = [regex]::Matches($outputStr, '\[executor\] Exit=')
        $actualCommands = $commandMatches.Count
        
        # Count vetoed commands
        $vetoMatches = [regex]::Matches($outputStr, 'Rejected:')
        $actualVetoed = $vetoMatches.Count
        
        # Check for "Done" message
        $hasCompleted = $outputStr -match '\[executor\] Done:'
        
        # Check for max turns message
        $maxTurnsReached = $outputStr -match '\[executor\] Max turns reached'
        
        # Validate expectations
        $pass = $true
        $reasons = @()
        
        if ($scenario.expectedTurns -and $actualTurns -ne $scenario.expectedTurns) {
            $pass = $false
            $reasons += "Expected $($scenario.expectedTurns) turns, got $actualTurns"
        }
        
        if ($scenario.expectedCommandCount -and $actualCommands -ne $scenario.expectedCommandCount) {
            $pass = $false
            $reasons += "Expected $($scenario.expectedCommandCount) commands executed, got $actualCommands"
        }
        
        if ($scenario.PSObject.Properties['expectedVetoedCommands'] -and $actualVetoed -ne $scenario.expectedVetoedCommands) {
            $pass = $false
            $reasons += "Expected $($scenario.expectedVetoedCommands) vetoed commands, got $actualVetoed"
        }
        
        if ($scenario.expectedOutcome -eq "success" -and -not $hasCompleted) {
            $pass = $false
            $reasons += "Expected successful completion, but no 'Done' message found"
        }
        
        if ($scenario.expectedOutcome -eq "max_turns_reached" -and -not $maxTurnsReached) {
            $pass = $false
            $reasons += "Expected max turns reached, but message not found"
        }
        
        # Report result
        if ($pass) {
            Write-Host "  ✓ PASS" -ForegroundColor Green
            Write-Host "    Turns: $actualTurns, Commands: $actualCommands, Vetoed: $actualVetoed" -ForegroundColor Gray
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL" -ForegroundColor Red
            foreach ($reason in $reasons) {
                Write-Host "    - $reason" -ForegroundColor Red
            }
            Write-Host "    Actual: Turns=$actualTurns, Commands=$actualCommands, Vetoed=$actualVetoed" -ForegroundColor Gray
            $script:failCount++
        }
    }
    finally {
        # Stop mock server
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        
        # Clean up environment
        Remove-Item Env:\OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_SIM_CREATE_ARTIFACTS -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
}

# Run all scenario tests
$scenarios = Get-ChildItem "$scenarioDir/*.json"

foreach ($scenarioFile in $scenarios) {
    Test-Scenario -ScenarioFile $scenarioFile.FullName -TestName $scenarioFile.BaseName
}

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Scenarios Tested: $($scenarios.Count)" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "All scenario tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some scenario tests failed! ✗" -ForegroundColor Red
    exit 1
}
