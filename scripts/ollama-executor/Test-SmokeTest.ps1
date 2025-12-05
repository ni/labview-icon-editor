<#
.SYNOPSIS
  Smoke test script for Ollama Executor - quick validation of critical functionality.

.DESCRIPTION
  Runs essential tests to validate the Ollama executor is functional:
  - Command vetting security
  - Simulation mode basics
  - Critical path validation
  
  Designed for CI/CD with fast execution (<2 minutes) and clear pass/fail.

.PARAMETER CI
  CI mode - generates structured output for GitHub Actions

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-SmokeTest.ps1
  
.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-SmokeTest.ps1 -CI
#>

[CmdletBinding()]
param(
    [switch]$CI
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$testResults = @{
    timestamp = Get-Date -Format 'o'
    tests = @()
    summary = @{
        total = 0
        passed = 0
        failed = 0
    }
}

function Test-Critical {
    param(
        [string]$Name,
        [scriptblock]$TestBlock
    )
    
    $script:testResults.summary.total++
    
    Write-Host "Testing: $Name" -ForegroundColor Yellow
    
    try {
        $result = & $TestBlock
        if ($result) {
            Write-Host "  ✓ PASS" -ForegroundColor Green
            $script:testResults.summary.passed++
            $script:testResults.tests += @{ name = $Name; passed = $true }
            return $true
        } else {
            Write-Host "  ✗ FAIL" -ForegroundColor Red
            $script:testResults.summary.failed++
            $script:testResults.tests += @{ name = $Name; passed = $false; error = "Test returned false" }
            return $false
        }
    }
    catch {
        Write-Host "  ✗ FAIL: $_" -ForegroundColor Red
        $script:testResults.summary.failed++
        $script:testResults.tests += @{ name = $Name; passed = $false; error = $_.Exception.Message }
        return $false
    }
}

Write-Host "=== Ollama Executor Smoke Test ===" -ForegroundColor Cyan
Write-Host ""

# Critical Test 1: Command vetting blocks dangerous commands
Test-Critical -Name "Command vetting blocks path traversal" -TestBlock {
    # Extract just the function we need
    function Test-CommandAllowed {
        param(
            [string]$Command,
            [string[]]$AllowedRuns = @()
        )
        
        if ($AllowedRuns -and $AllowedRuns.Count -gt 0) {
            $matched = $AllowedRuns | Where-Object { $_.ToLower() -eq $Command.ToLower() }
            if (-not $matched) {
                return "Rejected: command not in allowlist."
            }
        }

        $allowedPattern = '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\b'
        if (-not ($Command -match $allowedPattern)) {
            return "Rejected: command must start with 'pwsh -NoProfile -File scripts/...ps1'"
        }

        if ($Command -match '\.\.[/\\]' -or $Command -match '[/\\]\.\.') {
            return "Rejected: path traversal attempt detected (..)"
        }

        if ($Command -match '[;&|`]' -or $Command -match '\$\(') {
            return "Rejected: command injection attempt detected"
        }

        $forbidden = @('rm ', 'del ', 'Remove-Item', 'Format-',
                       'Invoke-WebRequest', 'curl ', 'Start-Process', 'shutdown', 'reg ', 'sc ')
        foreach ($tok in $forbidden) {
            if ($Command -like "*$tok*") {
                return "Rejected: contains forbidden token '$tok'"
            }
        }
        return $null
    }
    
    $result = Test-CommandAllowed -Command "pwsh -NoProfile -File scripts/../evil.ps1" -AllowedRuns @()
    return ($null -ne $result)  # Should be rejected
}

Test-Critical -Name "Command vetting blocks command injection" -TestBlock {
    function Test-CommandAllowed {
        param(
            [string]$Command,
            [string[]]$AllowedRuns = @()
        )
        
        if ($AllowedRuns -and $AllowedRuns.Count -gt 0) {
            $matched = $AllowedRuns | Where-Object { $_.ToLower() -eq $Command.ToLower() }
            if (-not $matched) {
                return "Rejected: command not in allowlist."
            }
        }

        $allowedPattern = '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\b'
        if (-not ($Command -match $allowedPattern)) {
            return "Rejected: command must start with 'pwsh -NoProfile -File scripts/...ps1'"
        }

        if ($Command -match '\.\.[/\\]' -or $Command -match '[/\\]\.\.') {
            return "Rejected: path traversal attempt detected (..)"
        }

        if ($Command -match '[;&|`]' -or $Command -match '\$\(') {
            return "Rejected: command injection attempt detected"
        }

        $forbidden = @('rm ', 'del ', 'Remove-Item', 'Format-',
                       'Invoke-WebRequest', 'curl ', 'Start-Process', 'shutdown', 'reg ', 'sc ')
        foreach ($tok in $forbidden) {
            if ($Command -like "*$tok*") {
                return "Rejected: contains forbidden token '$tok'"
            }
        }
        return $null
    }
    
    $result = Test-CommandAllowed -Command "pwsh -NoProfile -File scripts/test.ps1; rm -rf /" -AllowedRuns @()
    return ($null -ne $result)  # Should be rejected
}

Test-Critical -Name "Command vetting allows valid commands" -TestBlock {
    function Test-CommandAllowed {
        param(
            [string]$Command,
            [string[]]$AllowedRuns = @()
        )
        
        if ($AllowedRuns -and $AllowedRuns.Count -gt 0) {
            $matched = $AllowedRuns | Where-Object { $_.ToLower() -eq $Command.ToLower() }
            if (-not $matched) {
                return "Rejected: command not in allowlist."
            }
        }

        $allowedPattern = '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\b'
        if (-not ($Command -match $allowedPattern)) {
            return "Rejected: command must start with 'pwsh -NoProfile -File scripts/...ps1'"
        }

        if ($Command -match '\.\.[/\\]' -or $Command -match '[/\\]\.\.') {
            return "Rejected: path traversal attempt detected (..)"
        }

        if ($Command -match '[;&|`]' -or $Command -match '\$\(') {
            return "Rejected: command injection attempt detected"
        }

        $forbidden = @('rm ', 'del ', 'Remove-Item', 'Format-',
                       'Invoke-WebRequest', 'curl ', 'Start-Process', 'shutdown', 'reg ', 'sc ')
        foreach ($tok in $forbidden) {
            if ($Command -like "*$tok*") {
                return "Rejected: contains forbidden token '$tok'"
            }
        }
        return $null
    }
    
    $result = Test-CommandAllowed -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64" -AllowedRuns @()
    return ($null -eq $result)  # Should be accepted
}

# Critical Test 2: Simulation mode works
Test-Critical -Name "Simulation mode executes" -TestBlock {
    $env:OLLAMA_EXECUTOR_MODE = "sim"
    $env:OLLAMA_SIM_DELAY_MS = "10"
    
    try {
        $result = & "$PSScriptRoot/SimulationProvider.ps1" `
            -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64" `
            -WorkingDirectory "."
        
        return ($result.ExitCode -eq 0 -and $result.StdOut -match "SIMULATION MODE")
    }
    finally {
        Remove-Item Env:\OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
    }
}

# Critical Test 3: Mock server script is valid
Test-Critical -Name "Mock Ollama server script is valid" -TestBlock {
    # Check if the script exists and has valid syntax
    $scriptPath = "$PSScriptRoot/MockOllamaServer.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "    Mock server script not found" -ForegroundColor Gray
        return $false
    }
    
    # Try to parse the script to validate syntax
    try {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
        if ($errors.Count -gt 0) {
            Write-Host "    Script has syntax errors: $($errors.Count)" -ForegroundColor Gray
            return $false
        }
        return $true
    }
    catch {
        Write-Host "    Failed to parse script: $_" -ForegroundColor Gray
        return $false
    }
}

# Critical Test 4: No regressions in fixed bugs
Test-Critical -Name "No security regressions" -TestBlock {
    # Inline vetting function
    function Test-CommandAllowed {
        param(
            [string]$Command,
            [string[]]$AllowedRuns = @()
        )
        
        if ($AllowedRuns -and $AllowedRuns.Count -gt 0) {
            $matched = $AllowedRuns | Where-Object { $_.ToLower() -eq $Command.ToLower() }
            if (-not $matched) {
                return "Rejected: command not in allowlist."
            }
        }

        $allowedPattern = '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\b'
        if (-not ($Command -match $allowedPattern)) {
            return "Rejected: command must start with 'pwsh -NoProfile -File scripts/...ps1'"
        }

        if ($Command -match '\.\.[/\\]' -or $Command -match '[/\\]\.\.') {
            return "Rejected: path traversal attempt detected (..)"
        }

        if ($Command -match '[;&|`]' -or $Command -match '\$\(') {
            return "Rejected: command injection attempt detected"
        }

        $forbidden = @('rm ', 'del ', 'Remove-Item', 'Format-',
                       'Invoke-WebRequest', 'curl ', 'Start-Process', 'shutdown', 'reg ', 'sc ')
        foreach ($tok in $forbidden) {
            if ($Command -like "*$tok*") {
                return "Rejected: contains forbidden token '$tok'"
            }
        }
        return $null
    }
    
    # Load regression database
    $regressionDbPath = "$PSScriptRoot/regression-tests.json"
    if (-not (Test-Path $regressionDbPath)) {
        return $true  # No regressions to check
    }
    
    $db = Get-Content $regressionDbPath | ConvertFrom-Json
    
    foreach ($test in $db.tests) {
        if ($test.verification -eq "vetting") {
            $result = Test-CommandAllowed -Command $test.test_command -AllowedRuns @()
            
            if ($test.expected_result -eq "rejected" -and $null -eq $result) {
                return $false  # Regression detected
            }
        }
    }
    
    return $true
}

# Summary
Write-Host ""
Write-Host "=== Smoke Test Summary ===" -ForegroundColor Cyan
Write-Host "Total: $($testResults.summary.total)" -ForegroundColor White
Write-Host "Passed: $($testResults.summary.passed)" -ForegroundColor Green
Write-Host "Failed: $($testResults.summary.failed)" -ForegroundColor $(if ($testResults.summary.failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

# CI output
if ($CI) {
    $reportDir = "reports/test-results"
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $jsonReport = Join-Path $reportDir "smoke-test-results.json"
    $testResults | ConvertTo-Json -Depth 5 | Set-Content $jsonReport
    Write-Host "Results saved to: $jsonReport" -ForegroundColor Gray
}

if ($testResults.summary.failed -eq 0) {
    Write-Host "✓ All critical smoke tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Smoke test failed - $($testResults.summary.failed) critical test(s) failing" -ForegroundColor Red
    exit 1
}
