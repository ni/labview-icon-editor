<#
.SYNOPSIS
    Run LabVIEW unit tests using g-cli and output a color-coded table of results.

.DESCRIPTION
    Demonstrates a Setup/MainSequence/Cleanup flow with:
      - Table-based test results
      - Color-coded pass/fail
      - Non-zero exit if g-cli fails or if any test fails
      - Automatic search for exactly one *.lvproj file by moving up the folder hierarchy
        until just before the drive root.

.PARAMETER Package_LabVIEW_Version
    LabVIEW minimum supported version (e.g., "2021").

.PARAMETER SupportedBitness
    Bitness for LabVIEW (e.g., "64").

.NOTES
    PowerShell 7.5+ assumed for cross-platform support.
    This script *requires* that g-cli and LabVIEW be compatible with the OS.
#>

[Diagnostics.CodeAnalysis.SuppressMessage("PSReviewUnusedParameter","Package_LabVIEW_Version",Justification="Used in nested functions and g-cli invocation")]
[Diagnostics.CodeAnalysis.SuppressMessage("PSReviewUnusedParameter","SupportedBitness",Justification="Used in nested functions and g-cli invocation")]
param(
    [Alias('MinimumSupportedLVVersion')]
    [string]
    $Package_LabVIEW_Version = "",

    [Parameter(Mandatory=$true)]
    [ValidateSet("32","64")]
    [string]
    $SupportedBitness,

[string]
$AbsoluteProjectPath
)

Write-Warning "Deprecated: prefer 'pwsh scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCli -- unit-tests --repo <path> --bitness <both|64|32> --lv-version <year> --project <lvproj>'; this script remains as a delegate."
Write-Information "[legacy-ps] unit-tests delegate invoked" -InformationAction Continue

# Helpers for LabVIEW process handling (bitness-aware)
function Get-LabVIEWProcesses {
    param([string]$Bitness, [string]$LvVersion)
    $pattern = if ($Bitness -eq '32') { '*Program Files (x86)*' } else { '*Program Files*' }
    try {
        return Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ProcessName -like 'LabVIEW*' -and $_.Path -like "*LabVIEW $LvVersion\\LabVIEW.exe" -and $_.MainModule.FileName -like $pattern
        }
    }
    catch { return @() }
}

function Wait-LabVIEWExit {
    param(
        [string]$Bitness,
        [string]$LvVersion,
        [int]$TimeoutSec = 2,
        [string]$Context = "pre-test"
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $procs = Get-LabVIEWProcesses -Bitness $Bitness -LvVersion $LvVersion
    if (-not $procs) { return }
    Write-Information ("Waiting for LabVIEW {0}-bit to exit ({1}; PIDs: {2})" -f $Bitness, $Context, ($procs.Id -join ', ')) -InformationAction Continue
    do {
        Start-Sleep -Seconds 2
        $procs = Get-LabVIEWProcesses -Bitness $Bitness -LvVersion $LvVersion
    } while ($procs -and (Get-Date) -lt $deadline)
    if ($procs) {
        throw ("LabVIEW {0}-bit still running after wait ({1}); PIDs: {2}" -f $Bitness, $Context, ($procs.Id -join ', '))
    }
}

function Invoke-CloseLabVIEW {
    param(
        [string]$Bitness,
        [string]$LvVersion
    )
    $closeScript = Join-Path $PSScriptRoot '..\close-labview\Close_LabVIEW.ps1'
    if (-not (Test-Path -LiteralPath $closeScript)) {
        throw "Close_LabVIEW.ps1 not found at expected path: $closeScript"
    }
    & $closeScript -Package_LabVIEW_Version $LvVersion -SupportedBitness $Bitness
}

# --------------------------------------------------------------------
# 1) Locate exactly one .lvproj file (use provided path when available, else search upward)
# --------------------------------------------------------------------
Write-Information "Starting directory for .lvproj search: $PSScriptRoot" -InformationAction Continue

function Get-SingleLvproj {
    param(
        [string] $StartFolder
    )

    $currentDir = $StartFolder

    while ($true) {
        Write-Information "Searching '$currentDir' for *.lvproj files..." -InformationAction Continue
        $lvprojFiles = Get-ChildItem -Path $currentDir -Filter '*.lvproj' -File -ErrorAction SilentlyContinue

        if ($lvprojFiles.Count -eq 1) {
            # Found exactly one .lvproj
            return $lvprojFiles[0].FullName
        }
        elseif ($lvprojFiles.Count -gt 1) {
            # Found multiple .lvproj files
            $list = $lvprojFiles | ForEach-Object { " - {0}" -f $_.FullName }
            throw ("Multiple .lvproj files found in '{0}' (count={1}). Ensure only one is present. Found:{2}{3}" -f `
                    $currentDir, $lvprojFiles.Count, [Environment]::NewLine, ($list -join [Environment]::NewLine))
        }

        # If none found, move one level up
        $parentDir = Split-Path -Path $currentDir -Parent

        # If we've reached or are about to reach the drive root, stop searching
        $driveRoot = [System.IO.Path]::GetPathRoot($currentDir)
        if ($parentDir -eq $currentDir -or $parentDir -eq $driveRoot) {
            Write-Error "Error: Reached the level before root without finding exactly one .lvproj."
            return $null
        }

        $currentDir = $parentDir
    }
}

if ([string]::IsNullOrWhiteSpace($AbsoluteProjectPath)) {
    $AbsoluteProjectPath = Get-SingleLvproj -StartFolder $PSScriptRoot
}
else {
    if (-not (Test-Path $AbsoluteProjectPath)) {
        throw "Provided project path does not exist: $AbsoluteProjectPath"
    }
    $AbsoluteProjectPath = (Resolve-Path $AbsoluteProjectPath).Path
}

if (-not $AbsoluteProjectPath) {
    # We failed to find exactly one .lvproj in any ancestor up to the level before root
    exit 3
}
Write-Information "Using LabVIEW project file: $AbsoluteProjectPath" -InformationAction Continue
if ([string]::IsNullOrWhiteSpace($Package_LabVIEW_Version)) {
    throw "LabVIEW version is required but was not provided. Ensure the composite action supplies inputs.labview_version or LABVIEW_VERSION."
}
Write-Information ("Using LabVIEW version provided by workflow: {0}" -f $Package_LabVIEW_Version) -InformationAction Continue

# Script-level variables to track exit states
$Script:OriginalExitCode = 0
$Script:TestsHadFailures = $false

# Path to UnitTestReport.xml in the same directory as this script
$ReportPath = Join-Path -Path $PSScriptRoot -ChildPath "UnitTestReport.xml"

# --------------------------  SETUP  --------------------------
function Invoke-Setup {
    Write-Information "=== Setup ===" -InformationAction Continue
    $reportDir = Split-Path -Parent $ReportPath
    if (-not (Test-Path $reportDir)) {
        try {
            New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
            Write-Information "Created report directory: $reportDir" -InformationAction Continue
        }
        catch {
            Write-Warning ("Could not create report directory {0}: {1}" -f $reportDir, $_.Exception.Message)
        }
    }
    if (Test-Path $ReportPath) {
        try {
            Remove-Item $ReportPath -Force -ErrorAction Stop
            Write-Information "Deleted existing UnitTestReport.xml." -InformationAction Continue
        }
        catch {
            Write-Warning "Could not remove UnitTestReport.xml: $($_.Exception.Message)"
        }
    }
    else {
        Write-Information "No existing UnitTestReport.xml found. Continuing..." -InformationAction Continue
    }
}

# ------------------------  MAIN SEQUENCE  ----------------------
function Invoke-MainSequence {
    Write-Information "`n=== MainSequence ===" -InformationAction Continue
    Write-Information "Running unit tests for LabVIEW $Package_LabVIEW_Version ($SupportedBitness-bit)" -InformationAction Continue
    Write-Information "Project Path: $AbsoluteProjectPath" -InformationAction Continue
    Write-Information "Report will be saved at: $ReportPath" -InformationAction Continue

    Write-Information "`nExecuting g-cli command..." -InformationAction Continue
    & g-cli --lv-ver $Package_LabVIEW_Version --arch $SupportedBitness lunit -- -r "$ReportPath" "$AbsoluteProjectPath"

    $script:OriginalExitCode = $LASTEXITCODE
    if ($script:OriginalExitCode -ne 0) {
        Write-Error "g-cli test execution failed (exit code $script:OriginalExitCode)."
    }

    # If g-cli failed and no report was produced, we can't parse anything
    if ($script:OriginalExitCode -ne 0 -and -not (Test-Path $ReportPath)) {
        $script:TestsHadFailures = $true
        Write-Warning "No test report found, and g-cli returned an error."
        return
    }

    # Parse UnitTestReport.xml if it exists
    if (Test-Path $ReportPath) {
        try {
            [xml]$xmlDoc = Get-Content $ReportPath -ErrorAction Stop
        }
        catch {
            Write-Error "UnitTestReport.xml is invalid or malformed: $($_.Exception.Message)"
            $script:TestsHadFailures = $true
            return
        }
    }
    else {
        Write-Error "UnitTestReport.xml not found; cannot parse results."
        $script:TestsHadFailures = $true
        return
    }

    # Retrieve all <testcase> nodes
    $testCases = $xmlDoc.SelectNodes("//testcase")
    if (!$testCases -or $testCases.Count -eq 0) {
        Write-Error "No <testcase> entries found in UnitTestReport.xml."
        $script:TestsHadFailures = $true
        return
    }

    # Prepare for tabular output
    $col1 = "TestCaseName"; $col2 = "ClassName"; $col3 = "Status"; $col4 = "Time(s)"; $col5 = "Assertions"
    $maxName   = $col1.Length
    $maxClass  = $col2.Length
    $maxStatus = $col3.Length
    $maxTime   = $col4.Length
    $maxAssert = $col5.Length

    $results = @()
    foreach ($case in $testCases) {
        $name       = $case.GetAttribute("name")
        $className  = $case.GetAttribute("classname")
        $status     = $case.GetAttribute("status")
        $time       = $case.GetAttribute("time")
        $assertions = $case.GetAttribute("assertions")

        # If status is empty, treat as "Skipped" so it doesn't cause a false fail
        if ([string]::IsNullOrWhiteSpace($status)) {
            $status = "Skipped"
        }

        # Update max lengths for formatting
        if ($name.Length       -gt $maxName)   { $maxName   = $name.Length }
        if ($className.Length  -gt $maxClass)  { $maxClass  = $className.Length }
        if ($status.Length     -gt $maxStatus) { $maxStatus = $status.Length }
        if ($time.Length       -gt $maxTime)   { $maxTime   = $time.Length }
        if ($assertions.Length -gt $maxAssert) { $maxAssert = $assertions.Length }

        # Store data
        $results += [PSCustomObject]@{
            TestCaseName = $name
            ClassName    = $className
            Status       = $status
            Time         = $time
            Assertions   = $assertions
        }

        # Mark any test that isn't Passed or Skipped as a failure
        if ($status -notmatch "^Passed$" -and $status -notmatch "^Skipped$") {
            $script:TestsHadFailures = $true
        }
    }

    # Print table header
    $header = ($col1.PadRight($maxName) + "  " +
               $col2.PadRight($maxClass) + "  " +
               $col3.PadRight($maxStatus) + "  " +
               $col4.PadRight($maxTime) + "  " +
               $col5.PadRight($maxAssert))
Write-Information $header -InformationAction Continue

    # Output test results in color
    foreach ($res in $results) {
        $line = ($res.TestCaseName.PadRight($maxName) + "  " +
                 $res.ClassName.PadRight($maxClass)   + "  " +
                 $res.Status.PadRight($maxStatus)     + "  " +
                 $res.Time.PadRight($maxTime)         + "  " +
                 $res.Assertions.PadRight($maxAssert))

        if ($res.Status -eq "Passed") {
            Write-Information $line -InformationAction Continue
        }
        elseif ($res.Status -eq "Skipped") {
            Write-Information $line -InformationAction Continue
        }
        else {
            Write-Warning $line
        }
    }
}

# --------------------------  CLEANUP  --------------------------
function Invoke-Cleanup {
    Write-Information "`n=== Cleanup ===" -InformationAction Continue
    # If everything passed (and g-cli was OK), delete the report
    if (($script:OriginalExitCode -eq 0) -and (-not $script:TestsHadFailures)) {
        try {
            Remove-Item $ReportPath -Force -ErrorAction Stop
            Write-Information "`nAll tests passed. Deleted UnitTestReport.xml." -InformationAction Continue
        }
        catch {
            Write-Warning "Failed to delete $($ReportPath): $($_.Exception.Message)"
        }
    }

    # Close LabVIEW for the bitness used in this test run
    Write-Information ("Closing LabVIEW {0}-bit after unit tests..." -f $SupportedBitness) -InformationAction Continue
    try {
        Invoke-CloseLabVIEW -Bitness $SupportedBitness -LvVersion $Package_LabVIEW_Version
    }
    catch {
        Write-Warning ("Failed to close LabVIEW {0}-bit after unit tests: {1}" -f $SupportedBitness, $_.Exception.Message)
    }
    finally {
        try {
            Wait-LabVIEWExit -Bitness $SupportedBitness -LvVersion $Package_LabVIEW_Version -TimeoutSec 2 -Context "post-test"
        }
        catch {
            Write-Warning ("LabVIEW {0}-bit still running after post-test wait: {1}" -f $SupportedBitness, $_.Exception.Message)
        }
    }
}

# -------------------  EXECUTION FLOW  -------------------
try {
    # Ensure idempotent start: no LabVIEW for this bitness is running
    Wait-LabVIEWExit -Bitness $SupportedBitness -LvVersion $Package_LabVIEW_Version -TimeoutSec 2 -Context "pre-test"

    Invoke-Setup
    Invoke-MainSequence
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
        Invoke-Cleanup
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
