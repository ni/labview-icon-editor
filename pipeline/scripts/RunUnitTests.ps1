#Example: .\RunUnitTests.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath
)
Write-Host "Run unit tests for LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit)"
# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness lunit -- -r UnitTestReport.xml "$RelativePath\lv_icon_editor.lvproj"

"@

Write-Output "Executing the following command:"
Write-Output $script

# Execute the command and check for errors
try {
    Invoke-Expression $script

    # Check the exit code of the executed command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Unit tests failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "An error occurred while executing the unit tests."
    exit 1
}

