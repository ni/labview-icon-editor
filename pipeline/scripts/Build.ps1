
#Example: .\Build.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath
)

# Construct the command
$script = @"
.\RunUnitTests.ps1 -MinimumSupportedLVVersion "$MinimumSupportedLVVersion" -SupportedBitness "$SupportedBitness" -RelativePath "$RelativePath"
.\Build_lvlibp.ps1 -MinimumSupportedLVVersion "$MinimumSupportedLVVersion" -SupportedBitness "$SupportedBitness" -RelativePath "C:\labview-icon-editor"
.\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "$MinimumSupportedLVVersion" -SupportedBitness "$SupportedBitness" QuitLabVIEW
"@

Write-Output "Executing the following command:"
Write-Output $script

# Execute the command
Invoke-Expression $script


Write-Host " Build finished."

