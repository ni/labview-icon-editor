# Example usage:
# .\build.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor" -LabVIEW_Project "lv_icon_editor" -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -VIP_LVVersion "2024"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$LabVIEW_Project,
    [string]$VIPBPath,
    [string]$VIP_LVVersion
)

# Construct the command
$script = @"
.\RunUnitTests.ps1 -MinimumSupportedLVVersion "$MinimumSupportedLVVersion" -SupportedBitness "$SupportedBitness" -RelativePath "$RelativePath"
.\Build_lvlibp.ps1 -MinimumSupportedLVVersion "$MinimumSupportedLVVersion" -SupportedBitness "$SupportedBitness" -RelativePath "$RelativePath"
.\Build_vip.ps1 -MinimumSupportedLVVersion "$MinimumSupportedLVVersion" -SupportedBitness "$SupportedBitness" -RelativePath "$RelativePath" -LabVIEW_Project "$LabVIEW_Project" -VIPBPath "$VIPBPath" -VIP_LVVersion "$VIP_LVVersion"

"@

Write-Output "Executing the following command:"
Write-Output $script

# Execute the command
Invoke-Expression $script


Write-Host " Build finished."

