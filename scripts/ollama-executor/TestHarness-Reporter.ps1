<#
.SYNOPSIS
  Test Harness Reporter - Report generation for test results.

.DESCRIPTION
  Generates test reports in multiple formats: JSON, HTML, JUnit XML.
  Provides detailed test result visualization and CI/CD integration.
  Similar to TestStand's report generation functionality.

.NOTES
  Part of the Ollama Executor Test Harness Framework.
#>

# Prevent direct execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Error "This script should be dot-sourced, not executed directly."
    exit 1
}

#region === REPORT STATE ===

$script:ReportState = @{
    Results = $null
    GeneratedReports = [System.Collections.ArrayList]::new()
    ReportDirectory = 'reports/test-results'
}

#endregion

#region === REPORT INITIALIZATION ===

function Initialize-TestReporter {
    <#
    .SYNOPSIS
      Initializes the reporter with test results.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Results,
        
        [string]$ReportDirectory = 'reports/test-results'
    )
    
    $script:ReportState.Results = $Results
    $script:ReportState.ReportDirectory = $ReportDirectory
    $script:ReportState.GeneratedReports.Clear()
    
    # Ensure report directory exists
    if (-not (Test-Path $ReportDirectory)) {
        New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null
    }
}

#endregion

#region === JSON REPORT ===

function Export-TestResultsJson {
    <#
    .SYNOPSIS
      Exports test results to JSON format.
    #>
    param(
        [string]$FilePath = $null
    )
    
    if (-not $script:ReportState.Results) {
        Write-TestLog "No test results to export" -Level Warning
        return $null
    }
    
    if (-not $FilePath) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $FilePath = Join-Path $script:ReportState.ReportDirectory "test-results-$timestamp.json"
    }
    
    try {
        $jsonContent = $script:ReportState.Results | ConvertTo-Json -Depth 10
        Set-Content -Path $FilePath -Value $jsonContent -Encoding UTF8
        
        $script:ReportState.GeneratedReports.Add(@{
            Type = 'JSON'
            Path = $FilePath
            Timestamp = Get-Date
        }) | Out-Null
        
        Write-TestLog "JSON report saved: $FilePath" -Level Success
        return $FilePath
    }
    catch {
        Write-TestLog "Failed to export JSON report: $($_.Exception.Message)" -Level Error
        return $null
    }
}

#endregion

#region === JUNIT XML REPORT ===

function Export-TestResultsJUnit {
    <#
    .SYNOPSIS
      Exports test results to JUnit XML format for CI/CD integration.
    #>
    param(
        [string]$FilePath = $null
    )
    
    if (-not $script:ReportState.Results) {
        Write-TestLog "No test results to export" -Level Warning
        return $null
    }
    
    if (-not $FilePath) {
        $FilePath = Join-Path $script:ReportState.ReportDirectory "junit-results.xml"
    }
    
    try {
        $results = $script:ReportState.Results
        
        # Build XML using proper escaping
        $xml = [System.Text.StringBuilder]::new()
        $xml.AppendLine("<?xml version='1.0' encoding='UTF-8'?>") | Out-Null
        $xml.AppendLine("<testsuites tests='$($results.summary.total)' failures='$($results.summary.failed)' errors='0' time='$($results.summary.duration_seconds)'>") | Out-Null
        $xml.AppendLine("  <testsuite name='OllamaExecutorTests' tests='$($results.summary.total)' failures='$($results.summary.failed)' errors='0' time='$($results.summary.duration_seconds)' timestamp='$($results.timestamp)'>") | Out-Null
        
        foreach ($suite in $results.suites) {
            $escapedName = [System.Security.SecurityElement]::Escape($suite.name)
            $xml.AppendLine("    <testcase name='$escapedName' classname='OllamaExecutor' time='$($suite.duration_seconds)'>") | Out-Null
            
            if (-not $suite.passed) {
                $failureType = if ($suite.error) { 'Error' } else { 'Failure' }
                $failureMessage = if ($suite.error) { 
                    [System.Security.SecurityElement]::Escape($suite.error) 
                } else { 
                    "Exit code: $($suite.exit_code)" 
                }
                $xml.AppendLine("      <failure message='Test suite failed' type='$failureType'>$failureMessage</failure>") | Out-Null
            }
            
            if ($suite.status -eq 'Skipped') {
                $xml.AppendLine("      <skipped message='Test skipped'/>") | Out-Null
            }
            
            $xml.AppendLine("    </testcase>") | Out-Null
        }
        
        $xml.AppendLine("  </testsuite>") | Out-Null
        $xml.AppendLine("</testsuites>") | Out-Null
        
        Set-Content -Path $FilePath -Value $xml.ToString() -Encoding UTF8
        
        $script:ReportState.GeneratedReports.Add(@{
            Type = 'JUnit'
            Path = $FilePath
            Timestamp = Get-Date
        }) | Out-Null
        
        Write-TestLog "JUnit XML report saved: $FilePath" -Level Success
        return $FilePath
    }
    catch {
        Write-TestLog "Failed to export JUnit report: $($_.Exception.Message)" -Level Error
        return $null
    }
}

#endregion

#region === HTML REPORT ===

function Export-TestResultsHtml {
    <#
    .SYNOPSIS
      Exports test results to HTML format with visualization.
    #>
    param(
        [string]$FilePath = $null,
        [switch]$IncludeOutput
    )
    
    if (-not $script:ReportState.Results) {
        Write-TestLog "No test results to export" -Level Warning
        return $null
    }
    
    if (-not $FilePath) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $FilePath = Join-Path $script:ReportState.ReportDirectory "test-report-$timestamp.html"
    }
    
    try {
        $results = $script:ReportState.Results
        $passRate = if ($results.summary.total -gt 0) { 
            [math]::Round(($results.summary.passed / $results.summary.total) * 100, 1) 
        } else { 0 }
        
        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ollama Executor Test Report</title>
    <style>
        :root {
            --pass-color: #28a745;
            --fail-color: #dc3545;
            --warn-color: #ffc107;
            --info-color: #17a2b8;
            --bg-color: #f8f9fa;
            --card-bg: #ffffff;
            --text-color: #333;
            --border-color: #dee2e6;
        }
        
        * { box-sizing: border-box; margin: 0; padding: 0; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: var(--bg-color);
            color: var(--text-color);
            line-height: 1.6;
            padding: 20px;
        }
        
        .container { max-width: 1200px; margin: 0 auto; }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        
        .header h1 { font-size: 2em; margin-bottom: 10px; }
        .header .meta { opacity: 0.9; font-size: 0.9em; }
        
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .metric {
            background: var(--card-bg);
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
        }
        
        .metric-value {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .metric-label { color: #666; font-size: 0.9em; }
        .metric.passed .metric-value { color: var(--pass-color); }
        .metric.failed .metric-value { color: var(--fail-color); }
        
        .progress-bar {
            height: 10px;
            background: var(--border-color);
            border-radius: 5px;
            overflow: hidden;
            margin-top: 10px;
        }
        
        .progress-fill {
            height: 100%;
            background: var(--pass-color);
            transition: width 0.3s ease;
        }
        
        .suites { margin-top: 30px; }
        .suites h2 { margin-bottom: 20px; }
        
        .suite {
            background: var(--card-bg);
            border-radius: 10px;
            margin-bottom: 15px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .suite-header {
            padding: 15px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-left: 4px solid var(--border-color);
        }
        
        .suite.pass .suite-header { border-left-color: var(--pass-color); }
        .suite.fail .suite-header { border-left-color: var(--fail-color); }
        .suite.skip .suite-header { border-left-color: var(--warn-color); }
        
        .suite-name { font-weight: 600; }
        .suite-status { padding: 5px 10px; border-radius: 15px; font-size: 0.8em; }
        .suite.pass .suite-status { background: #d4edda; color: var(--pass-color); }
        .suite.fail .suite-status { background: #f8d7da; color: var(--fail-color); }
        .suite.skip .suite-status { background: #fff3cd; color: #856404; }
        
        .suite-details {
            padding: 15px 20px;
            background: #f8f9fa;
            font-size: 0.9em;
            border-top: 1px solid var(--border-color);
        }
        
        .suite-output {
            background: #1e1e1e;
            color: #d4d4d4;
            padding: 15px;
            border-radius: 5px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 0.85em;
            max-height: 300px;
            overflow-y: auto;
            white-space: pre-wrap;
            margin-top: 10px;
        }
        
        .footer {
            text-align: center;
            padding: 20px;
            color: #666;
            font-size: 0.85em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 Ollama Executor Test Report</h1>
            <div class="meta">
                <span>Mode: <strong>$($results.mode)</strong></span> |
                <span>Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))</span> |
                <span>Duration: <strong>$($results.summary.duration_seconds)s</strong></span>
            </div>
        </div>
        
        <div class="summary">
            <div class="metric">
                <div class="metric-value">$($results.summary.total)</div>
                <div class="metric-label">Total Tests</div>
            </div>
            <div class="metric passed">
                <div class="metric-value">$($results.summary.passed)</div>
                <div class="metric-label">Passed</div>
            </div>
            <div class="metric failed">
                <div class="metric-value">$($results.summary.failed)</div>
                <div class="metric-label">Failed</div>
            </div>
            <div class="metric">
                <div class="metric-value">$passRate%</div>
                <div class="metric-label">Pass Rate</div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $passRate%"></div>
                </div>
            </div>
        </div>
        
        <div class="suites">
            <h2>Test Suites</h2>
"@

        foreach ($suite in $results.suites) {
            $statusClass = if ($suite.passed) { 'pass' } elseif ($suite.status -eq 'Skipped') { 'skip' } else { 'fail' }
            $statusText = if ($suite.passed) { '✓ PASSED' } elseif ($suite.status -eq 'Skipped') { '⊘ SKIPPED' } else { '✗ FAILED' }
            $escapedName = [System.Web.HttpUtility]::HtmlEncode($suite.name)
            
            $html += @"
            <div class="suite $statusClass">
                <div class="suite-header">
                    <span class="suite-name">$escapedName</span>
                    <span class="suite-status">$statusText ($($suite.duration_seconds)s)</span>
                </div>
                <div class="suite-details">
                    <div>Script: <code>$($suite.script)</code></div>
                    <div>Exit Code: $($suite.exit_code)</div>
"@
            
            if ($IncludeOutput -and $suite.output) {
                $escapedOutput = [System.Web.HttpUtility]::HtmlEncode($suite.output)
                $html += @"
                    <div class="suite-output">$escapedOutput</div>
"@
            }
            
            $html += @"
                </div>
            </div>
"@
        }

        $html += @"
        </div>
        
        <div class="footer">
            Generated by Ollama Executor Test Harness v$($script:TestHarnessConfig.Version)
        </div>
    </div>
</body>
</html>
"@

        Set-Content -Path $FilePath -Value $html -Encoding UTF8
        
        $script:ReportState.GeneratedReports.Add(@{
            Type = 'HTML'
            Path = $FilePath
            Timestamp = Get-Date
        }) | Out-Null
        
        Write-TestLog "HTML report saved: $FilePath" -Level Success
        return $FilePath
    }
    catch {
        Write-TestLog "Failed to export HTML report: $($_.Exception.Message)" -Level Error
        return $null
    }
}

#endregion

#region === CONSOLE REPORT ===

function Write-TestResultsConsole {
    <#
    .SYNOPSIS
      Writes a formatted test results summary to the console.
    #>
    
    if (-not $script:ReportState.Results) {
        Write-TestLog "No test results to display" -Level Warning
        return
    }
    
    $results = $script:ReportState.Results
    
    Write-TestLog "" -NoTimestamp
    Write-TestHeader "Test Results"
    
    foreach ($suite in $results.suites) {
        $status = if ($suite.passed) { $script:TestStatus.Passed } 
                  elseif ($suite.status -eq 'Skipped') { $script:TestStatus.Skipped }
                  else { $script:TestStatus.Failed }
        
        Write-TestStatus -TestName $suite.name -Status $status -Duration $suite.duration_seconds
    }
    
    Write-TestSummary `
        -Total $results.summary.total `
        -Passed $results.summary.passed `
        -Failed $results.summary.failed `
        -Skipped $results.summary.skipped `
        -Duration $results.summary.duration_seconds
}

#endregion

#region === REPORT UTILITIES ===

function Get-GeneratedReports {
    <#
    .SYNOPSIS
      Returns list of generated reports.
    #>
    return $script:ReportState.GeneratedReports.ToArray()
}

function Export-AllReports {
    <#
    .SYNOPSIS
      Exports all configured report types.
    #>
    param(
        [switch]$Json,
        [switch]$Html,
        [switch]$JUnit,
        [switch]$IncludeOutput
    )
    
    $reports = @()
    
    if ($Json -or $script:TestHarnessConfig.EnableJsonReport) {
        $path = Export-TestResultsJson
        if ($path) { $reports += $path }
    }
    
    if ($Html -or $script:TestHarnessConfig.EnableHtmlReport) {
        $path = Export-TestResultsHtml -IncludeOutput:$IncludeOutput
        if ($path) { $reports += $path }
    }
    
    if ($JUnit -or $script:TestHarnessConfig.EnableJUnitReport) {
        $path = Export-TestResultsJUnit
        if ($path) { $reports += $path }
    }
    
    return $reports
}

#endregion
