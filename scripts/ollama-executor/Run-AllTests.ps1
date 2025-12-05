<#
.SYNOPSIS
  Master test orchestrator for running all Ollama executor tests.

.DESCRIPTION
  Unified test runner that executes all test suites in the correct order and generates
  comprehensive test reports. Uses a modular test harness framework with:
  - Centralized configuration (TestHarness-Config.ps1)
  - Structured logging (TestHarness-Logging.ps1)
  - Error handling (TestHarness-ErrorHandler.ps1)
  - Report generation (TestHarness-Reporter.ps1)
  - Test execution engine (TestHarness-Executor.ps1)
  - Sequence orchestration (TestHarness-Sequencer.ps1)

.PARAMETER Mode
  Test mode: 'fast' (quick essential tests), 'full' (all tests), 'security' (security-focused),
  'performance' (benchmarks only)

.PARAMETER GenerateReport
  Generate HTML test report

.PARAMETER CI
  CI/CD mode - generates JUnit XML output and returns appropriate exit codes

.PARAMETER LogLevel
  Logging verbosity: Debug, Info, Warning, Error

.EXAMPLE
  # Quick test run
  pwsh -NoProfile -File scripts/ollama-executor/Run-AllTests.ps1 -Mode fast

  # Full test suite with report
  pwsh -NoProfile -File scripts/ollama-executor/Run-AllTests.ps1 -Mode full -GenerateReport

  # CI/CD mode
  pwsh -NoProfile -File scripts/ollama-executor/Run-AllTests.ps1 -Mode full -CI
#>

[CmdletBinding()]
param(
    [ValidateSet('fast', 'full', 'security', 'performance')]
    [string]$Mode = 'fast',
    
    [switch]$GenerateReport,
    
    [switch]$CI,
    
    [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
    [string]$LogLevel = 'Info'
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#region === LOAD TEST HARNESS MODULES ===

# Load all harness modules in dependency order
$harnessModules = @(
    'TestHarness-Config.ps1',
    'TestHarness-Logging.ps1',
    'TestHarness-ErrorHandler.ps1',
    'TestHarness-Reporter.ps1',
    'TestHarness-Executor.ps1',
    'TestHarness-Sequencer.ps1'
)

foreach ($module in $harnessModules) {
    $modulePath = Join-Path $PSScriptRoot $module
    if (Test-Path $modulePath) {
        . $modulePath
    } else {
        Write-Error "Required module not found: $module"
        exit 99
    }
}

#endregion

#region === EXECUTE TEST SEQUENCE ===

$sequenceResult = Invoke-FullTestSequence `
    -Mode $Mode `
    -CI:$CI `
    -GenerateReport:$GenerateReport `
    -LogLevel $LogLevel

#endregion

#region === EXIT ===

exit $sequenceResult.ExitCode

#endregion
