<#
.SYNOPSIS
    Run LabVIEW unit tests using LabVIEWCLI (primary) with optional g-cli fallback.

.DESCRIPTION
    Demonstrates a Setup/MainSequence/Cleanup flow with:
      - Table-based test results
      - Color-coded pass/fail
      - Non-zero exit if the active backend fails or if any test fails
      - Requires an explicit LabVIEW project path (-ProjectPath).

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    Bitness for LabVIEW (e.g., "64").

.PARAMETER ProjectPath
    Required path to the LabVIEW project file to execute tests against.

.PARAMETER ReportPath
    Optional path to an existing UnitTestReport.xml. When provided with -SkipGcli,
    parsing runs without invoking external test execution.

.PARAMETER SkipGcli
    Compatibility switch name. Skips external test execution and parses an existing report.

.PARAMETER ConnectTimeoutMs
    Compatibility parameter kept for callers that still pass this value.
    This parameter is used only when g-cli fallback execution is enabled.

.PARAMETER EnableGcliFallback
    Enables optional fallback from LabVIEWCLI LUnit to g-cli LUnit.
    Fallback is disabled by default.

.NOTES
    PowerShell 7.5+ assumed for cross-platform support.
    This script prefers LabVIEWCLI LUnit. g-cli fallback is opt-in.
#>

[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ReportOnly')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]
    $LabVIEWVersion,

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
    $ReportPath,

    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ReportOnly')]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
    [Parameter(Mandatory = $false, ParameterSetName = 'ReportOnly')]
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

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportRoot = if ([string]::IsNullOrWhiteSpace($env:LVIE_ARTIFACT_ROOT)) { $PSScriptRoot } else { Join-Path $env:LVIE_ARTIFACT_ROOT 'unit-tests' }
    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_ARTIFACT_ROOT) -and -not (Test-Path -Path $reportRoot)) {
        New-Item -Path $reportRoot -ItemType Directory -Force | Out-Null
    }
    $ReportPath = Join-Path -Path $reportRoot -ChildPath "UnitTestReport.xml"
} else {
    Write-Host "Using report path override: $ReportPath"
}

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
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRoot
    $labviewYear = $versionInfo.Year
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
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
        Write-Warning "Project path not set; skipping unit test execution."
    }
}

# --------------------------  SETUP  --------------------------
function Setup {
    Write-Host "=== Setup ==="
    if ($Script:SkipRun) {
        Write-Host "Skipping unit test execution; report-only mode."
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
                Write-Host "::error::Unit test report missing. runner exit code $Script:OriginalExitCode."
            }
        } elseif ($Script:ParseError) {
            Write-Warning "UnitTestReport.xml parse error: $Script:ParseError"
            if ($env:GITHUB_ACTIONS -eq "true") {
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
        $summary += "### Unit Test Results (LabVIEW $labviewYear $SupportedBitness-bit)"
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

function ConvertTo-LUnitPortNumber {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RawValue,

        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return $null
    }

    $parsedPort = 0
    if (-not [int]::TryParse($RawValue.Trim(), [ref]$parsedPort) -or $parsedPort -lt 1 -or $parsedPort -gt 65535) {
        Write-Warning ("Ignoring invalid LUnit port value '{0}' from {1}. Expected integer range 1-65535." -f $RawValue, $Source)
        return $null
    }

    return $parsedPort
}

function Get-LabVIEWIniTcpSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath
    )

    $iniPath = Join-Path -Path (Split-Path -Path $LabVIEWExecutablePath -Parent) -ChildPath 'LabVIEW.ini'
    $portRaw = $null
    $enabledRaw = $null
    $enabledValue = $null

    if (-not (Test-Path -Path $iniPath -PathType Leaf)) {
        return [pscustomobject]@{
            IniPath       = $iniPath
            PortRaw       = $portRaw
            EnabledRaw    = $enabledRaw
            EnabledValue  = $enabledValue
        }
    }

    try {
        $lines = Get-Content -Path $iniPath -ErrorAction Stop
    }
    catch {
        Write-Warning ("Unable to read LabVIEW.ini at {0}: {1}" -f $iniPath, $_.Exception.Message)
        return [pscustomobject]@{
            IniPath       = $iniPath
            PortRaw       = $portRaw
            EnabledRaw    = $enabledRaw
            EnabledValue  = $enabledValue
        }
    }

    foreach ($line in $lines) {
        if ($null -eq $line) {
            continue
        }
        if ($line -match '^\s*server\.tcp\.port\s*=\s*(.+?)\s*$') {
            $portRaw = $Matches[1].Trim()
            continue
        }
        if ($line -match '^\s*server\.tcp\.enabled\s*=\s*(.+?)\s*$') {
            $enabledRaw = $Matches[1].Trim()
            continue
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($enabledRaw)) {
        $normalized = $enabledRaw.Trim().ToLowerInvariant()
        if (@('true', 't', '1', 'yes', 'y') -contains $normalized) {
            $enabledValue = $true
        }
        elseif (@('false', 'f', '0', 'no', 'n') -contains $normalized) {
            $enabledValue = $false
        }
        else {
            Write-Warning ("Ignoring unrecognized server.tcp.enabled value '{0}' in {1}." -f $enabledRaw, $iniPath)
        }
    }

    return [pscustomobject]@{
        IniPath       = $iniPath
        PortRaw       = $portRaw
        EnabledRaw    = $enabledRaw
        EnabledValue  = $enabledValue
    }
}

function Resolve-LUnitPort {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness,

        [Parameter(Mandatory = $true)]
        [string]$LabVIEWExecutablePath
    )

    $bitnessEnvName = "LVIE_LUNIT_PORT_{0}" -f $Bitness
    $bitnessEnvValue = [Environment]::GetEnvironmentVariable($bitnessEnvName)
    $genericEnvValue = [Environment]::GetEnvironmentVariable('LVIE_LUNIT_PORT')
    $hasEnvOverride = -not [string]::IsNullOrWhiteSpace($bitnessEnvValue) -or -not [string]::IsNullOrWhiteSpace($genericEnvValue)

    $iniSettings = Get-LabVIEWIniTcpSettings -LabVIEWExecutablePath $LabVIEWExecutablePath

    $bitnessPort = ConvertTo-LUnitPortNumber -RawValue $bitnessEnvValue -Source ('$env:{0}' -f $bitnessEnvName)
    if ($null -ne $bitnessPort) {
        return [pscustomobject]@{
            PortNumber     = $bitnessPort
            Source         = ('$env:{0}' -f $bitnessEnvName)
            IniPath        = $iniSettings.IniPath
            ViServerEnabled = $iniSettings.EnabledValue
            HasEnvOverride = $hasEnvOverride
        }
    }

    $genericPort = ConvertTo-LUnitPortNumber -RawValue $genericEnvValue -Source '$env:LVIE_LUNIT_PORT'
    if ($null -ne $genericPort) {
        return [pscustomobject]@{
            PortNumber      = $genericPort
            Source          = '$env:LVIE_LUNIT_PORT'
            IniPath         = $iniSettings.IniPath
            ViServerEnabled = $iniSettings.EnabledValue
            HasEnvOverride  = $hasEnvOverride
        }
    }

    $iniPort = ConvertTo-LUnitPortNumber -RawValue $iniSettings.PortRaw -Source ('{0} (server.tcp.port)' -f $iniSettings.IniPath)
    if ($null -ne $iniPort) {
        return [pscustomobject]@{
            PortNumber      = $iniPort
            Source          = ('{0} (server.tcp.port)' -f $iniSettings.IniPath)
            IniPath         = $iniSettings.IniPath
            ViServerEnabled = $iniSettings.EnabledValue
            HasEnvOverride  = $hasEnvOverride
        }
    }

    return [pscustomobject]@{
        PortNumber      = 3363
        Source          = 'default:3363'
        IniPath         = $iniSettings.IniPath
        ViServerEnabled = $iniSettings.EnabledValue
        HasEnvOverride  = $hasEnvOverride
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
        [string]$ReportPath
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

# ------------------------  MAIN SEQUENCE  ----------------------
function MainSequence {
    Write-Host "`n=== MainSequence ==="
    Write-Host "Running unit tests for LabVIEW $labviewYear ($SupportedBitness-bit)"
    Write-Host "Project Path: $AbsoluteProjectPath"
    Write-Host "Report will be saved at: $ReportPath"

    if ($Script:SkipRun) {
        Write-Host "Skipping unit test execution."
        return
    }

    if ($ConnectTimeoutMs -gt 0) {
        Write-Host ("ConnectTimeoutMs={0} is accepted for compatibility and used only when g-cli fallback is enabled." -f $ConnectTimeoutMs)
    }

    $gcliFallbackEnabled = $EnableGcliFallback.IsPresent
    if ($gcliFallbackEnabled) {
        Write-Host "g-cli fallback is enabled."
    } else {
        Write-Host "g-cli fallback is disabled (default)."
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
                $labviewCliResult = Invoke-LUnitLabVIEWCli `
                    -LabVIEWCliPath $labviewCliCommand.Source `
                    -LabVIEWExecutablePath $labviewExecutablePath `
                    -PortNumber $portResolution.PortNumber `
                    -ProjectPath $AbsoluteProjectPath `
                    -ReportPath $ReportPath

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

