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

# Execute the command
Invoke-Expression $script

Write-Host "Token added to LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) INI file."
