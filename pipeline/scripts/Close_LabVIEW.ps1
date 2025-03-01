#Example: .\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness
)

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness QuitLabVIEW
"@

Write-Output "Executing the following command:"
Write-Output $script

# Execute the command and check for errors
try {
    Invoke-Expression $script

    # Check the exit code of the executed command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to close LabVIEW with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "An error occurred while trying to close LabVIEW."
    exit 1
}

Write-Host "Close LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit)"
