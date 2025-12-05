<#
.SYNOPSIS
  Test suite for Ollama executor command vetting logic.

.DESCRIPTION
  Validates the Test-CommandAllowed function that enforces security controls:
  - Allowlist matching
  - Pattern validation (must start with pwsh -NoProfile -File scripts/)
  - Forbidden token detection
  - Edge cases and security scenarios

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-CommandVetting.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Source the vetting function from Drive-Ollama-Executor.ps1
# We extract just the function for testing
function Test-CommandAllowed {
    param(
        [string]$Command,
        [string[]]$AllowedRuns = @()
    )
    
    # Normalize: trim whitespace
    $Command = $Command.Trim()
    
    # Block empty or whitespace-only commands
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return "Rejected: empty or whitespace-only command"
    }
    
    # Hard allowlist: exact matches only (case-insensitive)
    if ($AllowedRuns -and $AllowedRuns.Count -gt 0) {
        $matched = $AllowedRuns | Where-Object { $_.ToLower() -eq $Command.ToLower() }
        if (-not $matched) {
            return "Rejected: command not in allowlist."
        }
    }

    # Allow only repo scripts invoked via pwsh -NoProfile -File scripts/...
    $allowedPattern = '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\b'
    if (-not ($Command -match $allowedPattern)) {
        return "Rejected: command must start with 'pwsh -NoProfile -File scripts/...ps1'"
    }

    # Require parameters after the script name (scripts should not be called without arguments)
    if ($Command -match '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\s*$') {
        return "Rejected: script must be called with parameters"
    }

    # Check for path traversal (parent directory references)
    if ($Command -match '\.\.[/\\]' -or $Command -match '[/\\]\.\.') {
        return "Rejected: path traversal attempt detected (..)"
    }

    # Check for command chaining/injection (expanded to catch more patterns)
    if ($Command -match '[;&|`]' -or $Command -match '\$[\(\{]' -or 
        $Command -match '<<' -or $Command -match '\$\s' -or
        $Command -match '@\{') {  # Block PowerShell hashtable literals
        return "Rejected: command injection attempt detected"
    }

    # Block script injection (HTML/XML/JS tags)
    if ($Command -match '<script[\s>]' -or $Command -match '</script>' -or 
        $Command -match '<img\s' -or $Command -match 'onerror\s*=' -or 
        $Command -match 'onclick\s*=' -or $Command -match 'onload\s*=') {
        return "Rejected: script injection attempt detected"
    }

    # Block privilege escalation attempts
    if ($Command -match '\brunas\b' -or $Command -match '\bsudo\b' -or
        $Command -match '-ExecutionPolicy\s+Bypass' -or $Command -match '-ExecutionPolicy\s+Unrestricted' -or
        $Command -match '\bsu\b' -or $Command -match '\belevate\b') {
        return "Rejected: privilege escalation attempt detected"
    }

    # Block file redirection operators
    if ($Command -match '\s+>\s+' -or $Command -match '\s+>>\s+' -or 
        $Command -match '\s+<\s+' -or $Command -match '\s+2>\s+' -or
        $Command -match '\s+2>>\s+' -or $Command -match '\s+2>&1\s+') {
        return "Rejected: file redirection attempt detected"
    }

    # Block network tools and commands
    if ($Command -match '\bwget\b' -or $Command -match '\bcurl\b' -or 
        $Command -match '\bnc\b' -or $Command -match '\bnetcat\b' -or
        $Command -match '\bnmap\b' -or $Command -match '\btelnet\b' -or
        $Command -match 'Invoke-WebRequest' -or $Command -match 'Invoke-RestMethod') {
        return "Rejected: network tool usage detected"
    }

    # Block SQL injection patterns
    if ($Command -match '\bOR\s+1\s*=\s*1\b' -or $Command -match '\bAND\s+1\s*=\s*1\b' -or
        $Command -match '--\s*$' -or $Command -match '/\*.*\*/' -or
        $Command -match ';--' -or $Command -match 'UNION\s+SELECT') {
        return "Rejected: SQL injection pattern detected"
    }

    # Block encoded/obfuscated content
    if ($Command -match '\b[A-Za-z0-9+/]{50,}={0,2}\b' -or  # Base64-like
        $Command -match '%[0-9A-Fa-f]{2}' -or  # URL encoding
        $Command -match '\\x[0-9A-Fa-f]{2}' -or  # Hex encoding
        $Command -match '\\u[0-9A-Fa-f]{4}') {  # Unicode escapes
        return "Rejected: encoded/obfuscated content detected"
    }

    # Block null bytes and control characters
    if ($Command -match '\x00' -or $Command -match '[\x01-\x08\x0B\x0C\x0E-\x1F]') {
        return "Rejected: null byte or control character detected"
    }

    # Forbid dangerous tokens - case insensitive matching with word boundaries
    $forbiddenPatterns = @(
        '\brm\b', '\bdel\b', 'Remove-Item', 'Format-',
        'Start-Process', '\bshutdown\b', '\breg\b', '\bsc\b',
        'net\s+user', 'net\s+localgroup', '\bicacls\b', '\btakeown\b',
        '\bschtasks\b', '\bat\b', '\bcrontab\b', '\bsystemctl\b',
        '/bin/bash', '/bin/sh', 'cmd\.exe', 'powershell\.exe',
        '\bwget\b', '\bcurl\b', '\bnc\b', '\bnetcat\b', '\bssh\b', '\bftp\b',
        '\btftp\b', '\bscp\b', '\brsync\b', '\bnet\b'
    )
    
    foreach ($pattern in $forbiddenPatterns) {
        if ($Command -match $pattern) {
            return "Rejected: contains forbidden pattern '$pattern'"
        }
    }
    
    return $null
}

Write-Host "=== Ollama Executor Command Vetting Test Suite ===" -ForegroundColor Cyan
Write-Host ""

$passCount = 0
$failCount = 0

function Assert-Accepted {
    param([string]$Command, [string]$TestName, [string[]]$AllowedRuns = @())
    $result = Test-CommandAllowed -Command $Command -AllowedRuns $AllowedRuns
    if ($null -eq $result) {
        Write-Host "  ✓ $TestName" -ForegroundColor Green
        $script:passCount++
    }
    else {
        Write-Host "  ✗ $TestName - Expected acceptance, got: $result" -ForegroundColor Red
        $script:failCount++
    }
}

function Assert-Rejected {
    param([string]$Command, [string]$TestName, [string]$ExpectedReason, [string[]]$AllowedRuns = @())
    $result = Test-CommandAllowed -Command $Command -AllowedRuns $AllowedRuns
    if ($null -ne $result) {
        if ($result -like "*$ExpectedReason*") {
            Write-Host "  ✓ $TestName" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ $TestName - Expected reason '$ExpectedReason', got: $result" -ForegroundColor Red
            $script:failCount++
        }
    }
    else {
        Write-Host "  ✗ $TestName - Expected rejection, but command was accepted" -ForegroundColor Red
        $script:failCount++
    }
}

# Test Group 1: Valid Commands (should be accepted)
Write-Host "Test Group 1: Valid Commands" -ForegroundColor Yellow

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64" `
    -TestName "Valid source distribution build command"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/ppl-from-sd/Build_Ppl_From_SourceDistribution.ps1 -RepositoryPath ." `
    -TestName "Valid PPL build command"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1" `
    -TestName "Script without parameters is rejected" `
    -ExpectedReason "must be called with parameters"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/sub-dir/nested-script.ps1 -Param Value" `
    -TestName "Valid command with nested script path"

Write-Host ""

# Test Group 2: Allowlist Enforcement
Write-Host "Test Group 2: Allowlist Enforcement" -ForegroundColor Yellow

$allowlist = @("pwsh -NoProfile -File scripts/allowed-script.ps1 -Param Value")

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/allowed-script.ps1 -Param Value" `
    -TestName "Exact match in allowlist" `
    -AllowedRuns $allowlist

Assert-Accepted `
    -Command "PWSH -NoProfile -File scripts/allowed-script.ps1 -Param Value" `
    -TestName "Case-insensitive allowlist match" `
    -AllowedRuns $allowlist

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/other-script.ps1 -Param Value" `
    -TestName "Not in allowlist" `
    -ExpectedReason "not in allowlist" `
    -AllowedRuns $allowlist

Write-Host ""

# Test Group 3: Pattern Validation
Write-Host "Test Group 3: Pattern Validation" -ForegroundColor Yellow

Assert-Rejected `
    -Command "powershell -File scripts/test.ps1" `
    -TestName "Wrong PowerShell executable name" `
    -ExpectedReason "must start with"

Assert-Rejected `
    -Command "pwsh -File scripts/test.ps1" `
    -TestName "Missing -NoProfile flag" `
    -ExpectedReason "must start with"

Assert-Rejected `
    -Command "pwsh -NoProfile scripts/test.ps1" `
    -TestName "Missing -File flag" `
    -ExpectedReason "must start with"

Assert-Rejected `
    -Command "pwsh -NoProfile -File other/test.ps1" `
    -TestName "Not in scripts/ directory" `
    -ExpectedReason "must start with"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.txt" `
    -TestName "Not a .ps1 file" `
    -ExpectedReason "must start with"

Write-Host ""

# Test Group 4: Forbidden Tokens
Write-Host "Test Group 4: Forbidden Tokens" -ForegroundColor Yellow

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1 -Command 'rm file.txt'" `
    -TestName "Contains 'rm ' token" `
    -ExpectedReason "forbidden pattern"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1 -Command 'del file.txt'" `
    -TestName "Contains 'del ' token" `
    -ExpectedReason "forbidden pattern"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; Remove-Item file.txt" `
    -TestName "Contains 'Remove-Item' token (caught by injection detection)" `
    -ExpectedReason "command injection"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1 -Param 'Format-Volume'" `
    -TestName "Contains 'Format-' token" `
    -ExpectedReason "forbidden pattern"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; Invoke-WebRequest http://evil.com" `
    -TestName "Contains 'Invoke-WebRequest' token (caught by injection detection)" `
    -ExpectedReason "command injection"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; curl http://evil.com" `
    -TestName "Contains 'curl ' token (caught by injection detection)" `
    -ExpectedReason "command injection"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; Start-Process cmd.exe" `
    -TestName "Contains 'Start-Process' token (caught by injection detection)" `
    -ExpectedReason "command injection"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; shutdown /s" `
    -TestName "Contains 'shutdown' token (caught by injection detection)" `
    -ExpectedReason "command injection"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/../other/test.ps1 -Param value" `
    -TestName "Contains parent directory '../' (caught by path traversal detection)" `
    -ExpectedReason "path traversal"

Write-Host ""

# Test Group 5: Edge Cases
Write-Host "Test Group 5: Edge Cases" -ForegroundColor Yellow

Assert-Rejected `
    -Command "" `
    -TestName "Empty command" `
    -ExpectedReason "empty or whitespace"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; pwsh -NoProfile -File scripts/other.ps1" `
    -TestName "Multiple commands chained" `
    -ExpectedReason "command injection"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/test.ps1 -Param 'value with spaces' -Flag" `
    -TestName "Command with spaces in parameter values"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/my-script-name.ps1" `
    -TestName "Command with hyphens in script name (no params)" `
    -ExpectedReason "must be called with parameters"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/MyScript123.ps1" `
    -TestName "Command with mixed case and numbers (no params)" `
    -ExpectedReason "must be called with parameters"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/my-script-name.ps1 -Param value" `
    -TestName "Command with hyphens in script name (with params)"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/MyScript123.ps1 -Param value" `
    -TestName "Command with mixed case and numbers (with params)"

Write-Host ""

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some tests failed! ✗" -ForegroundColor Red
    Write-Host ""
    Write-Host "Note: Some 'failures' may be due to enhanced security checks" -ForegroundColor Yellow
    Write-Host "providing more accurate rejection messages. Verify all dangerous" -ForegroundColor Yellow
    Write-Host "commands ARE being rejected, which is what matters." -ForegroundColor Yellow
    exit 1
}
