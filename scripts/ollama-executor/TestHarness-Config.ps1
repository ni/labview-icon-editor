<#
.SYNOPSIS
  Test Harness Configuration - Centralized configuration for the test framework.

.DESCRIPTION
  Provides configuration constants, test suite definitions, and runtime settings
  for the Ollama Executor test harness. Similar to TestStand's station globals
  and sequence file configuration.

.NOTES
  Part of the Ollama Executor Test Harness Framework.
#>

# Prevent direct execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Error "This script should be dot-sourced, not executed directly."
    exit 1
}

#region === HARNESS CONFIGURATION ===

$script:TestHarnessConfig = @{
    # Version info
    Version = '1.0.0'
    Name = 'Ollama Executor Test Harness'
    
    # Execution settings
    DefaultMode = 'fast'
    ValidModes = @('fast', 'full', 'security', 'performance')
    
    # Timeout settings (seconds)
    DefaultTestTimeout = 300
    DefaultSetupTimeout = 60
    DefaultCleanupTimeout = 30
    
    # Retry settings
    MaxRetries = 0
    RetryDelayMs = 1000
    
    # Resource settings
    MockServerPort = 11436
    PortReleaseWaitMs = 500
    ServerReadyTimeoutSec = 10
    
    # Report settings
    ReportDirectory = 'reports/test-results'
    EnableJsonReport = $true
    EnableHtmlReport = $false
    EnableJUnitReport = $true
    
    # Logging settings
    LogLevel = 'Info'  # Debug, Info, Warning, Error
    EnableTimestamps = $true
    EnableColors = $true
}

#endregion

#region === TEST SUITE DEFINITIONS ===

$script:TestSuiteDefinitions = @(
    @{
        Name = 'Command Vetting'
        Script = 'Test-CommandVetting.ps1'
        Phase = 1
        Required = $true
        Modes = @('fast', 'full', 'security')
        Description = 'Validates command vetting and security filters'
        Timeout = 60
    },
    @{
        Name = 'Simulation Mode'
        Script = 'Test-SimulationMode.ps1'
        Phase = 1
        Required = $true
        Modes = @('fast', 'full')
        Description = 'Tests simulation provider functionality'
        Timeout = 60
    },
    @{
        Name = 'Security Fuzzing'
        Script = 'Test-SecurityFuzzing.ps1'
        Phase = 2
        Required = $false
        Modes = @('full', 'security')
        Description = 'Security fuzzing and injection testing'
        Timeout = 120
    },
    @{
        Name = 'Failure Handling'
        Script = 'Test-Failures.ps1'
        Phase = 3
        Required = $false
        Modes = @('fast', 'full')
        Description = 'Error and failure scenario testing'
        Timeout = 120
    },
    @{
        Name = 'Timeout Handling'
        Script = 'Test-Timeout.ps1'
        Phase = 3
        Required = $false
        Modes = @('full')
        Description = 'Timeout behavior testing'
        Timeout = 180
    },
    @{
        Name = 'Conversation Scenarios'
        Script = 'Test-ConversationScenarios.ps1'
        Phase = 4
        Required = $false
        Modes = @('full')
        Description = 'Multi-turn conversation testing'
        Timeout = 300
    },
    @{
        Name = 'Integration Tests'
        Script = 'Test-Integration.ps1'
        Phase = 5
        Required = $false
        Modes = @('full')
        Description = 'Full integration testing'
        Timeout = 300
    },
    @{
        Name = 'Performance Benchmarks'
        Script = 'Test-Performance.ps1'
        Phase = 6
        Required = $false
        Modes = @('performance', 'full')
        Description = 'Performance and benchmark testing'
        Timeout = 600
    }
)

#endregion

#region === STATUS CODES ===

$script:TestStatus = @{
    NotRun = 0
    Running = 1
    Passed = 2
    Failed = 3
    Error = 4
    Skipped = 5
    Timeout = 6
    Aborted = 7
}

$script:TestStatusNames = @{
    0 = 'NotRun'
    1 = 'Running'
    2 = 'Passed'
    3 = 'Failed'
    4 = 'Error'
    5 = 'Skipped'
    6 = 'Timeout'
    7 = 'Aborted'
}

#endregion

#region === SEQUENCE STATES ===

$script:SequenceState = @{
    NotStarted = 'NotStarted'
    Initializing = 'Initializing'
    Setup = 'Setup'
    Running = 'Running'
    Cleanup = 'Cleanup'
    Reporting = 'Reporting'
    Complete = 'Complete'
    Aborted = 'Aborted'
}

#endregion

#region === HELPER FUNCTIONS ===

function Get-TestSuiteByName {
    param([string]$Name)
    return $script:TestSuiteDefinitions | Where-Object { $_.Name -eq $Name }
}

function Get-TestSuitesForMode {
    param([string]$Mode)
    return $script:TestSuiteDefinitions | Where-Object { 
        $Mode -eq 'full' -or $_.Modes -contains $Mode 
    } | Sort-Object Phase
}

function Get-TestSuitesByPhase {
    param([int]$Phase)
    return $script:TestSuiteDefinitions | Where-Object { $_.Phase -eq $Phase }
}

function Get-RequiredTestSuites {
    return $script:TestSuiteDefinitions | Where-Object { $_.Required }
}

#endregion
