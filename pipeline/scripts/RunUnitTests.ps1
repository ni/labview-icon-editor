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

.PARAMETER MinimumSupportedLVVersion
    LabVIEW minimum supported version (e.g., "2021").

.PARAMETER SupportedBitness
    Bitness for LabVIEW (e.g., "64").

.NOTES
    PowerShell 7.5+ assumed for cross-platform support.
    This script *requires* that g-cli and LabVIEW be compatible with the OS.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]
    $MinimumSupportedLVVersion,

    [Parameter(Mandatory=$true)]
    [ValidateSet("32","64")]
    [string]
    $SupportedBitness
)

# --------------------------------------------------------------------
# 1) Locate exactly one .lvproj file by searching upward from $PSScriptRoot
# --------------------------------------------------------------------
Write-Host "Starting directory for .lvproj search: $PSScriptRoot"

function Get-SingleLvproj {
    param(
        [string] $StartFolder
    )

    $currentDir = $StartFolder

    while ($true) {
        Write-Host "Searching '$currentDir' for *.lvproj files..."
        $lvprojFiles = Get-ChildItem -Path $currentDir -Filter '*.lvproj' -File -ErrorAction SilentlyContinue

        if ($lvprojFiles.Count -eq 1) {
            # Found exactly one .lvproj
            return $lvprojFiles[0].FullName
        }
        elseif ($lvprojFiles.Count -gt 1) {
            # Found multiple .lvproj files
            Write-Error "Error: Multiple .lvproj files found in '$currentDir'. Please ensure only one .lvproj is present."
            $lvprojFiles | ForEach-Object { Write-Host " - $_.FullName" }
            return $null
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

$AbsoluteProjectPath = Get-SingleLvproj -StartFolder $PSScriptRoot

if (-not $AbsoluteProjectPath) {
    # We failed to find exactly one .lvproj in any ancestor up to the level before root
    exit 3
}
Write-Host "Using LabVIEW project file: $AbsoluteProjectPath"

# Script-level variables to track exit states
$Script:OriginalExitCode = 0
$Script:TestsHadFailures = $false

# Path to UnitTestReport.xml in the same directory as this script
$ReportPath = Join-Path -Path $PSScriptRoot -ChildPath "UnitTestReport.xml"

# --------------------------  SETUP  --------------------------
function Setup {
    Write-Host "=== Setup ==="
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

# ------------------------  MAIN SEQUENCE  ----------------------
function MainSequence {
    Write-Host "`n=== MainSequence ==="
    Write-Host "Running unit tests for LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit)"
    Write-Host "Project Path: $AbsoluteProjectPath"
    Write-Host "Report will be saved at: $ReportPath"

    Write-Host "`nExecuting g-cli command..."
    & g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness lunit -- -r "$ReportPath" "$AbsoluteProjectPath"

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
    Write-Host $header

    # Output test results in color
    foreach ($res in $results) {
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
Setup
MainSequence
#Cleanup

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
