<#
.SYNOPSIS
  Test suite for Ollama executor failure handling.

.DESCRIPTION
  Tests error scenarios including network failures, command execution failures,
  and behavior flags like StopAfterFirstCommand.
  
  Follows a Sequential Process Model similar to TestStand:
  - Setup: Initialize resources
  - Main: Execute tests sequentially  
  - Cleanup: Release all resources
  
  Each test follows Setup -> Execute -> Cleanup pattern.

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-Failures.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#region === SEQUENCE CONFIGURATION ===

$script:TestConfig = @{
    MockServerPort = 11436
    ScriptDirectory = $PSScriptRoot
    CurrentMockJob = $null
    TestResults = @()
    PassCount = 0
    FailCount = 0
    SequenceState = 'NotStarted'  # NotStarted, Setup, Running, Cleanup, Complete
}

#endregion

#region === SEQUENCE INFRASTRUCTURE ===

function Write-SequenceLog {
    param(
        [string]$Message,
        [string]$Level = 'Info'  # Info, Warning, Error, Debug
    )
    
    $timestamp = Get-Date -Format 'HH:mm:ss.fff'
    $color = switch ($Level) {
        'Info' { 'White' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Debug' { 'Gray' }
        'Success' { 'Green' }
        default { 'White' }
    }
    
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Set-SequenceState {
    param([string]$State)
    $script:TestConfig.SequenceState = $State
    Write-SequenceLog "Sequence state: $State" -Level Debug
}

function Wait-ForPortRelease {
    param(
        [int]$Port,
        [int]$TimeoutSeconds = 10
    )
    
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    
    while ((Get-Date) -lt $deadline) {
        try {
            $null = Invoke-RestMethod -Uri "http://localhost:$Port/api/tags" -TimeoutSec 1 -ErrorAction Stop
            # Server still responding, wait
            Start-Sleep -Milliseconds 200
        }
        catch {
            # Connection failed = port is free
            return $true
        }
    }
    
    return $false
}

function Wait-ForServerReady {
    param(
        [int]$Port,
        [int]$TimeoutSeconds = 10
    )
    
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    
    while ((Get-Date) -lt $deadline) {
        try {
            $null = Invoke-RestMethod -Uri "http://localhost:$Port/api/tags" -TimeoutSec 1 -ErrorAction Stop
            return $true
        }
        catch {
            Start-Sleep -Milliseconds 200
        }
    }
    
    return $false
}

#endregion

#region === RESOURCE MANAGEMENT ===

function Initialize-MockServer {
    <#
    .SYNOPSIS
      Starts mock server and waits for it to be ready.
      Part of test Setup phase.
    #>
    param([int]$MaxRequests = 10)
    
    # Ensure clean state first
    $null = Terminate-MockServer
    
    $scriptDir = $script:TestConfig.ScriptDirectory
    $port = $script:TestConfig.MockServerPort
    
    Write-SequenceLog "  [Setup] Starting mock server on port $port" -Level Debug
    
    $script:TestConfig.CurrentMockJob = Start-Job -ScriptBlock {
        param($portNum, $scriptPath, $maxReq)
        & "$scriptPath/MockOllamaServer.ps1" -Port $portNum -MaxRequests $maxReq
    } -ArgumentList $port, $scriptDir, $MaxRequests
    
    # Wait for ready
    if (Wait-ForServerReady -Port $port -TimeoutSeconds 10) {
        Write-SequenceLog "  [Setup] Mock server ready" -Level Debug
        return $true
    }
    else {
        Write-SequenceLog "  [Setup] Mock server failed to start" -Level Warning
        return $false
    }
}

function Terminate-MockServer {
    <#
    .SYNOPSIS
      Stops mock server and releases port.
      Part of test Cleanup phase.
    #>
    
    $port = $script:TestConfig.MockServerPort
    
    if ($script:TestConfig.CurrentMockJob) {
        Write-SequenceLog "  [Cleanup] Stopping mock server" -Level Debug
        
        Stop-Job $script:TestConfig.CurrentMockJob -ErrorAction SilentlyContinue
        $null = Wait-Job $script:TestConfig.CurrentMockJob -Timeout 3 -ErrorAction SilentlyContinue
        Remove-Job $script:TestConfig.CurrentMockJob -Force -ErrorAction SilentlyContinue
        $script:TestConfig.CurrentMockJob = $null
    }
    
    # Wait for port release
    if (-not (Wait-ForPortRelease -Port $port -TimeoutSeconds 5)) {
        Write-SequenceLog "  [Cleanup] Warning: Port $port may still be in use" -Level Warning
    }
    
    # Extra stabilization delay
    Start-Sleep -Milliseconds 300
    
    return $true
}

function Clear-TestEnvironment {
    <#
    .SYNOPSIS
      Clears all test-related environment variables.
    #>
    
    $envVars = @(
        'OLLAMA_EXECUTOR_MODE',
        'OLLAMA_SIM_FAIL',
        'OLLAMA_SIM_EXIT', 
        'OLLAMA_SIM_DELAY_MS',
        'OLLAMA_HOST'
    )
    
    foreach ($var in $envVars) {
        Remove-Item "Env:\$var" -ErrorAction SilentlyContinue
    }
}

#endregion

#region === TEST STEP DEFINITIONS ===

function Invoke-TestStep {
    <#
    .SYNOPSIS
      Executes a single test following Setup -> Execute -> Cleanup pattern.
    #>
    param(
        [string]$TestName,
        [scriptblock]$Setup,
        [scriptblock]$Execute,
        [scriptblock]$Cleanup
    )
    
    Write-Host ""
    Write-SequenceLog "TEST: $TestName" -Level Info
    Write-Host ("-" * 50) -ForegroundColor Gray
    
    $result = @{
        Name = $TestName
        Status = 'NotRun'
        StartTime = Get-Date
        EndTime = $null
        Error = $null
    }
    
    try {
        # SETUP PHASE
        Write-SequenceLog "  [Setup] Beginning" -Level Debug
        if ($Setup) {
            $setupResult = & $Setup
            if ($setupResult -eq $false) {
                throw "Setup failed"
            }
        }
        Write-SequenceLog "  [Setup] Complete" -Level Debug
        
        # EXECUTE PHASE
        Write-SequenceLog "  [Execute] Beginning" -Level Debug
        $testPassed = & $Execute
        Write-SequenceLog "  [Execute] Complete" -Level Debug
        
        if ($testPassed) {
            $result.Status = 'Passed'
            $script:TestConfig.PassCount++
            Write-Host "  ✓ PASS" -ForegroundColor Green
        }
        else {
            $result.Status = 'Failed'
            $script:TestConfig.FailCount++
            Write-Host "  ✗ FAIL" -ForegroundColor Red
        }
    }
    catch {
        $result.Status = 'Error'
        $result.Error = $_.Exception.Message
        $script:TestConfig.FailCount++
        Write-SequenceLog "  [Error] $($_.Exception.Message)" -Level Error
        Write-Host "  ✗ ERROR" -ForegroundColor Red
    }
    finally {
        # CLEANUP PHASE - Always runs
        Write-SequenceLog "  [Cleanup] Beginning" -Level Debug
        if ($Cleanup) {
            try {
                & $Cleanup
            }
            catch {
                Write-SequenceLog "  [Cleanup] Warning: $($_.Exception.Message)" -Level Warning
            }
        }
        Write-SequenceLog "  [Cleanup] Complete" -Level Debug
        
        $result.EndTime = Get-Date
        $script:TestConfig.TestResults += $result
    }
    
    # Stabilization delay between tests
    Start-Sleep -Milliseconds 500
    
    return $result.Status -eq 'Passed'
}

#endregion

#region === TEST IMPLEMENTATIONS ===

function Test-OllamaUnreachable {
    Invoke-TestStep -TestName "Ollama Server Unreachable" `
        -Setup {
            # No mock server needed - we're testing connection failure
            Clear-TestEnvironment
            $env:OLLAMA_HOST = "http://localhost:65432"
            return $true
        } `
        -Execute {
            try {
                $output = & "$($script:TestConfig.ScriptDirectory)/Drive-Ollama-Executor.ps1" `
                    -Endpoint "http://localhost:65432" `
                    -Model "llama3-8b-local" `
                    -RepoPath "." `
                    -Goal "Test unreachable" `
                    -MaxTurns 1 `
                    *>&1
                
                $outputStr = $output | Out-String
                return ($outputStr -match 'Failed to reach Ollama|Connection refused|unreachable|Unable to connect')
            }
            catch {
                return ($_.Exception.Message -match 'Failed to reach|Connection|unreachable|Unable to connect')
            }
        } `
        -Cleanup {
            Clear-TestEnvironment
        }
}

function Test-SimulatedCommandFailure {
    Invoke-TestStep -TestName "Simulated Command Failure" `
        -Setup {
            Clear-TestEnvironment
            $env:OLLAMA_EXECUTOR_MODE = "sim"
            $env:OLLAMA_SIM_FAIL = "true"
            $env:OLLAMA_SIM_EXIT = "42"
            $env:OLLAMA_SIM_DELAY_MS = "10"
            $env:OLLAMA_HOST = "http://localhost:$($script:TestConfig.MockServerPort)"
            
            return (Initialize-MockServer -MaxRequests 10)
        } `
        -Execute {
            $tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) "fail-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $tempRepo -Force | Out-Null
            
            try {
                $output = & "$($script:TestConfig.ScriptDirectory)/Drive-Ollama-Executor.ps1" `
                    -Endpoint "http://localhost:$($script:TestConfig.MockServerPort)" `
                    -Model "llama3-8b-local" `
                    -RepoPath $tempRepo `
                    -Goal "Test failure" `
                    -MaxTurns 2 `
                    -StopAfterFirstCommand `
                    *>&1
                
                $outputStr = $output | Out-String
                return ($outputStr -match 'Exit=42')
            }
            finally {
                Remove-Item $tempRepo -Recurse -Force -ErrorAction SilentlyContinue
            }
        } `
        -Cleanup {
            $null = Terminate-MockServer
            Remove-Item Env:\OLLAMA_SIM_FAIL -ErrorAction SilentlyContinue
            Remove-Item Env:\OLLAMA_SIM_EXIT -ErrorAction SilentlyContinue
        }
}

function Test-StopAfterFirstCommand {
    Invoke-TestStep -TestName "StopAfterFirstCommand Flag" `
        -Setup {
            Clear-TestEnvironment
            $env:OLLAMA_EXECUTOR_MODE = "sim"
            $env:OLLAMA_SIM_DELAY_MS = "10"
            $env:OLLAMA_HOST = "http://localhost:$($script:TestConfig.MockServerPort)"
            
            return (Initialize-MockServer -MaxRequests 10)
        } `
        -Execute {
            $tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) "stop-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $tempRepo -Force | Out-Null
            
            try {
                $output = & "$($script:TestConfig.ScriptDirectory)/Drive-Ollama-Executor.ps1" `
                    -Endpoint "http://localhost:$($script:TestConfig.MockServerPort)" `
                    -Model "llama3-8b-local" `
                    -RepoPath $tempRepo `
                    -Goal "Test stop after first" `
                    -MaxTurns 10 `
                    -StopAfterFirstCommand `
                    *>&1
                
                $outputStr = $output | Out-String
                $hasStopMessage = $outputStr -match 'StopAfterFirstCommand'
                $commandMatches = [regex]::Matches($outputStr, '\[executor\] Exit=')
                
                if ($hasStopMessage -and $commandMatches.Count -ge 1) {
                    return $true
                }
                elseif ($hasStopMessage -and ($outputStr -match 'Rejected:|vetoed')) {
                    return $true
                }
                return $false
            }
            finally {
                Remove-Item $tempRepo -Recurse -Force -ErrorAction SilentlyContinue
            }
        } `
        -Cleanup {
            $null = Terminate-MockServer
        }
}

#endregion

#region === MAIN SEQUENCE ===

Write-Host "=== Ollama Executor Failure Tests ===" -ForegroundColor Cyan
Write-Host "Sequential Process Model" -ForegroundColor Gray
Write-Host ""

# === SEQUENCE SETUP ===
Set-SequenceState 'Setup'
Write-SequenceLog "Sequence Setup" -Level Info
Clear-TestEnvironment
$null = Terminate-MockServer  # Ensure clean initial state

# === MAIN SEQUENCE - Execute tests sequentially ===
Set-SequenceState 'Running'
Write-SequenceLog "Beginning Test Sequence" -Level Info

# Test 1
$null = Test-OllamaUnreachable

# Test 2
$null = Test-SimulatedCommandFailure

# Test 3
$null = Test-StopAfterFirstCommand

# === SEQUENCE CLEANUP ===
Set-SequenceState 'Cleanup'
Write-SequenceLog "Sequence Cleanup" -Level Info
$null = Terminate-MockServer
Clear-TestEnvironment

# === SEQUENCE COMPLETE ===
Set-SequenceState 'Complete'

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $($script:TestConfig.PassCount)" -ForegroundColor Green
Write-Host "Failed: $($script:TestConfig.FailCount)" -ForegroundColor $(if ($script:TestConfig.FailCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

# Report individual results
Write-Host "Test Results:" -ForegroundColor Gray
foreach ($result in $script:TestConfig.TestResults) {
    $statusColor = switch ($result.Status) {
        'Passed' { 'Green' }
        'Failed' { 'Red' }
        'Error' { 'Red' }
        default { 'Yellow' }
    }
    $duration = if ($result.EndTime -and $result.StartTime) { 
        [math]::Round(($result.EndTime - $result.StartTime).TotalSeconds, 2) 
    } else { 0 }
    Write-Host "  [$($result.Status)] $($result.Name) (${duration}s)" -ForegroundColor $statusColor
}
Write-Host ""

if ($script:TestConfig.FailCount -eq 0) {
    Write-Host "All failure tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some failure tests failed! ✗" -ForegroundColor Red
    exit 1
}

#endregion
