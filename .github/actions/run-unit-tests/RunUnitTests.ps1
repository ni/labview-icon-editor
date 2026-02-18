<#
.SYNOPSIS
    Parse-only validator for existing LUnit reports.

.DESCRIPTION
    Parse-only execution contract:
      - Validates an existing UnitTestReport XML file
      - Emits table-based and summary pass/fail output
      - Returns non-zero on missing/invalid/empty testcase reports
      - Is intended to be called via `runner-cli lunit validate`
      - Test execution is canonicalized on `runner-cli lunit run` (g-cli backend)

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    Bitness for LabVIEW (e.g., "64").

.PARAMETER ProjectPath
    Required path to the LabVIEW project file to execute tests against.

.PARAMETER ReportPath
    Optional path to UnitTestReport.xml.
    In parse mode (-SkipGcli), this points to an existing report to validate.

.PARAMETER SkipGcli
    Required parse mode switch. Validates an existing report and never executes tests.

.PARAMETER ConnectTimeoutMs
    Deprecated compatibility parameter. Parse-only mode ignores this value.

.PARAMETER EnableGcliFallback
    Deprecated. Test execution is no longer supported by this script.
    Use `runner-cli lunit run` for canonical g-cli execution.

.NOTES
    PowerShell 7.5+ assumed for cross-platform support.
    This script is parse-only.
    Legacy backend knobs (LVIE_LUNIT_BACKEND, LVIE_FORCE_GCLI_LUNIT) are fail-fast.
#>

[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Parse')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]
    $LabVIEWVersion,

    [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Parse')]
    [ValidateSet("32","64")]
    [string]
    $SupportedBitness,

    [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
    [string]
    $ProjectPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'Parse')]
    [switch]
    $SkipGcli,

    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Parse')]
    [string]
    $ReportPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Parse')]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $false, ParameterSetName = 'Parse')]
    [switch]$SkipWorktreeRootCheck,

    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 0,

    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [switch]$EnableGcliFallback
)

# Script-level variables to track exit states and results
$Script:OriginalExitCode = 0
$Script:TestsHadFailures = $false
$Script:Results = @()
$Script:FailedResults = @()
$Script:ReportMissing = $false
$Script:ParseError = $null
$Script:ReportPathCanonical = $null
$Script:ReportPathLegacyCandidate = $null
$Script:ReportPathUsed = $null
$Script:ReportFallbackUsed = $false
$Script:ReportParseSource = 'canonical'
$Script:SourceTestStrictMode = $false

function Test-PathEquivalent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Left,
        [Parameter(Mandatory = $true)]
        [string]$Right
    )

    $leftFull = [System.IO.Path]::GetFullPath($Left)
    $rightFull = [System.IO.Path]::GetFullPath($Right)
    $comparison = if ($IsWindows) {
        [StringComparison]::OrdinalIgnoreCase
    } else {
        [StringComparison]::Ordinal
    }

    return [string]::Equals($leftFull, $rightFull, $comparison)
}

function Resolve-ReportOsSegment {
    if ($IsWindows) {
        return 'Windows'
    }
    if ($IsLinux) {
        return 'Linux'
    }
    if ($IsMacOS) {
        return 'macOS'
    }

    return 'Unknown'
}

function Resolve-SourceTestStrictMode {
    $strictModeRaw = [Environment]::GetEnvironmentVariable('LVIE_SOURCE_TEST_STRICT')
    if ([string]::IsNullOrWhiteSpace($strictModeRaw)) {
        return $false
    }

    $normalized = $strictModeRaw.Trim().ToLowerInvariant()
    return $normalized -notin @('0', 'false', 'no')
}

$Script:SourceTestStrictMode = Resolve-SourceTestStrictMode

function Assert-LegacyLunitBackendKnobsNotSet {
    $backendValue = [Environment]::GetEnvironmentVariable('LVIE_LUNIT_BACKEND')
    if (-not [string]::IsNullOrWhiteSpace($backendValue)) {
        throw ("LVIE_LUNIT_BACKEND is no longer supported. Use 'runner-cli lunit run' for canonical g-cli execution and 'runner-cli lunit validate' for parse-only validation.")
    }

    $forceGcliValue = [Environment]::GetEnvironmentVariable('LVIE_FORCE_GCLI_LUNIT')
    if (-not [string]::IsNullOrWhiteSpace($forceGcliValue)) {
        throw ("LVIE_FORCE_GCLI_LUNIT is no longer supported. Use 'runner-cli lunit run' for canonical g-cli execution.")
    }
}

Assert-LegacyLunitBackendKnobsNotSet

if ($EnableGcliFallback.IsPresent) {
    throw ("-EnableGcliFallback is no longer supported. Use 'runner-cli lunit run' for canonical g-cli execution.")
}

if ($PSCmdlet.ParameterSetName -ne 'Parse') {
    throw ("RunUnitTests.ps1 execution mode is deprecated. Use 'runner-cli lunit run' for test execution, or pass -SkipGcli for parse-only validation.")
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportRoot = if ([string]::IsNullOrWhiteSpace($env:LVIE_ARTIFACT_ROOT)) { $PSScriptRoot } else { Join-Path $env:LVIE_ARTIFACT_ROOT 'unit-tests' }
    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_ARTIFACT_ROOT) -and -not (Test-Path -Path $reportRoot)) {
        New-Item -Path $reportRoot -ItemType Directory -Force | Out-Null
    }
    $reportOs = Resolve-ReportOsSegment
    $ReportPath = Join-Path -Path $reportRoot -ChildPath ("UnitTestReport-{0}-{1}.xml" -f $reportOs, $SupportedBitness)
} else {
    Write-Host "Using report path override: $ReportPath"
}

$Script:ReportPathCanonical = $ReportPath
$reportDirectory = Split-Path -Parent $Script:ReportPathCanonical
$legacyCandidatePath = Join-Path -Path $reportDirectory -ChildPath 'UnitTestReport.xml'
if (-not (Test-PathEquivalent -Left $Script:ReportPathCanonical -Right $legacyCandidatePath)) {
    $Script:ReportPathLegacyCandidate = $legacyCandidatePath
}
$Script:ReportPathUsed = $Script:ReportPathCanonical

$repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\..')).Path
$preflightScript = Join-Path $repoRoot 'Tooling\Invoke-Preflight.ps1'
if (Test-Path -Path $preflightScript) {
    . $preflightScript
    $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
    $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $repoRoot -Path $PSCommandPath } else { $null }
    $preflight = Invoke-Preflight `
        -RepoRoot $repoRoot `
        -WorktreeRoot $WorktreeRoot `
        -LabVIEWVersion $LabVIEWVersion `
        -LabVIEWBitness $SupportedBitness `
        -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
        -AutoWorktree:$false `
        -ScriptPath $relativeScript `
        -ScriptArguments $scriptArgs
    if ($preflight.Reinvoked) {
        return
    }
    $repoRoot = $preflight.RepoRoot
}
$versionHelper = Join-Path $repoRoot 'Tooling\support\LabVIEWVersion.ps1'
$labviewYear = $LabVIEWVersion
$labviewNumericVersion = $null
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRoot
    $labviewYear = $versionInfo.Year
    $labviewNumericVersion = $versionInfo.NumericVersion
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}
if ([string]::IsNullOrWhiteSpace($labviewNumericVersion)) {
    $parsedYear = 0
    if ([int]::TryParse($labviewYear, [ref]$parsedYear)) {
        if ($parsedYear -ge 2000) {
            $parsedYear -= 2000
        }
        $labviewNumericVersion = "{0}.0" -f $parsedYear
    }
}
$labviewExecutableHelper = Join-Path $repoRoot 'Tooling\support\LabVIEWExecutablePath.ps1'
if (-not (Test-Path -Path $labviewExecutableHelper)) {
    throw "LabVIEW executable path helper not found at $labviewExecutableHelper"
}
. $labviewExecutableHelper

# --------------------------------------------------------------------
# 1) Resolve the LabVIEW project path
# --------------------------------------------------------------------

$AbsoluteProjectPath = $null

if ($PSCmdlet.ParameterSetName -eq 'Run') {
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $Script:OriginalExitCode = 3
        $Script:TestsHadFailures = $true
        $Script:ParseError = "ProjectPath is required in run mode."
        throw "ProjectPath is required in run mode."
    }

    if (Test-Path -Path $ProjectPath -PathType Leaf) {
        $AbsoluteProjectPath = (Resolve-Path -Path $ProjectPath).Path
    } else {
        $Script:OriginalExitCode = 3
        $Script:TestsHadFailures = $true
        $Script:ParseError = "ProjectPath does not exist: $ProjectPath"
        throw "Provided ProjectPath does not exist: $ProjectPath"
    }
}

$Script:SkipRun = ($PSCmdlet.ParameterSetName -eq 'Parse')

if ($AbsoluteProjectPath) {
    Write-Host "Using LabVIEW project file: $AbsoluteProjectPath"
} else {
    if ($PSCmdlet.ParameterSetName -eq 'Parse') {
        Write-Host "Project path is not required in parse mode."
    } else {
        $Script:OriginalExitCode = 3
        $Script:TestsHadFailures = $true
        $Script:ParseError = "ProjectPath resolution failed in run mode."
        throw "ProjectPath resolution failed in run mode."
    }
}

# --------------------------  SETUP  --------------------------
function Setup {
    Write-Host "=== Setup ==="
    if ($Script:SkipRun) {
        Write-Host "Skipping unit test execution; parse mode selected."
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
    $Script:ReportPathUsed = $Script:ReportPathCanonical
    $Script:ReportFallbackUsed = $false
    $Script:ReportParseSource = 'canonical'

    $candidates = @(
        [pscustomobject]@{
            Source = 'canonical'
            Path   = $Script:ReportPathCanonical
        }
    )
    if (-not [string]::IsNullOrWhiteSpace($Script:ReportPathLegacyCandidate)) {
        $candidates += [pscustomobject]@{
            Source = 'legacy'
            Path   = $Script:ReportPathLegacyCandidate
        }
    }

    $xmlDoc = $null
    $testCases = $null
    $parsePath = $Script:ReportPathCanonical
    $parseSource = 'canonical'
    $lastError = $null
    $lastPathMissing = $false
    $canonicalNoTestcasePath = $null
    $canonicalNoTestcaseError = $null

    for ($index = 0; $index -lt $candidates.Count; $index++) {
        $candidate = $candidates[$index]
        $isLastCandidate = $index -eq ($candidates.Count - 1)
        $candidatePath = $candidate.Path
        $candidateSource = $candidate.Source

        if (-not (Test-Path -Path $candidatePath -PathType Leaf)) {
            $lastPathMissing = $true
            if ($candidateSource -eq 'canonical' -and -not $isLastCandidate) {
                Write-Warning ("Canonical unit test report missing at {0}; falling back to legacy alias {1}." -f $Script:ReportPathCanonical, $Script:ReportPathLegacyCandidate)
                continue
            }
            if ($isLastCandidate) {
                $parsePath = $candidatePath
                $parseSource = $candidateSource
            }
            continue
        }

        try {
            [xml]$candidateDoc = Get-Content -Path $candidatePath -Raw -ErrorAction Stop
        }
        catch {
            $lastError = $_.Exception.Message
            if ($candidateSource -eq 'canonical' -and -not $isLastCandidate) {
                Write-Warning ("Canonical unit test report unreadable at {0}; falling back to legacy alias {1}. Error: {2}" -f $Script:ReportPathCanonical, $Script:ReportPathLegacyCandidate, $lastError)
                continue
            }
            $parsePath = $candidatePath
            $parseSource = $candidateSource
            break
        }

        $candidateTestCases = $candidateDoc.SelectNodes("//testcase")
        if (-not $candidateTestCases -or $candidateTestCases.Count -eq 0) {
            $lastError = ("No <testcase> entries found in report '{0}'." -f $candidatePath)
            if ($candidateSource -eq 'canonical' -and -not $isLastCandidate) {
                $canonicalNoTestcasePath = $candidatePath
                $canonicalNoTestcaseError = $lastError
                Write-Warning ("Canonical unit test report has no <testcase> entries at {0}; falling back to legacy alias {1}." -f $Script:ReportPathCanonical, $Script:ReportPathLegacyCandidate)
                continue
            }
            $xmlDoc = $candidateDoc
            $testCases = $candidateTestCases
            $parsePath = $candidatePath
            $parseSource = $candidateSource
            break
        }

        $xmlDoc = $candidateDoc
        $testCases = $candidateTestCases
        $parsePath = $candidatePath
        $parseSource = $candidateSource
        break
    }

    if ($null -eq $xmlDoc -and -not [string]::IsNullOrWhiteSpace($canonicalNoTestcasePath)) {
        $parsePath = $canonicalNoTestcasePath
        $parseSource = 'canonical'
        $lastPathMissing = $false
        if ([string]::IsNullOrWhiteSpace($lastError)) {
            $lastError = $canonicalNoTestcaseError
        }
    }

    $Script:ReportPathUsed = $parsePath
    $Script:ReportParseSource = $parseSource
    $Script:ReportFallbackUsed = $parseSource -eq 'legacy'
    Write-Host ("Unit test report parse source: {0}" -f $Script:ReportParseSource)
    Write-Host ("Unit test report parse path: {0}" -f $Script:ReportPathUsed)

    if ($null -eq $xmlDoc) {
        if ($lastPathMissing) {
            $Script:ReportMissing = $true
        } else {
            $Script:ParseError = $lastError
        }
        $Script:TestsHadFailures = $true
        return
    }

    if (-not $testCases -or $testCases.Count -eq 0) {
        if ([string]::IsNullOrWhiteSpace($lastError)) {
            $lastError = ("No <testcase> entries found in report '{0}'." -f $Script:ReportPathUsed)
        }
        $Script:ParseError = $lastError
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
            Write-Warning ("Unit test report not found at {0}." -f $Script:ReportPathUsed)
            if ($env:GITHUB_ACTIONS -eq "true" -and $Script:SourceTestStrictMode) {
                Write-Host "::error::Unit test report missing. runner exit code $Script:OriginalExitCode."
            }
        } elseif ($Script:ParseError) {
            Write-Warning ("Unit test report parse error ({0}): {1}" -f $Script:ReportPathUsed, $Script:ParseError)
            if ($env:GITHUB_ACTIONS -eq "true" -and $Script:SourceTestStrictMode) {
                Write-Host ("::error::Unit test report parse error: {0}" -f ($Script:ParseError -replace "\r?\n", " ").Trim())
            }
        }

        if ($env:GITHUB_STEP_SUMMARY) {
            $summary = @()
            $summary += "### Unit Test Results (LabVIEW $labviewYear $SupportedBitness-bit)"
            $summary += ""
            $summary += "- Total: 0"
            $summary += "- Failed: 1"
            $summary += "- Skipped: 0"
            $summary += "- Report: $($Script:ReportPathUsed)"
            $summary += "- Parse source: $($Script:ReportParseSource)"
            if ($Script:ReportMissing) {
                $summary += "- Note: Unit test report not found."
            } elseif ($Script:ParseError) {
                $summary += "- Note: Unit test report parse error."
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

            if ($env:GITHUB_ACTIONS -eq "true" -and $Script:SourceTestStrictMode) {
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
        $summary += "### Unit Test Results (LabVIEW $labviewYear $SupportedBitness-bit)"
        $summary += ""
        $summary += "- Total: $($Script:Results.Count)"
        $summary += "- Failed: $($Script:FailedResults.Count)"
        $summary += "- Skipped: $skippedCount"
        $summary += "- Report: $($Script:ReportPathUsed)"
        $summary += "- Parse source: $($Script:ReportParseSource)"
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

function Test-ReportHasTestcases {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        return $false
    }

    try {
        [xml]$xmlDoc = Get-Content -Path $Path -ErrorAction Stop
    }
    catch {
        return $false
    }

    $testCases = $xmlDoc.SelectNodes("//testcase")
    return [bool]($testCases -and $testCases.Count -gt 0)
}

function Resolve-LUnitPort {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness,

        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath
    )

    $portContractHelper = Join-Path $repoRoot 'Tooling\support\LabVIEWCliPortContract.ps1'
    if (-not (Test-Path -Path $portContractHelper -PathType Leaf)) {
        throw "LabVIEW CLI port contract helper not found at $portContractHelper"
    }
    . $portContractHelper

    $resolved = Resolve-LabVIEWCliPortFromContract `
        -RepoRoot $repoRoot `
        -LabVIEWVersion $labviewYear `
        -Bitness $Bitness `
        -LabVIEWExecutablePath $LabVIEWExecutablePath

    return [pscustomobject]@{
        PortNumber      = $resolved.PortNumber
        Source          = $resolved.Source
        IniPath         = $resolved.IniPath
        ViServerEnabled = $true
        HasEnvOverride  = $false
    }
}

function Test-LUnitOperationFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationFolderPath
    )

    if (-not (Test-Path -Path $OperationFolderPath -PathType Container)) {
        return $false
    }

    $runOperation = Join-Path -Path $OperationFolderPath -ChildPath 'RunOperation.vi'
    return (Test-Path -Path $runOperation -PathType Leaf)
}

function Resolve-LUnitOperationRootFromPath {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CandidatePath,

        [Parameter(Mandatory = $true)]
        [string]$Source,

        [switch]$WarnWhenMissing
    )

    if ([string]::IsNullOrWhiteSpace($CandidatePath)) {
        return $null
    }

    if (-not (Test-Path -Path $CandidatePath -PathType Container)) {
        if ($WarnWhenMissing) {
            Write-Warning ("Ignoring missing LUnit operation directory candidate from {0}: {1}" -f $Source, $CandidatePath)
        }
        return $null
    }

    $resolvedPath = (Resolve-Path -Path $CandidatePath).Path
    $candidateLeaf = Split-Path -Path $resolvedPath -Leaf

    if ($candidateLeaf -ieq 'LUnit') {
        if (Test-LUnitOperationFolder -OperationFolderPath $resolvedPath) {
            return [pscustomobject]@{
                OperationRoot = (Split-Path -Path $resolvedPath -Parent)
                Source        = ("{0} (LUnit folder)" -f $Source)
            }
        }
    }

    $lunitFolder = Join-Path -Path $resolvedPath -ChildPath 'LUnit'
    if (Test-LUnitOperationFolder -OperationFolderPath $lunitFolder) {
        return [pscustomobject]@{
            OperationRoot = $resolvedPath
            Source        = $Source
        }
    }

    if ($WarnWhenMissing) {
        Write-Warning ("No usable 'LUnit\\RunOperation.vi' found under candidate from {0}: {1}" -f $Source, $resolvedPath)
    }
    return $null
}

function Get-LUnitOperationRootsFromVipmIndex {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$LabVIEWNumericVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness
    )

    if ([string]::IsNullOrWhiteSpace($LabVIEWNumericVersion)) {
        return @()
    }

    $dbRoot = Join-Path $env:ProgramData 'JKI\VIPM\databases'
    if (-not (Test-Path -Path $dbRoot -PathType Container)) {
        return @()
    }

    $dbFolder = if ($Bitness -eq '64') { "LV $LabVIEWNumericVersion (64-bit)" } else { "LV $LabVIEWNumericVersion" }
    $indexPath = Join-Path (Join-Path (Join-Path $dbRoot $dbFolder) 'astemes_lib_lunit_cli') 'files-installed'
    if (-not (Test-Path -Path $indexPath -PathType Leaf)) {
        return @()
    }

    $candidates = @()
    $seen = @{}

    foreach ($line in Get-Content -Path $indexPath -ErrorAction SilentlyContinue) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $candidateRoots = @()
        $trimmed = $line.Trim()

        $operationsMatch = [regex]::Match($trimmed, '^(?<root>.+?[\\/](?:Operations|operations))(?:[\\/]LUnit(?:[\\/].*)?)$')
        if ($operationsMatch.Success) {
            $candidateRoots += [string]$operationsMatch.Groups['root'].Value
        }

        $runOperationMatch = [regex]::Match($trimmed, '^(?<root>.+?)[\\/]LUnit[\\/]RunOperation\.vi$')
        if ($runOperationMatch.Success) {
            $candidateRoots += [string]$runOperationMatch.Groups['root'].Value
        }

        $exampleMatch = [regex]::Match($trimmed, '^(?<root>.+?)[\\/]LUnit CLI(?:[\\/].*)?$')
        if ($exampleMatch.Success) {
            $candidateRoots += [string]$exampleMatch.Groups['root'].Value
        }

        foreach ($root in $candidateRoots) {
            if ([string]::IsNullOrWhiteSpace($root)) {
                continue
            }
            try {
                $fullRoot = [System.IO.Path]::GetFullPath($root)
            }
            catch {
                continue
            }
            $key = $fullRoot.ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $candidates += [pscustomobject]@{
                    Path   = $fullRoot
                    Source = ("VIPM files-installed ({0})" -f $indexPath)
                }
            }
        }
    }

    return $candidates
}

function Resolve-LUnitOperationDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness,

        [Parameter(Mandatory = $true)]
        [string]$LabVIEWCliPath,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$LabVIEWNumericVersion
    )

    $sourceTrail = New-Object System.Collections.Generic.List[string]
    $defaultOperationRoot = Join-Path -Path (Split-Path -Path $LabVIEWCliPath -Parent) -ChildPath 'Operations'
    $specificEnvName = "LVIE_LUNIT_OPERATION_DIR_{0}" -f $Bitness
    $specificEnvValue = [Environment]::GetEnvironmentVariable($specificEnvName)
    $genericEnvValue = [Environment]::GetEnvironmentVariable('LVIE_LUNIT_OPERATION_DIR')

    $specific = Resolve-LUnitOperationRootFromPath -CandidatePath $specificEnvValue -Source ('$env:{0}' -f $specificEnvName) -WarnWhenMissing
    if ($specific) {
        return [pscustomobject]@{
            Found                            = $true
            OperationRoot                    = $specific.OperationRoot
            Source                           = $specific.Source
            RequiresAdditionalOperationDirectory = -not ($specific.OperationRoot.Equals($defaultOperationRoot, [System.StringComparison]::OrdinalIgnoreCase))
            SourceTrail                      = @($sourceTrail)
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($specificEnvValue)) {
        $sourceTrail.Add(('$env:{0}={1}' -f $specificEnvName, $specificEnvValue))
    }

    $generic = Resolve-LUnitOperationRootFromPath -CandidatePath $genericEnvValue -Source '$env:LVIE_LUNIT_OPERATION_DIR' -WarnWhenMissing
    if ($generic) {
        return [pscustomobject]@{
            Found                            = $true
            OperationRoot                    = $generic.OperationRoot
            Source                           = $generic.Source
            RequiresAdditionalOperationDirectory = -not ($generic.OperationRoot.Equals($defaultOperationRoot, [System.StringComparison]::OrdinalIgnoreCase))
            SourceTrail                      = @($sourceTrail)
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($genericEnvValue)) {
        $sourceTrail.Add(('$env:LVIE_LUNIT_OPERATION_DIR={0}' -f $genericEnvValue))
    }

    $defaultCandidate = Resolve-LUnitOperationRootFromPath -CandidatePath $defaultOperationRoot -Source 'default LabVIEW CLI Operations directory'
    if ($defaultCandidate) {
        return [pscustomobject]@{
            Found                            = $true
            OperationRoot                    = $defaultCandidate.OperationRoot
            Source                           = $defaultCandidate.Source
            RequiresAdditionalOperationDirectory = $false
            SourceTrail                      = @($sourceTrail)
        }
    }
    $sourceTrail.Add($defaultOperationRoot)

    $vipmCandidates = Get-LUnitOperationRootsFromVipmIndex -LabVIEWNumericVersion $LabVIEWNumericVersion -Bitness $Bitness
    foreach ($candidate in $vipmCandidates) {
        $resolved = Resolve-LUnitOperationRootFromPath -CandidatePath $candidate.Path -Source $candidate.Source
        if ($resolved) {
            return [pscustomobject]@{
                Found                            = $true
                OperationRoot                    = $resolved.OperationRoot
                Source                           = $resolved.Source
                RequiresAdditionalOperationDirectory = -not ($resolved.OperationRoot.Equals($defaultOperationRoot, [System.StringComparison]::OrdinalIgnoreCase))
                SourceTrail                      = @($sourceTrail)
            }
        }
        $sourceTrail.Add(('{0}: {1}' -f $candidate.Source, $candidate.Path))
    }

    return [pscustomobject]@{
        Found                            = $false
        OperationRoot                    = $null
        Source                           = 'not-found'
        RequiresAdditionalOperationDirectory = $false
        SourceTrail                      = @($sourceTrail)
    }
}

function Invoke-LUnitLabVIEWCli {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWCliPath,

        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath,

        [Parameter(Mandatory = $true)]
        [int]$PortNumber,

        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,

        [Parameter(Mandatory = $true)]
        [string]$ReportPath,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$AdditionalOperationDirectory
    )

    Write-Host "`nExecuting LabVIEWCLI LUnit operation..."
    Write-Host ("LabVIEWCLI: {0}" -f $LabVIEWCliPath)
    Write-Host ("LabVIEWPath: {0}" -f $LabVIEWExecutablePath)

    $previousNativePreference = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    $exitCode = 0
    try {
        $labviewCliArgs = @(
            '-OperationName', 'LUnit',
            '-LabVIEWPath', $LabVIEWExecutablePath,
            '-PortNumber', $PortNumber.ToString(),
            '-LogToConsole', 'TRUE',
            '-Verbosity', 'Default',
            '-ProjectPath', "$ProjectPath",
            '-ReportPath', "$ReportPath"
        )
        if (-not [string]::IsNullOrWhiteSpace($AdditionalOperationDirectory)) {
            Write-Host ("AdditionalOperationDirectory: {0}" -f $AdditionalOperationDirectory)
            $labviewCliArgs += @('-AdditionalOperationDirectory', $AdditionalOperationDirectory)
        }
        & $LabVIEWCliPath @labviewCliArgs
        $exitCode = $LASTEXITCODE
    }
    finally {
        $PSNativeCommandUseErrorActionPreference = $previousNativePreference
    }

    return [pscustomobject]@{
        Attempted = $true
        ExitCode  = $exitCode
    }
}

function Invoke-LUnitGcli {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWVersionYear,

        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness,

        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,

        [Parameter(Mandatory = $true)]
        [string]$ReportPath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 600000)]
        [int]$ConnectTimeoutMs = 0
    )

    $gcliCommand = Get-Command g-cli -ErrorAction SilentlyContinue
    if (-not $gcliCommand) {
        Write-Warning "g-cli is not available on PATH. Install g-cli and ensure g-cli.exe is discoverable."
        return [pscustomobject]@{
            Attempted = $false
            ExitCode  = $null
        }
    }

    Write-Host "`nFalling back to g-cli LUnit execution..."
    Write-Host ("g-cli: {0}" -f $gcliCommand.Source)

    $gcliArgs = @(
        '--lv-ver', $LabVIEWVersionYear,
        '--arch', $Bitness
    )
    if ($ConnectTimeoutMs -gt 0) {
        $gcliArgs += @('--connect-timeout', $ConnectTimeoutMs)
    }
    $gcliArgs += @('lunit', '--', '-r', "$ReportPath", "$ProjectPath")

    $previousNativePreference = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    $exitCode = 0
    try {
        & $gcliCommand.Source @gcliArgs
        $exitCode = $LASTEXITCODE
    }
    finally {
        $PSNativeCommandUseErrorActionPreference = $previousNativePreference
    }

    return [pscustomobject]@{
        Attempted = $true
        ExitCode  = $exitCode
    }
}

function Resolve-LUnitBackendMode {
    $rawBackendMode = [Environment]::GetEnvironmentVariable('LVIE_LUNIT_BACKEND')
    if (-not [string]::IsNullOrWhiteSpace($rawBackendMode)) {
        $normalizedBackendMode = $rawBackendMode.Trim().ToLowerInvariant()
        if (@('labviewcli', 'gcli') -contains $normalizedBackendMode) {
            return [pscustomobject]@{
                Mode   = $normalizedBackendMode
                Source = '$env:LVIE_LUNIT_BACKEND'
            }
        }
        Write-Warning ("Ignoring invalid LVIE_LUNIT_BACKEND value '{0}'. Expected 'labviewcli' or 'gcli'." -f $rawBackendMode)
    }

    $forceGcliRaw = [Environment]::GetEnvironmentVariable('LVIE_FORCE_GCLI_LUNIT')
    if (-not [string]::IsNullOrWhiteSpace($forceGcliRaw)) {
        $normalizedForceGcli = $forceGcliRaw.Trim().ToLowerInvariant()
        if (@('1', 'true', 'yes', 'y', 'on') -contains $normalizedForceGcli) {
            return [pscustomobject]@{
                Mode   = 'gcli'
                Source = '$env:LVIE_FORCE_GCLI_LUNIT'
            }
        }
    }

    return [pscustomobject]@{
        Mode   = 'labviewcli'
        Source = 'default:labviewcli'
    }
}

# ------------------------  MAIN SEQUENCE  ----------------------
function MainSequence {
    Write-Host "`n=== MainSequence ==="
    if ($Script:SkipRun) {
        Write-Host "Validating existing unit test report for LabVIEW $labviewYear ($SupportedBitness-bit)"
    } else {
        Write-Host "Running unit tests for LabVIEW $labviewYear ($SupportedBitness-bit)"
        Write-Host "Project Path: $AbsoluteProjectPath"
    }
    Write-Host "Report will be saved at: $ReportPath"

    if ($Script:SkipRun) {
        Write-Host "Parse mode selected; skipping unit test execution and validating existing report."
        return
    }

    if ($ConnectTimeoutMs -gt 0) {
        Write-Host ("ConnectTimeoutMs={0} is accepted for compatibility and used only when g-cli execution is selected." -f $ConnectTimeoutMs)
    }

    $gcliFallbackEnabled = $EnableGcliFallback.IsPresent
    if ($gcliFallbackEnabled) {
        Write-Host "g-cli fallback is enabled."
    } else {
        Write-Host "g-cli fallback is disabled (default)."
    }

    $backendResolution = Resolve-LUnitBackendMode
    $lunitBackendMode = $backendResolution.Mode
    Write-Host ("LUnit backend mode: {0} (source: {1})" -f $lunitBackendMode, $backendResolution.Source)

    if ($lunitBackendMode -eq 'gcli') {
        Write-Host "Forced g-cli backend selected. Skipping LabVIEWCLI LUnit execution path."
        $gcliResult = Invoke-LUnitGcli `
            -LabVIEWVersionYear $labviewYear `
            -Bitness $SupportedBitness `
            -ProjectPath $AbsoluteProjectPath `
            -ReportPath $ReportPath `
            -ConnectTimeoutMs $ConnectTimeoutMs

        if (-not $gcliResult.Attempted) {
            if ($script:OriginalExitCode -eq 0) {
                $script:OriginalExitCode = 1
            }
            $script:TestsHadFailures = $true
            Write-Warning "No test execution backend is available. Install g-cli and ensure 'sas_workshops_lib_lunit_for_g_cli' is installed."
            return
        }

        $script:OriginalExitCode = $gcliResult.ExitCode
        if ($script:OriginalExitCode -ne 0) {
            $script:TestsHadFailures = $true
            Write-Warning ("g-cli LUnit execution failed (exit code {0}). Ensure 'sas_workshops_lib_lunit_for_g_cli' is installed (apply .github/actions/apply-vipc/runner_dependencies.vipc)." -f $script:OriginalExitCode)
        }
        return
    }

    $runGcliFallback = $false
    $labviewCliAttempted = $false
    $labviewCliExitCode = $null
    $labviewCliCommand = Get-Command LabVIEWCLI -ErrorAction SilentlyContinue

    if (-not $labviewCliCommand) {
        if ($gcliFallbackEnabled) {
            Write-Warning "LabVIEWCLI is not available on PATH. Falling back to g-cli LUnit execution."
            $runGcliFallback = $true
        } else {
            $script:OriginalExitCode = 1
            $script:TestsHadFailures = $true
            Write-Warning "LabVIEWCLI is not available on PATH and g-cli fallback is disabled. Re-run with -EnableGcliFallback to allow fallback."
            return
        }
    } else {
        $labviewExecutablePath = $null
        try {
            $labviewExecutablePath = Resolve-LabVIEWExecutablePath -VersionYear $labviewYear -Bitness $SupportedBitness
        }
        catch {
            if ($gcliFallbackEnabled) {
                Write-Warning ("Unable to resolve LabVIEW executable for LabVIEWCLI: {0}" -f $_.Exception.Message)
                $runGcliFallback = $true
            } else {
                $script:OriginalExitCode = 1
                $script:TestsHadFailures = $true
                Write-Warning ("Unable to resolve LabVIEW executable for LabVIEWCLI: {0}" -f $_.Exception.Message)
                Write-Warning "g-cli fallback is disabled. Re-run with -EnableGcliFallback to allow fallback."
                return
            }
        }

        if ($labviewExecutablePath) {
            $portResolution = Resolve-LUnitPort -Bitness $SupportedBitness -LabVIEWExecutablePath $labviewExecutablePath
            Write-Host ("LabVIEWCLI PortNumber: {0} (source: {1})" -f $portResolution.PortNumber, $portResolution.Source)

            if (($portResolution.ViServerEnabled -eq $false) -and (-not $portResolution.HasEnvOverride)) {
                if ($gcliFallbackEnabled) {
                    Write-Warning ("LabVIEW VI Server TCP is disabled in {0} and no LVIE_LUNIT_PORT override is set. Falling back to g-cli." -f $portResolution.IniPath)
                    $runGcliFallback = $true
                } else {
                    $script:OriginalExitCode = 1
                    $script:TestsHadFailures = $true
                    Write-Warning ("LabVIEW VI Server TCP is disabled in {0} and no LVIE_LUNIT_PORT override is set." -f $portResolution.IniPath)
                    Write-Warning "g-cli fallback is disabled. Enable VI Server TCP or re-run with -EnableGcliFallback."
                    return
                }
            } else {
                $operationResolution = Resolve-LUnitOperationDirectory -Bitness $SupportedBitness -LabVIEWCliPath $labviewCliCommand.Source -LabVIEWNumericVersion $labviewNumericVersion
                if (-not $operationResolution.Found) {
                    $checkedLocations = if ($operationResolution.SourceTrail -and $operationResolution.SourceTrail.Count -gt 0) {
                        $operationResolution.SourceTrail -join '; '
                    } else {
                        'none'
                    }

                    if ($gcliFallbackEnabled) {
                        Write-Warning ("Unable to resolve LabVIEWCLI LUnit operation directory. Checked: {0}" -f $checkedLocations)
                        Write-Warning "Ensure 'astemes_lib_lunit_cli' is installed and provides an 'LUnit' operation folder, or set LVIE_LUNIT_OPERATION_DIR_<BITNESS>/LVIE_LUNIT_OPERATION_DIR. Falling back to g-cli."
                        $runGcliFallback = $true
                    } else {
                        $script:OriginalExitCode = 1
                        $script:TestsHadFailures = $true
                        Write-Warning ("Unable to resolve LabVIEWCLI LUnit operation directory. Checked: {0}" -f $checkedLocations)
                        Write-Warning "Ensure 'astemes_lib_lunit_cli' is installed and provides an 'LUnit' operation folder, or set LVIE_LUNIT_OPERATION_DIR_<BITNESS>/LVIE_LUNIT_OPERATION_DIR."
                        Write-Warning "g-cli fallback is disabled. Re-run with -EnableGcliFallback to allow fallback."
                        return
                    }
                } else {
                    Write-Host ("LUnit operation root: {0} (source: {1})" -f $operationResolution.OperationRoot, $operationResolution.Source)
                }

                if (-not $runGcliFallback) {
                    $additionalOperationDirectory = $null
                    if ($operationResolution.RequiresAdditionalOperationDirectory) {
                        $additionalOperationDirectory = $operationResolution.OperationRoot
                    }

                    $labviewCliResult = Invoke-LUnitLabVIEWCli `
                        -LabVIEWCliPath $labviewCliCommand.Source `
                        -LabVIEWExecutablePath $labviewExecutablePath `
                        -PortNumber $portResolution.PortNumber `
                        -ProjectPath $AbsoluteProjectPath `
                        -ReportPath $ReportPath `
                        -AdditionalOperationDirectory $additionalOperationDirectory

                    $labviewCliAttempted = $labviewCliResult.Attempted
                    $labviewCliExitCode = $labviewCliResult.ExitCode
                    $script:OriginalExitCode = $labviewCliExitCode

                    if ($labviewCliExitCode -ne 0) {
                        Write-Warning ("LabVIEWCLI LUnit execution failed (exit code {0}). Ensure 'astemes_lib_lunit_cli' is installed (apply .github/actions/apply-vipc/runner_dependencies.vipc)." -f $labviewCliExitCode)
                        if (Test-ReportHasTestcases -Path $ReportPath) {
                            Write-Host "LabVIEWCLI produced a usable report despite non-zero exit; g-cli fallback will not run."
                        } else {
                            if ($gcliFallbackEnabled) {
                                Write-Warning "LabVIEWCLI did not produce a usable report. Falling back to g-cli."
                                $runGcliFallback = $true
                            } else {
                                Write-Warning "LabVIEWCLI did not produce a usable report and g-cli fallback is disabled."
                            }
                        }
                    }
                }
            }
        }
    }

    if ($runGcliFallback) {
        $gcliResult = Invoke-LUnitGcli `
            -LabVIEWVersionYear $labviewYear `
            -Bitness $SupportedBitness `
            -ProjectPath $AbsoluteProjectPath `
            -ReportPath $ReportPath `
            -ConnectTimeoutMs $ConnectTimeoutMs

        if (-not $gcliResult.Attempted) {
            if ($script:OriginalExitCode -eq 0) {
                $script:OriginalExitCode = 1
            }
            $script:TestsHadFailures = $true
            Write-Warning "No test execution backend is available. Install g-cli and ensure 'sas_workshops_lib_lunit_for_g_cli' is installed."
            return
        }

        $script:OriginalExitCode = $gcliResult.ExitCode
        if ($script:OriginalExitCode -ne 0) {
            $script:TestsHadFailures = $true
            Write-Warning ("g-cli LUnit fallback failed (exit code {0}). Ensure 'sas_workshops_lib_lunit_for_g_cli' is installed (apply .github/actions/apply-vipc/runner_dependencies.vipc)." -f $script:OriginalExitCode)
        }
        return
    }

    if ($labviewCliAttempted -and $labviewCliExitCode -ne 0) {
        $script:TestsHadFailures = $true
    }
}

# --------------------------  CLEANUP  --------------------------
function Cleanup {
    Write-Host "`n=== Cleanup ==="
    # If everything passed (and LabVIEWCLI was OK), delete the report
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

