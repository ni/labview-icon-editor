<#
.SYNOPSIS
  Test Harness Sequencer - Test orchestration and sequencing.

.DESCRIPTION
  Provides the main test sequencing logic, phase management, and overall
  orchestration of the test harness. Similar to TestStand's sequence
  execution engine.

.NOTES
  Part of the Ollama Executor Test Harness Framework.
#>

# Prevent direct execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Error "This script should be dot-sourced, not executed directly."
    exit 1
}

#region === SEQUENCE STATE ===

$script:SequenceRunState = @{
    CurrentState = 'NotStarted'
    Mode = 'fast'
    StartTime = $null
    EndTime = $null
    Phases = @{
        Setup = @{ Status = 'NotRun'; Duration = 0 }
        Execution = @{ Status = 'NotRun'; Duration = 0 }
        Cleanup = @{ Status = 'NotRun'; Duration = 0 }
        Reporting = @{ Status = 'NotRun'; Duration = 0 }
    }
    Results = $null
}

#endregion

#region === SEQUENCE LIFECYCLE ===

function Start-TestSequence {
    <#
    .SYNOPSIS
      Starts a new test sequence.
    #>
    param(
        [ValidateSet('fast', 'full', 'security', 'performance')]
        [string]$Mode = 'fast',
        
        [switch]$CI,
        [switch]$GenerateReport,
        [string]$LogLevel = 'Info'
    )
    
    # Initialize state
    $script:SequenceRunState.CurrentState = 'Initializing'
    $script:SequenceRunState.Mode = $Mode
    $script:SequenceRunState.StartTime = Get-Date
    
    # Initialize subsystems
    Initialize-TestLog -Level $LogLevel
    Reset-ErrorState
    
    Write-TestHeader "$($script:TestHarnessConfig.Name)"
    Write-TestLog "Version: $($script:TestHarnessConfig.Version)" -Level Info
    Write-TestLog "Mode: $Mode" -Level Info
    Write-TestLog "CI Mode: $CI" -Level Info
    Write-TestLog "" -NoTimestamp
    
    return @{
        Mode = $Mode
        CI = $CI.IsPresent
        GenerateReport = $GenerateReport.IsPresent
        StartTime = $script:SequenceRunState.StartTime
    }
}

function Invoke-SequenceSetup {
    <#
    .SYNOPSIS
      Executes the sequence setup phase.
    #>
    
    $script:SequenceRunState.CurrentState = 'Setup'
    $startTime = Get-Date
    
    Write-TestLog "" -NoTimestamp
    Write-TestLog "=== SEQUENCE SETUP ===" -Level Header -NoTimestamp
    Push-TestLogIndent
    
    try {
        # Verify test scripts exist
        $scriptDir = $PSScriptRoot
        $missingScripts = @()
        
        foreach ($suite in $script:TestSuiteDefinitions) {
            $scriptPath = Join-Path $scriptDir $suite.Script
            if (-not (Test-Path $scriptPath)) {
                $missingScripts += $suite.Script
            }
        }
        
        if ($missingScripts.Count -gt 0) {
            Write-TestLog "Warning: Missing test scripts: $($missingScripts -join ', ')" -Level Warning
        }
        
        # Clean up any stale resources
        Write-TestLog "Cleaning up stale resources..." -Level Debug
        Invoke-ResourceCleanup
        
        $script:SequenceRunState.Phases.Setup.Status = 'Completed'
        Write-TestLog "Setup completed successfully" -Level Success
    }
    catch {
        $script:SequenceRunState.Phases.Setup.Status = 'Failed'
        Register-TestError -Error (New-TestError -Message $_.Exception.Message -Category 'Setup' -Exception $_.Exception -IsCritical:$true)
        throw
    }
    finally {
        $script:SequenceRunState.Phases.Setup.Duration = ((Get-Date) - $startTime).TotalSeconds
        Pop-TestLogIndent
    }
}

function Invoke-SequenceExecution {
    <#
    .SYNOPSIS
      Executes the main test sequence.
    #>
    param(
        [string]$Mode = 'fast',
        [switch]$StopOnRequiredFailure
    )
    
    $script:SequenceRunState.CurrentState = 'Running'
    $startTime = Get-Date
    
    Write-TestLog "" -NoTimestamp
    Write-TestLog "=== TEST EXECUTION ===" -Level Header -NoTimestamp
    Push-TestLogIndent
    
    $results = @{
        mode = $Mode
        timestamp = (Get-Date).ToString('o')
        suites = @()
        summary = @{
            total = 0
            passed = 0
            failed = 0
            skipped = 0
            duration_seconds = 0
        }
    }
    
    try {
        $scriptDir = $PSScriptRoot
        $testsToRun = Get-TestSuitesForMode -Mode $Mode
        
        Write-TestLog "Executing $($testsToRun.Count) test suite(s)" -Level Info
        
        foreach ($testDef in $testsToRun) {
            # Check for abort
            if (Test-CriticalErrorOccurred -and $StopOnRequiredFailure) {
                Write-TestLog "Aborting due to critical error" -Level Warning
                break
            }
            
            $scriptPath = Join-Path $scriptDir $testDef.Script
            
            if (-not (Test-Path $scriptPath)) {
                Write-TestLog "[$($testDef.Name)] Skipped - script not found" -Level Warning
                $results.summary.skipped++
                continue
            }
            
            # Execute test
            $testResult = Invoke-TestSuite `
                -Name $testDef.Name `
                -ScriptPath $scriptPath `
                -Required:$testDef.Required `
                -Modes $testDef.Modes `
                -CurrentMode $Mode
            
            # Record result
            $results.suites += $testResult
            $results.summary.total++
            
            if ($testResult.status -eq 'Skipped') {
                $results.summary.skipped++
            }
            elseif ($testResult.passed) {
                $results.summary.passed++
            }
            else {
                $results.summary.failed++
                
                if ($testDef.Required) {
                    Register-TestError -Error (New-TestError `
                        -Message "Required test '$($testDef.Name)' failed" `
                        -Category 'Execution' `
                        -TestName $testDef.Name `
                        -IsCritical:$true)
                }
            }
        }
        
        $script:SequenceRunState.Phases.Execution.Status = 'Completed'
    }
    catch {
        $script:SequenceRunState.Phases.Execution.Status = 'Failed'
        Register-TestError -Error (New-TestError -Message $_.Exception.Message -Category 'Execution' -Exception $_.Exception)
    }
    finally {
        $endTime = Get-Date
        $script:SequenceRunState.Phases.Execution.Duration = ($endTime - $startTime).TotalSeconds
        $results.summary.duration_seconds = [math]::Round($script:SequenceRunState.Phases.Execution.Duration, 2)
        
        Pop-TestLogIndent
    }
    
    $script:SequenceRunState.Results = $results
    return $results
}

function Invoke-SequenceCleanup {
    <#
    .SYNOPSIS
      Executes the sequence cleanup phase.
    #>
    
    $script:SequenceRunState.CurrentState = 'Cleanup'
    $startTime = Get-Date
    
    Write-TestLog "" -NoTimestamp
    Write-TestLog "=== SEQUENCE CLEANUP ===" -Level Header -NoTimestamp
    Push-TestLogIndent
    
    try {
        Write-TestLog "Performing resource cleanup..." -Level Debug
        Invoke-ResourceCleanup
        
        $script:SequenceRunState.Phases.Cleanup.Status = 'Completed'
        Write-TestLog "Cleanup completed" -Level Success
    }
    catch {
        $script:SequenceRunState.Phases.Cleanup.Status = 'Failed'
        Register-TestWarning -Message "Cleanup failed: $($_.Exception.Message)"
    }
    finally {
        $script:SequenceRunState.Phases.Cleanup.Duration = ((Get-Date) - $startTime).TotalSeconds
        Pop-TestLogIndent
    }
}

function Invoke-SequenceReporting {
    <#
    .SYNOPSIS
      Executes the reporting phase.
    #>
    param(
        [switch]$CI,
        [switch]$GenerateHtml
    )
    
    $script:SequenceRunState.CurrentState = 'Reporting'
    $startTime = Get-Date
    
    Write-TestLog "" -NoTimestamp
    Write-TestLog "=== REPORTING ===" -Level Header -NoTimestamp
    Push-TestLogIndent
    
    try {
        if (-not $script:SequenceRunState.Results) {
            Write-TestLog "No results to report" -Level Warning
            return
        }
        
        # Initialize reporter
        Initialize-TestReporter -Results $script:SequenceRunState.Results
        
        # Console summary
        Write-TestResultsConsole
        
        # Generate reports
        if ($CI) {
            Export-TestResultsJUnit
            Export-TestResultsJson
        }
        
        if ($GenerateHtml) {
            Export-TestResultsHtml -IncludeOutput
        }
        
        $script:SequenceRunState.Phases.Reporting.Status = 'Completed'
    }
    catch {
        $script:SequenceRunState.Phases.Reporting.Status = 'Failed'
        Register-TestWarning -Message "Reporting failed: $($_.Exception.Message)"
    }
    finally {
        $script:SequenceRunState.Phases.Reporting.Duration = ((Get-Date) - $startTime).TotalSeconds
        Pop-TestLogIndent
    }
}

function Complete-TestSequence {
    <#
    .SYNOPSIS
      Completes the test sequence and returns final status.
    #>
    
    $script:SequenceRunState.CurrentState = 'Complete'
    $script:SequenceRunState.EndTime = Get-Date
    
    $totalDuration = ($script:SequenceRunState.EndTime - $script:SequenceRunState.StartTime).TotalSeconds
    
    Write-TestLog "" -NoTimestamp
    Write-TestLog "Sequence completed in $([math]::Round($totalDuration, 2))s" -Level Info
    
    # Return exit code based on results
    $exitCode = 0
    if ($script:SequenceRunState.Results -and $script:SequenceRunState.Results.summary.failed -gt 0) {
        $exitCode = 1
    }
    
    if (Test-CriticalErrorOccurred) {
        $exitCode = 2
    }
    
    return @{
        ExitCode = $exitCode
        Duration = $totalDuration
        Results = $script:SequenceRunState.Results
        ErrorSummary = Get-ErrorSummary
    }
}

#endregion

#region === CONVENIENCE FUNCTION ===

function Invoke-FullTestSequence {
    <#
    .SYNOPSIS
      Runs the complete test sequence with all phases.
    #>
    param(
        [ValidateSet('fast', 'full', 'security', 'performance')]
        [string]$Mode = 'fast',
        
        [switch]$CI,
        [switch]$GenerateReport,
        [string]$LogLevel = 'Info'
    )
    
    try {
        # Start
        $null = Start-TestSequence -Mode $Mode -CI:$CI -GenerateReport:$GenerateReport -LogLevel $LogLevel
        
        # Setup
        $null = Invoke-SequenceSetup
        
        # Execute
        $null = Invoke-SequenceExecution -Mode $Mode
        
        # Cleanup
        $null = Invoke-SequenceCleanup
        
        # Report
        $null = Invoke-SequenceReporting -CI:$CI -GenerateHtml:$GenerateReport
        
        # Complete
        return Complete-TestSequence
    }
    catch {
        Write-TestLog "Sequence failed with error: $($_.Exception.Message)" -Level Critical
        
        # Emergency cleanup
        try { $null = Invoke-SequenceCleanup } catch {}
        
        return @{
            ExitCode = 99
            Duration = 0
            Results = $null
            ErrorSummary = Get-ErrorSummary
        }
    }
}

#endregion
