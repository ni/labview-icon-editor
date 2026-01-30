<#
.SYNOPSIS
    Run LabVIEW unit tests using g-cli and output a color-coded table of results.

.DESCRIPTION
    Demonstrates a Setup/MainSequence/Cleanup flow with:
      - Table-based test results
      - Color-coded pass/fail
      - Non-zero exit if g-cli fails or if any test fails
      - Requires an explicit LabVIEW project path (-ProjectPath).

.PARAMETER MinimumSupportedLVVersion
    LabVIEW 2021 (21.0) only.

.PARAMETER SupportedBitness
    Bitness for LabVIEW (e.g., "64").

.PARAMETER ProjectPath
    Required path to the LabVIEW project file to execute tests against.

.PARAMETER ReportPath
    Optional path to an existing UnitTestReport.xml. When provided with -SkipGcli,
    parsing runs without invoking g-cli.

.PARAMETER SkipGcli
    Skip running g-cli and only parse an existing report (useful for local testing).

.NOTES
    PowerShell 7.5+ assumed for cross-platform support.
    This script *requires* that g-cli and LabVIEW be compatible with the OS.
#>

[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $true, ParameterSetName = 'ReportOnly')]
    [ValidateSet('2021')]
    [string]
    $MinimumSupportedLVVersion,

    [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $true, ParameterSetName = 'ReportOnly')]
    [ValidateSet("32","64")]
    [string]
    $SupportedBitness,

    [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
    [string]
    $ProjectPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'ReportOnly')]
    [switch]
    $SkipGcli,

    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ReportOnly')]
    [string]
    $ReportPath
)

# Script-level variables to track exit states and results
$Script:OriginalExitCode = 0
$Script:TestsHadFailures = $false
$Script:Results = @()
$Script:FailedResults = @()
$Script:ReportMissing = $false
$Script:ParseError = $null

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path -Path $PSScriptRoot -ChildPath "UnitTestReport.xml"
} else {
    Write-Host "Using report path override: $ReportPath"
}

# --------------------------------------------------------------------
# 1) Resolve the LabVIEW project path
# --------------------------------------------------------------------

$AbsoluteProjectPath = $null

if ($PSCmdlet.ParameterSetName -eq 'Run') {
    if (Test-Path $ProjectPath) {
        $AbsoluteProjectPath = (Resolve-Path -Path $ProjectPath).Path
    } else {
        Write-Warning "Provided ProjectPath does not exist: $ProjectPath"
        $Script:OriginalExitCode = 3
        $Script:TestsHadFailures = $true
        $Script:ParseError = "ProjectPath does not exist: $ProjectPath"
    }
}

$Script:SkipRun = ($PSCmdlet.ParameterSetName -eq 'ReportOnly') -or ($null -eq $AbsoluteProjectPath)

if ($AbsoluteProjectPath) {
    Write-Host "Using LabVIEW project file: $AbsoluteProjectPath"
} else {
    if ($PSCmdlet.ParameterSetName -eq 'ReportOnly') {
        Write-Host "Project path not set; running in report-only mode."
    } else {
        Write-Warning "Project path not set; skipping g-cli run."
    }
}

# --------------------------  SETUP  --------------------------
function Setup {
    Write-Host "=== Setup ==="
    if ($Script:SkipRun) {
        Write-Host "Skipping g-cli run; report-only mode."
        return
    }
    $reportDir = Split-Path -Parent $ReportPath
    if (-not (Test-Path $reportDir)) {
        try {
            New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
            Write-Host "Created report directory: $reportDir"
        }
        catch {
            Write-Warning ("Could not create report directory {0}: {1}" -f $reportDir, $_.Exception.Message)
        }
    }
    if (Test-Path $ReportPath) {
        try {
            Remove-Item $ReportPath -Force -ErrorAction Stop
            Write-Host "Deleted existing UnitTestReport.xml."
        }
        catch {
            Write-Warning "Could not remove UnitTestReport.xml: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "No existing UnitTestReport.xml found. Continuing..."
    }
}

function Parse-Report {
    $Script:Results = @()
    $Script:FailedResults = @()
    $Script:ReportMissing = $false
    $Script:ParseError = $null

    if (-not (Test-Path $ReportPath)) {
        $Script:ReportMissing = $true
        $Script:TestsHadFailures = $true
        return
    }

    try {
        [xml]$xmlDoc = Get-Content $ReportPath -ErrorAction Stop
    }
    catch {
        $Script:ParseError = $_.Exception.Message
        $Script:TestsHadFailures = $true
        return
    }

    $testCases = $xmlDoc.SelectNodes("//testcase")
    if (!$testCases -or $testCases.Count -eq 0) {
        $Script:ParseError = "No <testcase> entries found in UnitTestReport.xml."
        $Script:TestsHadFailures = $true
        return
    }

    $results = @()
    foreach ($case in $testCases) {
        $name       = $case.GetAttribute("name")
        $className  = $case.GetAttribute("classname")
        $status     = $case.GetAttribute("status")
        $time       = $case.GetAttribute("time")
        $assertions = $case.GetAttribute("assertions")
        $failureNode = $case.SelectSingleNode("failure")
        if (-not $failureNode) {
            $failureNode = $case.SelectSingleNode("error")
        }
        $failureMessage = $null
        $failureText = $null
        if ($failureNode) {
            $failureMessage = $failureNode.GetAttribute("message")
            $failureText = ($failureNode.InnerText | Out-String).Trim()
        }

        if ([string]::IsNullOrWhiteSpace($status)) {
            $status = "Skipped"
        }

        $results += [PSCustomObject]@{
            TestCaseName   = $name
            ClassName      = $className
            Status         = $status
            Time           = $time
            Assertions     = $assertions
            FailureMessage = $failureMessage
            FailureText    = $failureText
        }
    }

    $Script:Results = $results
    $Script:FailedResults = $results | Where-Object { $_.Status -ne "Passed" -and $_.Status -ne "Skipped" }
    if ($Script:FailedResults.Count -gt 0) {
        $Script:TestsHadFailures = $true
    }
}

function Emit-Results {
    if ($Script:Results.Count -eq 0) {
        if ($Script:ReportMissing) {
            Write-Warning "UnitTestReport.xml not found at $ReportPath."
            if ($env:GITHUB_ACTIONS -eq "true") {
                Write-Host "::error::Unit test report missing. g-cli exit code $Script:OriginalExitCode."
            }
        } elseif ($Script:ParseError) {
            Write-Warning "UnitTestReport.xml parse error: $Script:ParseError"
            if ($env:GITHUB_ACTIONS -eq "true") {
                Write-Host ("::error::Unit test report parse error: {0}" -f ($Script:ParseError -replace "\r?\n", " ").Trim())
            }
        }

        if ($env:GITHUB_STEP_SUMMARY) {
            $summary = @()
            $summary += "### Unit Test Results (LabVIEW $MinimumSupportedLVVersion $SupportedBitness-bit)"
            $summary += ""
            $summary += "- Total: 0"
            $summary += "- Failed: 1"
            $summary += "- Skipped: 0"
            $summary += "- Report: $ReportPath"
            if ($Script:ReportMissing) {
                $summary += "- Note: UnitTestReport.xml not found."
            } elseif ($Script:ParseError) {
                $summary += "- Note: UnitTestReport.xml parse error."
            } else {
                $summary += "- Note: No test cases reported."
            }
            ($summary -join "`n") | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
        }

        return
    }

    $col1 = "TestCaseName"; $col2 = "ClassName"; $col3 = "Status"; $col4 = "Time(s)"; $col5 = "Assertions"
    $maxName   = $col1.Length
    $maxClass  = $col2.Length
    $maxStatus = $col3.Length
    $maxTime   = $col4.Length
    $maxAssert = $col5.Length

    foreach ($res in $Script:Results) {
        if ($res.TestCaseName.Length -gt $maxName)   { $maxName   = $res.TestCaseName.Length }
        if ($res.ClassName.Length -gt $maxClass)     { $maxClass  = $res.ClassName.Length }
        if ($res.Status.Length -gt $maxStatus)       { $maxStatus = $res.Status.Length }
        if ($res.Time.Length -gt $maxTime)           { $maxTime   = $res.Time.Length }
        if ($res.Assertions.Length -gt $maxAssert)   { $maxAssert = $res.Assertions.Length }
    }

    $header = ($col1.PadRight($maxName) + "  " +
               $col2.PadRight($maxClass) + "  " +
               $col3.PadRight($maxStatus) + "  " +
               $col4.PadRight($maxTime) + "  " +
               $col5.PadRight($maxAssert))
    Write-Host $header

    foreach ($res in $Script:Results) {
        $line = ($res.TestCaseName.PadRight($maxName) + "  " +
                 $res.ClassName.PadRight($maxClass)   + "  " +
                 $res.Status.PadRight($maxStatus)     + "  " +
                 $res.Time.PadRight($maxTime)         + "  " +
                 $res.Assertions.PadRight($maxAssert))

        if ($res.Status -eq "Passed") {
            Write-Host $line -ForegroundColor Green
        }
        elseif ($res.Status -eq "Skipped") {
            Write-Host $line -ForegroundColor Yellow
        }
        else {
            Write-Host $line -ForegroundColor Red
        }
    }

    if ($Script:FailedResults.Count -gt 0) {
        Write-Host "`n=== Unit Test Failures ($($Script:FailedResults.Count)) ==="
        foreach ($res in $Script:FailedResults) {
            Write-Host ("- {0} :: {1} [{2}, {3}s]" -f $res.ClassName, $res.TestCaseName, $res.Status, $res.Time)

            $reason = $res.FailureMessage
            if ([string]::IsNullOrWhiteSpace($reason)) {
                $reason = $res.FailureText
            }
            if (-not [string]::IsNullOrWhiteSpace($reason)) {
                Write-Host ("  {0}" -f $reason)
            }

            if ($env:GITHUB_ACTIONS -eq "true") {
                $annotation = if (-not [string]::IsNullOrWhiteSpace($reason)) { $reason } else { "Test failed." }
                $annotation = ($annotation -replace "\r?\n", " ").Trim()
                if ($annotation.Length -gt 300) {
                    $annotation = $annotation.Substring(0, 300) + "..."
                }
                Write-Host ("::error::{0} / {1} - {2}" -f $res.ClassName, $res.TestCaseName, $annotation)
            }
        }
    }

    if ($env:GITHUB_STEP_SUMMARY) {
        $skippedCount = ($Script:Results | Where-Object { $_.Status -eq "Skipped" }).Count
        $passedResults = $Script:Results | Where-Object { $_.Status -eq "Passed" }
        $summary = @()
        $summary += "### Unit Test Results (LabVIEW $MinimumSupportedLVVersion $SupportedBitness-bit)"
        $summary += ""
        $summary += "- Total: $($Script:Results.Count)"
        $summary += "- Failed: $($Script:FailedResults.Count)"
        $summary += "- Skipped: $skippedCount"
        $summary += "- Report: $ReportPath"
        if ($Script:FailedResults.Count -gt 0) {
            $summary += ""
            $summary += "| Class | Test | Status | Time (s) | Message |"
            $summary += "| --- | --- | --- | --- | --- |"
            foreach ($res in $Script:FailedResults) {
                $message = $res.FailureMessage
                if ([string]::IsNullOrWhiteSpace($message)) {
                    $message = $res.FailureText
                }
                if ([string]::IsNullOrWhiteSpace($message)) {
                    $message = "No details in report."
                }
                $message = ($message -replace "\r?\n", " ").Trim()
                if ($message.Length -gt 300) {
                    $message = $message.Substring(0, 300) + "..."
                }
                $summary += ("| {0} | {1} | {2} | {3} | {4} |" -f $res.ClassName, $res.TestCaseName, $res.Status, $res.Time, $message)
            }
        }
        $summary += ""
        $summary += "#### Passed Tests"
        if ($passedResults.Count -gt 0) {
            $summary += ""
            $summary += "| Class | Test | Status | Time (s) | Assertions |"
            $summary += "| --- | --- | --- | --- | --- |"
            foreach ($res in $passedResults) {
                $summary += ("| {0} | {1} | {2} | {3} | {4} |" -f $res.ClassName, $res.TestCaseName, $res.Status, $res.Time, $res.Assertions)
            }
        } else {
            $summary += ""
            $summary += "No passing tests reported."
        }
        ($summary -join "`n") | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    }
}

# ------------------------  MAIN SEQUENCE  ----------------------
function MainSequence {
    Write-Host "`n=== MainSequence ==="
    Write-Host "Running unit tests for LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit)"
    Write-Host "Project Path: $AbsoluteProjectPath"
    Write-Host "Report will be saved at: $ReportPath"

    if ($Script:SkipRun) {
        Write-Host "Skipping g-cli run."
        return
    }

    Write-Host "`nExecuting g-cli command..."
    $previousNativePreference = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        & g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness lunit -- -r "$ReportPath" "$AbsoluteProjectPath"
    }
    finally {
        $PSNativeCommandUseErrorActionPreference = $previousNativePreference
    }

    $script:OriginalExitCode = $LASTEXITCODE
    if ($script:OriginalExitCode -ne 0) {
        $script:TestsHadFailures = $true
        Write-Warning "g-cli test execution failed (exit code $script:OriginalExitCode)."
    }
}

# --------------------------  CLEANUP  --------------------------
function Cleanup {
    Write-Host "`n=== Cleanup ==="
    # If everything passed (and g-cli was OK), delete the report
    if (($script:OriginalExitCode -eq 0) -and (-not $script:TestsHadFailures)) {
        try {
            Remove-Item $ReportPath -Force -ErrorAction Stop
            Write-Host "`nAll tests passed. Deleted UnitTestReport.xml."
        }
        catch {
            Write-Warning "Failed to delete $($ReportPath): $($_.Exception.Message)"
        }
    }
}

# -------------------  EXECUTION FLOW  -------------------
try {
    Setup
    MainSequence
}
catch {
    if ($Script:OriginalExitCode -eq 0) {
        $Script:OriginalExitCode = 1
    }
    $Script:TestsHadFailures = $true
    Write-Warning ("Unhandled exception during test run: {0}" -f $_.Exception.Message)
}
finally {
    try {
        Parse-Report
    }
    catch {
        $Script:ParseError = $_.Exception.Message
        $Script:TestsHadFailures = $true
        Write-Warning ("Parsing failed: {0}" -f $_.Exception.Message)
    }

    try {
        Emit-Results
    }
    catch {
        Write-Warning ("Summary emission failed: {0}" -f $_.Exception.Message)
    }

    try {
        Cleanup
    }
    catch {
        Write-Warning ("Cleanup failed: {0}" -f $_.Exception.Message)
    }
}

# -------------------  FINAL EXIT CODE  ------------------
if ($Script:OriginalExitCode -ne 0) {
    exit $Script:OriginalExitCode
}
elseif ($Script:TestsHadFailures) {
    exit 2
}
else {
    exit 0
}
