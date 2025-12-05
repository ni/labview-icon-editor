<#
.SYNOPSIS
  Test Harness Executor - Test execution engine with lifecycle management.

.DESCRIPTION
  Provides the core test execution engine with Setup -> Execute -> Cleanup
  lifecycle, timeout handling, and result collection. Similar to TestStand's
  step execution functionality.

.NOTES
  Part of the Ollama Executor Test Harness Framework.
#>

# Prevent direct execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Error "This script should be dot-sourced, not executed directly."
    exit 1
}

#region === EXECUTION STATE ===

$script:ExecutionState = @{
    CurrentTest = $null
    CurrentPhase = $null
    TestQueue = [System.Collections.ArrayList]::new()
    CompletedTests = [System.Collections.ArrayList]::new()
    StartTime = $null
    EndTime = $null
    IsRunning = $false
    ShouldAbort = $false
}

#endregion

#region === TEST RESULT STRUCTURE ===

function New-TestResult {
    <#
    .SYNOPSIS
      Creates a new test result object.
    #>
    param(
        [string]$Name,
        [string]$Script
    )
    
    return @{
        name = $Name
        script = $Script
        status = 'NotRun'
        passed = $false
        exit_code = -1
        duration_seconds = 0
        start_time = $null
        end_time = $null
        output = ''
        error = $null
        phases = @{
            setup = @{ status = 'NotRun'; duration = 0; error = $null }
            execute = @{ status = 'NotRun'; duration = 0; error = $null }
            cleanup = @{ status = 'NotRun'; duration = 0; error = $null }
        }
    }
}

#endregion

#region === PHASE EXECUTION ===

function Invoke-TestPhase {
    <#
    .SYNOPSIS
      Executes a single phase of a test (Setup, Execute, or Cleanup).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PhaseName,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$TimeoutSeconds = 60,
        [hashtable]$Result
    )
    
    $script:ExecutionState.CurrentPhase = $PhaseName
    $phaseResult = @{
        status = 'Running'
        duration = 0
        error = $null
        output = $null
    }
    
    Write-TestLog "[$PhaseName] Beginning" -Level Debug
    Push-TestLogIndent
    
    $startTime = Get-Date
    
    try {
        # Execute with timeout
        $job = Start-Job -ScriptBlock $ScriptBlock
        $completed = Wait-Job $job -Timeout $TimeoutSeconds
        
        if ($completed) {
            $phaseResult.output = Receive-Job $job
            $exitCode = $job.State -eq 'Completed'
            
            if ($exitCode) {
                $phaseResult.status = 'Completed'
            } else {
                $phaseResult.status = 'Failed'
                $phaseResult.error = "Phase execution failed"
            }
        } else {
            # Timeout
            Stop-Job $job -ErrorAction SilentlyContinue
            $phaseResult.status = 'Timeout'
            $phaseResult.error = "Phase timed out after $TimeoutSeconds seconds"
            
            Register-TestWarning -Message "$PhaseName phase timed out" -TestName $Result.name -Phase $PhaseName
        }
        
        Remove-Job $job -Force -ErrorAction SilentlyContinue
    }
    catch {
        $phaseResult.status = 'Error'
        $phaseResult.error = $_.Exception.Message
        
        $error = New-TestError `
            -Message $_.Exception.Message `
            -Category 'Execution' `
            -TestName $Result.name `
            -Phase $PhaseName `
            -Exception $_.Exception
        
        Register-TestError -Error $error
    }
    finally {
        $phaseResult.duration = ((Get-Date) - $startTime).TotalSeconds
        Pop-TestLogIndent
        Write-TestLog "[$PhaseName] Complete ($([math]::Round($phaseResult.duration, 2))s) - $($phaseResult.status)" -Level Debug
    }
    
    return $phaseResult
}

#endregion

#region === TEST EXECUTION ===

function Invoke-SingleTest {
    <#
    .SYNOPSIS
      Executes a single test suite with full lifecycle management.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$TestDefinition,
        
        [string]$ScriptDirectory
    )
    
    $result = New-TestResult -Name $TestDefinition.Name -Script $TestDefinition.Script
    $result.start_time = Get-Date
    $script:ExecutionState.CurrentTest = $TestDefinition.Name
    
    Write-TestLog "" -NoTimestamp
    Write-TestSeparator
    Write-TestLog "TEST: $($TestDefinition.Name)" -Level Header -NoTimestamp
    Write-TestSeparator
    
    $scriptPath = Join-Path $ScriptDirectory $TestDefinition.Script
    
    # Verify script exists
    if (-not (Test-Path $scriptPath)) {
        $result.status = 'Error'
        $result.error = "Test script not found: $scriptPath"
        Register-TestError -Error (New-TestError -Message $result.error -Category 'Configuration' -TestName $TestDefinition.Name)
        return $result
    }
    
    try {
        # Execute the test script
        Write-TestLog "Executing: $scriptPath" -Level Debug
        
        $output = & $scriptPath *>&1
        $exitCode = $LASTEXITCODE
        
        $result.output = $output | Out-String
        $result.exit_code = $exitCode
        $result.passed = ($exitCode -eq 0)
        $result.status = if ($result.passed) { 'Passed' } else { 'Failed' }
        
        $result.phases.execute.status = $result.status
        $result.phases.execute.duration = ((Get-Date) - $result.start_time).TotalSeconds
    }
    catch {
        $result.status = 'Error'
        $result.error = $_.Exception.Message
        $result.phases.execute.status = 'Error'
        $result.phases.execute.error = $_.Exception.Message
        
        Register-TestError -Error (New-TestError `
            -Message $_.Exception.Message `
            -Category 'Execution' `
            -TestName $TestDefinition.Name `
            -Exception $_.Exception)
    }
    
    $result.end_time = Get-Date
    $result.duration_seconds = [math]::Round(($result.end_time - $result.start_time).TotalSeconds, 2)
    
    # Log result
    $statusCode = switch ($result.status) {
        'Passed' { $script:TestStatus.Passed }
        'Failed' { $script:TestStatus.Failed }
        'Error' { $script:TestStatus.Error }
        'Skipped' { $script:TestStatus.Skipped }
        'Timeout' { $script:TestStatus.Timeout }
        default { $script:TestStatus.NotRun }
    }
    
    Write-TestStatus -TestName $TestDefinition.Name -Status $statusCode -Duration $result.duration_seconds
    
    $script:ExecutionState.CompletedTests.Add($result) | Out-Null
    $script:ExecutionState.CurrentTest = $null
    
    return $result
}

function Invoke-TestSuite {
    <#
    .SYNOPSIS
      Executes a test suite (wrapper for compatibility with existing code).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [switch]$Required,
        [string[]]$Modes = @('full'),
        [string]$CurrentMode = 'fast'
    )
    
    # Check if test should run in current mode
    if ($CurrentMode -ne 'full' -and $Modes -notcontains $CurrentMode) {
        Write-TestLog "[$Name] Skipped (not in $CurrentMode mode)" -Level Warning
        
        $result = New-TestResult -Name $Name -Script $ScriptPath
        $result.status = 'Skipped'
        $script:ExecutionState.CompletedTests.Add($result) | Out-Null
        
        return $result
    }
    
    $testDef = @{
        Name = $Name
        Script = (Split-Path $ScriptPath -Leaf)
        Required = $Required.IsPresent
        Modes = $Modes
    }
    
    return Invoke-SingleTest -TestDefinition $testDef -ScriptDirectory (Split-Path $ScriptPath -Parent)
}

#endregion

#region === BATCH EXECUTION ===

function Invoke-TestBatch {
    <#
    .SYNOPSIS
      Executes a batch of tests sequentially.
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Tests,
        
        [Parameter(Mandatory)]
        [string]$ScriptDirectory,
        
        [string]$Mode = 'fast',
        [switch]$StopOnFailure
    )
    
    $script:ExecutionState.IsRunning = $true
    $script:ExecutionState.StartTime = Get-Date
    $script:ExecutionState.CompletedTests.Clear()
    $script:ExecutionState.ShouldAbort = $false
    
    $results = @()
    $failedRequired = $false
    
    foreach ($test in $Tests) {
        # Check for abort
        if ($script:ExecutionState.ShouldAbort) {
            Write-TestLog "Execution aborted" -Level Warning
            break
        }
        
        # Check if test should run
        if ($Mode -ne 'full' -and $test.Modes -notcontains $Mode) {
            $result = New-TestResult -Name $test.Name -Script $test.Script
            $result.status = 'Skipped'
            $results += $result
            $script:ExecutionState.CompletedTests.Add($result) | Out-Null
            continue
        }
        
        # Execute test
        $result = Invoke-SingleTest -TestDefinition $test -ScriptDirectory $ScriptDirectory
        $results += $result
        
        # Check for required test failure
        if ($test.Required -and -not $result.passed) {
            $failedRequired = $true
            Write-TestLog "CRITICAL: Required test '$($test.Name)' failed!" -Level Critical
            
            if ($StopOnFailure) {
                Write-TestLog "Stopping execution due to required test failure" -Level Warning
                break
            }
        }
    }
    
    $script:ExecutionState.EndTime = Get-Date
    $script:ExecutionState.IsRunning = $false
    
    return @{
        Results = $results
        TotalDuration = ($script:ExecutionState.EndTime - $script:ExecutionState.StartTime).TotalSeconds
        FailedRequired = $failedRequired
        Aborted = $script:ExecutionState.ShouldAbort
    }
}

#endregion

#region === EXECUTION CONTROL ===

function Stop-TestExecution {
    <#
    .SYNOPSIS
      Signals the executor to stop after the current test.
    #>
    
    Write-TestLog "Stop requested - will abort after current test" -Level Warning
    $script:ExecutionState.ShouldAbort = $true
}

function Get-ExecutionState {
    <#
    .SYNOPSIS
      Returns the current execution state.
    #>
    
    return @{
        IsRunning = $script:ExecutionState.IsRunning
        CurrentTest = $script:ExecutionState.CurrentTest
        CurrentPhase = $script:ExecutionState.CurrentPhase
        CompletedCount = $script:ExecutionState.CompletedTests.Count
        ShouldAbort = $script:ExecutionState.ShouldAbort
    }
}

function Get-CompletedTests {
    <#
    .SYNOPSIS
      Returns all completed test results.
    #>
    
    return $script:ExecutionState.CompletedTests.ToArray()
}

#endregion
