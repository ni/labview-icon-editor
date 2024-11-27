#Example: .\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" QuitLabVIEW
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath
)

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness QuitLabVIEW
"@

Write-Output "Executing the following command:"
Write-Output $script
            
# Execute the command
Invoke-Expression $script

Write-Host "Close LabVIEW"
