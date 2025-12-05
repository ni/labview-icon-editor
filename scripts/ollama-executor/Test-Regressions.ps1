<#
.SYNOPSIS
  Regression test framework for tracking and preventing fixed bugs from reappearing.

.DESCRIPTION
  Maintains a database of regression tests for previously-fixed bugs. Each regression
  test includes reproduction steps, expected behavior, and verification. Auto-runs
  all regression tests and fails if any resurface.

.PARAMETER AddRegression
  Add a new regression test interactively

.EXAMPLE
  # Run all regression tests
  pwsh -NoProfile -File scripts/ollama-executor/Test-Regressions.ps1

  # Add new regression test
  pwsh -NoProfile -File scripts/ollama-executor/Test-Regressions.ps1 -AddRegression
#>

[CmdletBinding()]
param(
    [switch]$AddRegression
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$regressionDbPath = "$PSScriptRoot/regression-tests.json"

# Initialize regression database if it doesn't exist
if (-not (Test-Path $regressionDbPath)) {
    $initialDb = @{
        version = "1.0"
        tests = @(
            @{
                id = "REG-001"
                bug_id = "Parent directory traversal not blocked"
                description = "Commands using ..\ or ../ should be rejected"
                added_date = "2025-12-03"
                test_command = "pwsh -NoProfile -File scripts/../other.ps1"
                expected_result = "rejected"
                verification = "vetting"
            }
            @{
                id = "REG-002"
                bug_id = "Command chaining with semicolon not blocked"
                description = "Commands with ; should be rejected to prevent injection"
                added_date = "2025-12-03"
                test_command = "pwsh -NoProfile -File scripts/test.ps1; rm -rf /"
                expected_result = "rejected"
                verification = "vetting"
            }
        )
    }
    $initialDb | ConvertTo-Json -Depth 10 | Set-Content $regressionDbPath
}

Write-Host "=== Regression Test Suite ===" -ForegroundColor Cyan
Write-Host ""

if ($AddRegression) {
    Write-Host "Adding new regression test..." -ForegroundColor Yellow
    Write-Host ""
    
    $db = Get-Content $regressionDbPath | ConvertFrom-Json
    
    # Get next ID
    $maxId = 0
    foreach ($test in $db.tests) {
        if ($test.id -match 'REG-(\d+)') {
            $num = [int]$matches[1]
            if ($num -gt $maxId) { $maxId = $num }
        }
    }
    $newId = "REG-$(($maxId + 1).ToString('000'))"
    
    $bugId = Read-Host "Bug ID/Description"
    $description = Read-Host "Detailed description"
    $testCommand = Read-Host "Test command (or 'scenario' for scenario-based)"
    $expectedResult = Read-Host "Expected result (rejected/accepted/specific behavior)"
    
    $newTest = @{
        id = $newId
        bug_id = $bugId
        description = $description
        added_date = (Get-Date -Format 'yyyy-MM-dd')
        test_command = $testCommand
        expected_result = $expectedResult
        verification = "vetting"
    }
    
    $db.tests += $newTest
    $db | ConvertTo-Json -Depth 10 | Set-Content $regressionDbPath
    
    Write-Host ""
    Write-Host "Regression test $newId added successfully!" -ForegroundColor Green
    exit 0
}

# Load regression database
$db = Get-Content $regressionDbPath | ConvertFrom-Json

Write-Host "Loaded $($db.tests.Count) regression tests from database" -ForegroundColor White
Write-Host ""

# Source vetting function for command tests
. "$PSScriptRoot/Test-CommandVetting.ps1" -ErrorAction SilentlyContinue

$passCount = 0
$failCount = 0
$failures = @()

foreach ($test in $db.tests) {
    Write-Host "[$($test.id)] $($test.bug_id)" -ForegroundColor Yellow
    
    $passed = $false
    
    if ($test.verification -eq "vetting") {
        # Test command vetting
        $result = Test-CommandAllowed -Command $test.test_command -AllowedRuns @()
        
        if ($test.expected_result -eq "rejected") {
            $passed = ($null -ne $result)
            if ($passed) {
                Write-Host "  ✓ PASS - Command properly rejected" -ForegroundColor Green
            }
            else {
                Write-Host "  ✗ REGRESSION - Command was accepted (should be rejected)" -ForegroundColor Red
                $failures += @{
                    id = $test.id
                    bug_id = $test.bug_id
                    reason = "Previously fixed bug has reappeared - command now accepted"
                }
            }
        }
        elseif ($test.expected_result -eq "accepted") {
            $passed = ($null -eq $result)
            if ($passed) {
                Write-Host "  ✓ PASS - Command properly accepted" -ForegroundColor Green
            }
            else {
                Write-Host "  ✗ REGRESSION - Command was rejected (should be accepted)" -ForegroundColor Red
                $failures += @{
                    id = $test.id
                    bug_id = $test.bug_id
                    reason = "Previously fixed bug has reappeared - command now rejected"
                }
            }
        }
    }
    
    if ($passed) {
        $passCount++
    }
    else {
        $failCount++
    }
}

Write-Host ""
Write-Host "=== Regression Test Summary ===" -ForegroundColor Cyan
Write-Host "Total: $($db.tests.Count)" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "=== REGRESSIONS DETECTED ===" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host ""
        Write-Host "[$($failure.id)] $($failure.bug_id)" -ForegroundColor Red
        Write-Host "  $($failure.reason)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "CRITICAL: $failCount regression(s) detected!" -ForegroundColor Red
    Write-Host "Previously fixed bugs have reappeared and must be addressed immediately." -ForegroundColor Red
    exit 1
}
else {
    Write-Host "✓ No regressions detected - all previously fixed bugs remain fixed!" -ForegroundColor Green
    exit 0
}
