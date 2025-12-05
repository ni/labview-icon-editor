<#
.SYNOPSIS
    Test VI Metadata Simulator functionality.

.DESCRIPTION
    Validates SimulateVIMetadata.ps1 with various VI files and scenarios.

.EXAMPLE
    pwsh -NoProfile -File Test-VIMetadata.ps1
#>

param()

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== VI Metadata Tests ===" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0
$total = 0

function Test-Case {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    $script:total++
    Write-Host "Test $script:total: $Name" -NoNewline
    
    try {
        & $Test
        Write-Host " ✓ PASS" -ForegroundColor Green
        $script:passed++
    }
    catch {
        Write-Host " ✗ FAIL: $_" -ForegroundColor Red
        $script:failed++
    }
}

# Test 1: Script exists and is executable
Test-Case "SimulateVIMetadata.ps1 exists" {
    $scriptPath = Join-Path $scriptDir "SimulateVIMetadata.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "Script not found"
    }
}

# Test 2: Compatibility matrix exists
Test-Case "vi-compatibility-matrix.json exists" {
    $matrixPath = Join-Path $scriptDir "vi-compatibility-matrix.json"
    if (-not (Test-Path $matrixPath)) {
        throw "Compatibility matrix not found"
    }
}

# Test 3: Compatibility matrix is valid JSON
Test-Case "vi-compatibility-matrix.json is valid JSON" {
    $matrixPath = Join-Path $scriptDir "vi-compatibility-matrix.json"
    $null = Get-Content $matrixPath | ConvertFrom-Json
}

# Test 4: API deprecations exists
Test-Case "api-deprecations.json exists" {
    $deprecPath = Join-Path $scriptDir "api-deprecations.json"
    if (-not (Test-Path $deprecPath)) {
        throw "API deprecations not found"
    }
}

# Test 5: API deprecations is valid JSON
Test-Case "api-deprecations.json is valid JSON" {
    $deprecPath = Join-Path $scriptDir "api-deprecations.json"
    $null = Get-Content $deprecPath | ConvertFrom-Json
}

# Test 6: Find a real VI file to test with
$testVI = $null
$viSearchPaths = @(
    (Join-Path $scriptDir "../../resource/plugins/*.vi"),
    (Join-Path $scriptDir "../../scripts/missing-in-project/*.vi")
)

foreach ($searchPath in $viSearchPaths) {
    $vis = Get-ChildItem -Path $searchPath -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($vis) {
        $testVI = $vis.FullName
        break
    }
}

if ($testVI) {
    Test-Case "Can extract metadata from real VI: $(Split-Path -Leaf $testVI)" {
        $result = & (Join-Path $scriptDir "SimulateVIMetadata.ps1") -VIPath $testVI -OutputFormat json 2>&1 | Out-String
        if ($result -notmatch '"vi_name"') {
            throw "Output doesn't contain expected metadata"
        }
    }
    
    Test-Case "Metadata contains required fields" {
        $jsonOutput = & (Join-Path $scriptDir "SimulateVIMetadata.ps1") -VIPath $testVI -OutputFormat json 2>&1 | Where-Object { $_ -match '^\s*{' } | Out-String
        $metadata = $jsonOutput | ConvertFrom-Json
        
        $requiredFields = @('vi_name', 'lv_version', 'lv_version_normalized', 'compatibility')
        foreach ($field in $requiredFields) {
            if (-not $metadata.PSObject.Properties[$field]) {
                throw "Missing required field: $field"
            }
        }
    }
}
else {
    Write-Host "Warning: No VI files found for testing" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Total:  $total"
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failed -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed" -ForegroundColor Red
    exit 1
}
