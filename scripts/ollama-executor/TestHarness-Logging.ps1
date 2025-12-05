<#
.SYNOPSIS
  Test Harness Logging - Centralized logging and status reporting.

.DESCRIPTION
  Provides structured logging with levels, timestamps, and color coding.
  Supports console output and log file generation. Similar to TestStand's
  report generation and trace functionality.

.NOTES
  Part of the Ollama Executor Test Harness Framework.
#>

# Prevent direct execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Error "This script should be dot-sourced, not executed directly."
    exit 1
}

#region === LOG LEVELS ===

$script:LogLevels = @{
    Debug = 0
    Info = 1
    Warning = 2
    Error = 3
    Critical = 4
}

$script:LogColors = @{
    Debug = 'Gray'
    Info = 'White'
    Warning = 'Yellow'
    Error = 'Red'
    Critical = 'Magenta'
    Success = 'Green'
    Header = 'Cyan'
    Separator = 'DarkGray'
}

#endregion

#region === LOG STATE ===

$script:LogState = @{
    CurrentLevel = 1  # Info
    LogBuffer = [System.Collections.ArrayList]::new()
    SessionStart = $null
    LastTimestamp = $null
    IndentLevel = 0
    EnableFile = $false
    LogFilePath = $null
}

#endregion

#region === CORE LOGGING FUNCTIONS ===

function Initialize-TestLog {
    <#
    .SYNOPSIS
      Initializes the logging system for a test session.
    #>
    param(
        [string]$Level = 'Info',
        [switch]$EnableFileLog,
        [string]$LogDirectory = 'reports/logs'
    )
    
    $script:LogState.SessionStart = Get-Date
    $script:LogState.LastTimestamp = $script:LogState.SessionStart
    $script:LogState.CurrentLevel = $script:LogLevels[$Level]
    $script:LogState.LogBuffer.Clear()
    $script:LogState.IndentLevel = 0
    
    if ($EnableFileLog) {
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $script:LogState.LogFilePath = Join-Path $LogDirectory "test-log-$timestamp.log"
        $script:LogState.EnableFile = $true
    }
}

function Write-TestLog {
    <#
    .SYNOPSIS
      Writes a log message with level, timestamp, and formatting.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = '',
        
        [ValidateSet('Debug', 'Info', 'Warning', 'Error', 'Critical', 'Success', 'Header', 'Separator')]
        [string]$Level = 'Info',
        
        [switch]$NoNewLine,
        [switch]$NoTimestamp
    )
    
    # Handle empty message - just write blank line
    if ([string]::IsNullOrEmpty($Message)) {
        Write-Host ""
        return
    }
    
    # Check if message should be displayed based on log level
    $msgLevel = if ($script:LogLevels.ContainsKey($Level)) { $script:LogLevels[$Level] } else { 1 }
    if ($msgLevel -lt $script:LogState.CurrentLevel -and $Level -notin @('Success', 'Header', 'Separator')) {
        return
    }
    
    $now = Get-Date
    $elapsed = if ($script:LogState.SessionStart) {
        $span = $now - $script:LogState.SessionStart
        "{0:00}:{1:00}.{2:000}" -f [int]$span.TotalMinutes, $span.Seconds, $span.Milliseconds
    } else { "00:00.000" }
    
    # Build log entry
    $indent = "  " * $script:LogState.IndentLevel
    $timestamp = if ($NoTimestamp) { "" } else { "[$elapsed] " }
    $prefix = switch ($Level) {
        'Error' { "[ERROR] " }
        'Warning' { "[WARN]  " }
        'Critical' { "[CRIT]  " }
        'Debug' { "[DEBUG] " }
        default { "" }
    }
    
    $formattedMessage = "$timestamp$indent$prefix$Message"
    
    # Add to buffer
    $logEntry = @{
        Timestamp = $now
        Elapsed = $elapsed
        Level = $Level
        Message = $Message
        Formatted = $formattedMessage
    }
    $script:LogState.LogBuffer.Add($logEntry) | Out-Null
    
    # Write to console
    $color = $script:LogColors[$Level]
    if ($NoNewLine) {
        Write-Host $formattedMessage -ForegroundColor $color -NoNewline
    } else {
        Write-Host $formattedMessage -ForegroundColor $color
    }
    
    # Write to file if enabled
    if ($script:LogState.EnableFile -and $script:LogState.LogFilePath) {
        Add-Content -Path $script:LogState.LogFilePath -Value $formattedMessage
    }
    
    $script:LogState.LastTimestamp = $now
}

function Write-TestHeader {
    <#
    .SYNOPSIS
      Writes a formatted header section.
    #>
    param(
        [string]$Title,
        [char]$Char = '=',
        [int]$Width = 50
    )
    
    $separator = [string]::new($Char, $Width)
    Write-TestLog $separator -Level Header -NoTimestamp
    Write-TestLog $Title -Level Header -NoTimestamp
    Write-TestLog $separator -Level Header -NoTimestamp
}

function Write-TestSeparator {
    <#
    .SYNOPSIS
      Writes a separator line.
    #>
    param(
        [char]$Char = '-',
        [int]$Width = 50
    )
    
    Write-TestLog ([string]::new($Char, $Width)) -Level Separator -NoTimestamp
}

function Write-TestProgress {
    <#
    .SYNOPSIS
      Writes a progress indicator for a test step.
    #>
    param(
        [string]$Step,
        [string]$Status,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$StatusType = 'Info'
    )
    
    $statusIcon = switch ($StatusType) {
        'Success' { '✓' }
        'Warning' { '⚠' }
        'Error' { '✗' }
        default { '○' }
    }
    
    Write-TestLog "[$statusIcon] $Step - $Status" -Level $StatusType
}

#endregion

#region === INDENT MANAGEMENT ===

function Push-TestLogIndent {
    $script:LogState.IndentLevel++
}

function Pop-TestLogIndent {
    if ($script:LogState.IndentLevel -gt 0) {
        $script:LogState.IndentLevel--
    }
}

function Reset-TestLogIndent {
    $script:LogState.IndentLevel = 0
}

#endregion

#region === STATUS REPORTING ===

function Write-TestStatus {
    <#
    .SYNOPSIS
      Writes a test status update with consistent formatting.
    #>
    param(
        [string]$TestName,
        [int]$Status,
        [double]$Duration = 0,
        [string]$Details = ''
    )
    
    $statusName = $script:TestStatusNames[$Status]
    $statusDisplay = switch ($Status) {
        2 { "✓ PASSED" }
        3 { "✗ FAILED" }
        4 { "✗ ERROR" }
        5 { "⊘ SKIPPED" }
        6 { "⏱ TIMEOUT" }
        7 { "⊗ ABORTED" }
        default { "○ $statusName" }
    }
    
    $level = switch ($Status) {
        2 { 'Success' }
        3 { 'Error' }
        4 { 'Error' }
        5 { 'Warning' }
        6 { 'Warning' }
        7 { 'Error' }
        default { 'Info' }
    }
    
    $durationStr = if ($Duration -gt 0) { " ({0:F2}s)" -f $Duration } else { "" }
    $detailStr = if ($Details) { " - $Details" } else { "" }
    
    Write-TestLog "[$TestName] $statusDisplay$durationStr$detailStr" -Level $level
}

function Write-TestSummary {
    <#
    .SYNOPSIS
      Writes a summary of test results.
    #>
    param(
        [int]$Total,
        [int]$Passed,
        [int]$Failed,
        [int]$Skipped,
        [double]$Duration
    )
    
    Write-TestLog "" -NoTimestamp
    Write-TestHeader "Test Summary"
    Write-TestLog "Total:    $Total" -Level Info
    Write-TestLog "Passed:   $Passed" -Level $(if ($Passed -gt 0) { 'Success' } else { 'Info' })
    Write-TestLog "Failed:   $Failed" -Level $(if ($Failed -gt 0) { 'Error' } else { 'Success' })
    Write-TestLog "Skipped:  $Skipped" -Level $(if ($Skipped -gt 0) { 'Warning' } else { 'Info' })
    Write-TestLog "Duration: $($Duration)s" -Level Info
    Write-TestLog "" -NoTimestamp
    
    if ($Failed -eq 0) {
        Write-TestLog "All tests passed! ✓" -Level Success
    } else {
        Write-TestLog "$Failed test(s) failed! ✗" -Level Error
    }
}

#endregion

#region === LOG RETRIEVAL ===

function Get-TestLogBuffer {
    <#
    .SYNOPSIS
      Returns the log buffer for report generation.
    #>
    return $script:LogState.LogBuffer.ToArray()
}

function Get-TestLogAsText {
    <#
    .SYNOPSIS
      Returns the log as plain text.
    #>
    return ($script:LogState.LogBuffer | ForEach-Object { $_.Formatted }) -join "`n"
}

#endregion
