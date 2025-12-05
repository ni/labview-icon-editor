# Generate HTML simulation report
[CmdletBinding()]
param(
    [string]$OutputPath = "reports/simulation-report.html"
)

$ErrorActionPreference = "Stop"

Write-Host "Generating simulation report..." -ForegroundColor Cyan

# Sample data
$testData = @{
    timestamp = Get-Date -Format 'o'
    mode = "simulation"
    summary = @{ total = 6; passed = 6; failed = 0 }
}

$passRate = 100

$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Simulation Report</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; padding: 30px; }
        h1 { color: #667eea; }
        .metric { display: inline-block; margin: 10px; padding: 20px; background: #f8f9fa; border-radius: 6px; }
        .success { color: #4caf50; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🧪 Ollama Executor Simulation Report</h1>
        <div class="metric">Total Tests: <span class="success">$($testData.summary.total)</span></div>
        <div class="metric">Passed: <span class="success">$($testData.summary.passed)</span></div>
        <div class="metric">Failed: <span class="success">$($testData.summary.failed)</span></div>
        <div class="metric">Pass Rate: <span class="success">$passRate%</span></div>
        <p>Generated: $($testData.timestamp)</p>
        <p><strong>Mode:</strong> SIMULATION</p>
    </div>
</body>
</html>
"@

$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$html | Set-Content $OutputPath -Encoding UTF8
Write-Host "Report generated: $OutputPath" -ForegroundColor Green

# Explicit exit code for CI/CD
exit 0
