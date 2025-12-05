<#
.SYNOPSIS
  Test Harness Error Handler - Centralized error handling and recovery.

.DESCRIPTION
  Provides structured error handling, error classification, recovery strategies,
  and error reporting. Similar to TestStand's error handling and cleanup
  functionality.

.NOTES
  Part of the Ollama Executor Test Harness Framework.
#>

# Prevent direct execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Error "This script should be dot-sourced, not executed directly."
    exit 1
}

#region === ERROR CATEGORIES ===

$script:ErrorCategories = @{
    Setup = 'SETUP_ERROR'
    Execution = 'EXECUTION_ERROR'
    Cleanup = 'CLEANUP_ERROR'
    Timeout = 'TIMEOUT_ERROR'
    Resource = 'RESOURCE_ERROR'
    Network = 'NETWORK_ERROR'
    Validation = 'VALIDATION_ERROR'
    Configuration = 'CONFIG_ERROR'
    Unknown = 'UNKNOWN_ERROR'
}

#endregion

#region === ERROR STATE ===

$script:ErrorState = @{
    Errors = [System.Collections.ArrayList]::new()
    Warnings = [System.Collections.ArrayList]::new()
    LastError = $null
    ErrorCount = 0
    WarningCount = 0
    CriticalErrorOccurred = $false
}

#endregion

#region === ERROR RECORDING ===

function New-TestError {
    <#
    .SYNOPSIS
      Creates a structured error object.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$Category = 'Unknown',
        [string]$TestName = '',
        [string]$Phase = '',
        [System.Exception]$Exception = $null,
        [hashtable]$Context = @{},
        [bool]$IsCritical = $false
    )
    
    $errorObj = @{
        Id = [guid]::NewGuid().ToString('N').Substring(0, 8)
        Timestamp = Get-Date
        Message = $Message
        Category = $script:ErrorCategories[$Category]
        TestName = $TestName
        Phase = $Phase
        IsCritical = $IsCritical
        Context = $Context
        Exception = if ($Exception) {
            @{
                Type = $Exception.GetType().FullName
                Message = $Exception.Message
                StackTrace = $Exception.StackTrace
                InnerException = if ($Exception.InnerException) { $Exception.InnerException.Message } else { $null }
            }
        } else { $null }
    }
    
    return $errorObj
}

function Register-TestError {
    <#
    .SYNOPSIS
      Registers an error in the error state.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Error
    )
    
    $script:ErrorState.Errors.Add($Error) | Out-Null
    $script:ErrorState.LastError = $Error
    $script:ErrorState.ErrorCount++
    
    if ($Error.IsCritical) {
        $script:ErrorState.CriticalErrorOccurred = $true
    }
    
    # Log the error
    $logMessage = "[$($Error.Category)] $($Error.Message)"
    if ($Error.TestName) {
        $logMessage = "[$($Error.TestName)] $logMessage"
    }
    
    Write-TestLog $logMessage -Level $(if ($Error.IsCritical) { 'Critical' } else { 'Error' })
    
    if ($Error.Exception -and $script:LogState.CurrentLevel -eq 0) {
        Write-TestLog "  Exception: $($Error.Exception.Type)" -Level Debug
        Write-TestLog "  Stack: $($Error.Exception.StackTrace)" -Level Debug
    }
}

function Register-TestWarning {
    <#
    .SYNOPSIS
      Registers a warning in the error state.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$TestName = '',
        [string]$Phase = '',
        [hashtable]$Context = @{}
    )
    
    $warning = @{
        Id = [guid]::NewGuid().ToString('N').Substring(0, 8)
        Timestamp = Get-Date
        Message = $Message
        TestName = $TestName
        Phase = $Phase
        Context = $Context
    }
    
    $script:ErrorState.Warnings.Add($warning) | Out-Null
    $script:ErrorState.WarningCount++
    
    $logMessage = $Message
    if ($TestName) {
        $logMessage = "[$TestName] $logMessage"
    }
    
    Write-TestLog $logMessage -Level Warning
}

#endregion

#region === ERROR HANDLING ===

function Invoke-WithErrorHandling {
    <#
    .SYNOPSIS
      Executes a script block with standardized error handling.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [string]$TestName = '',
        [string]$Phase = 'Execution',
        [string]$ErrorCategory = 'Execution',
        [switch]$CriticalOnError,
        [scriptblock]$OnError = $null,
        [scriptblock]$Finally = $null
    )
    
    $result = @{
        Success = $false
        Result = $null
        Error = $null
        Duration = 0
    }
    
    $startTime = Get-Date
    
    try {
        $result.Result = & $ScriptBlock
        $result.Success = $true
    }
    catch {
        $error = New-TestError `
            -Message $_.Exception.Message `
            -Category $ErrorCategory `
            -TestName $TestName `
            -Phase $Phase `
            -Exception $_.Exception `
            -IsCritical:$CriticalOnError
        
        Register-TestError -Error $error
        $result.Error = $error
        
        if ($OnError) {
            try {
                & $OnError $_
            }
            catch {
                Register-TestWarning -Message "Error handler failed: $($_.Exception.Message)" -TestName $TestName
            }
        }
    }
    finally {
        $result.Duration = ((Get-Date) - $startTime).TotalSeconds
        
        if ($Finally) {
            try {
                & $Finally
            }
            catch {
                Register-TestWarning -Message "Finally block failed: $($_.Exception.Message)" -TestName $TestName
            }
        }
    }
    
    return $result
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
      Executes a script block with retry logic.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$MaxRetries = 3,
        [int]$DelayMs = 1000,
        [string]$OperationName = 'Operation',
        [scriptblock]$OnRetry = $null
    )
    
    $attempt = 0
    $lastError = $null
    
    while ($attempt -lt $MaxRetries) {
        $attempt++
        
        try {
            return & $ScriptBlock
        }
        catch {
            $lastError = $_
            
            if ($attempt -lt $MaxRetries) {
                Write-TestLog "$OperationName failed (attempt $attempt/$MaxRetries), retrying..." -Level Warning
                
                if ($OnRetry) {
                    try { & $OnRetry $attempt } catch {}
                }
                
                Start-Sleep -Milliseconds $DelayMs
            }
        }
    }
    
    throw $lastError
}

#endregion

#region === ERROR RECOVERY ===

function Invoke-ErrorRecovery {
    <#
    .SYNOPSIS
      Attempts to recover from an error condition.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Error,
        
        [scriptblock]$RecoveryAction = $null
    )
    
    Write-TestLog "Attempting recovery for error: $($Error.Id)" -Level Warning
    
    $recovered = $false
    
    # Category-specific recovery
    switch ($Error.Category) {
        'RESOURCE_ERROR' {
            # Try to release resources
            if ($script:TestHarnessConfig) {
                Invoke-ResourceCleanup
                $recovered = $true
            }
        }
        'NETWORK_ERROR' {
            # Wait and check connectivity
            Start-Sleep -Seconds 2
            $recovered = $true
        }
        default {
            if ($RecoveryAction) {
                try {
                    & $RecoveryAction
                    $recovered = $true
                }
                catch {
                    Write-TestLog "Recovery action failed: $($_.Exception.Message)" -Level Error
                }
            }
        }
    }
    
    if ($recovered) {
        Write-TestLog "Recovery successful for error: $($Error.Id)" -Level Success
    } else {
        Write-TestLog "Recovery failed for error: $($Error.Id)" -Level Error
    }
    
    return $recovered
}

function Invoke-ResourceCleanup {
    <#
    .SYNOPSIS
      Performs emergency resource cleanup.
    #>
    
    Write-TestLog "Performing emergency resource cleanup" -Level Warning
    
    # Stop any mock servers
    Get-Job | Where-Object { $_.Name -like '*Mock*' -or $_.Name -like '*Test*' } | ForEach-Object {
        Stop-Job $_ -ErrorAction SilentlyContinue
        Remove-Job $_ -Force -ErrorAction SilentlyContinue
    }
    
    # Clear environment variables
    $testEnvVars = @('OLLAMA_EXECUTOR_MODE', 'OLLAMA_SIM_FAIL', 'OLLAMA_SIM_EXIT', 
                     'OLLAMA_SIM_DELAY_MS', 'OLLAMA_HOST')
    foreach ($var in $testEnvVars) {
        Remove-Item "Env:\$var" -ErrorAction SilentlyContinue
    }
    
    # Wait for port release
    Start-Sleep -Milliseconds 500
}

#endregion

#region === ERROR REPORTING ===

function Get-ErrorSummary {
    <#
    .SYNOPSIS
      Returns a summary of all errors.
    #>
    
    $criticalErrors = @($script:ErrorState.Errors | Where-Object { $_.IsCritical })
    $errorsByCategory = $script:ErrorState.Errors | Group-Object -Property Category | ForEach-Object {
        @{ Category = $_.Name; Count = $_.Count }
    }
    
    return @{
        TotalErrors = $script:ErrorState.ErrorCount
        TotalWarnings = $script:ErrorState.WarningCount
        CriticalErrors = $criticalErrors.Count
        ErrorsByCategory = @($errorsByCategory)
        Errors = @($script:ErrorState.Errors)
        Warnings = @($script:ErrorState.Warnings)
    }
}

function Reset-ErrorState {
    <#
    .SYNOPSIS
      Resets the error state for a new test run.
    #>
    
    $script:ErrorState.Errors.Clear()
    $script:ErrorState.Warnings.Clear()
    $script:ErrorState.LastError = $null
    $script:ErrorState.ErrorCount = 0
    $script:ErrorState.WarningCount = 0
    $script:ErrorState.CriticalErrorOccurred = $false
}

function Test-CriticalErrorOccurred {
    return $script:ErrorState.CriticalErrorOccurred
}

#endregion
