#Example: .\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion "2023" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath
)

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$RelativePath\Tooling\deployment\Create_LV_INI_Token.vi" -- LabVIEW Localhost.LibraryPaths "$RelativePath"
"@

Write-Output "Executing the following command:"
Write-Output $script

# Execute the command and check for errors
try {
    Invoke-Expression $script

    # Check the exit code of the executed command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to add token to LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "An error occurred while adding the token to LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) INI file."
    exit 1
}

Write-Host "Token successfully added to LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) INI file."
