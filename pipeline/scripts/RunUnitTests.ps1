#Example: .\RunUnitTests.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath
)

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$RelativePath\Tooling\Run all tests CLI.vi"
"@

Write-Output "Executing the following command:"
Write-Output $script

# Execute the command
Invoke-Expression $script

Write-Host "Unit tests finished."
