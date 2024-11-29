# Example usage:
# .\build.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor" -LabVIEW_Project "lv_icon_editor" -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -VIP_LVVersion "2021" -VIPCPath "Tooling\deployment\Dependencies.vipc"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$LabVIEW_Project,
    [string]$VIPBPath,
    [string]$VIP_LVVersion,
	[string]$VIPCPath
)
# Construct the command
$script = @"
#############################
#   Apply dependenciesx86   #
#############################
.\Applyvipc.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath "$RelativePath" -VIPCPath "Tooling\deployment\Dependencies.vipc" -VIP_LVVersion "$VIP_LVVersion"
#############################
#		Build 32 bit        #
#############################
.\RunUnitTests.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath "$RelativePath"

.\Build_lvlibp.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath "$RelativePath"

.\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "32"

.\Rename-File.ps1 -CurrentFilename $RelativePath\resource\plugins\lv_icon.lvlibp -NewFilename lv_icon_x86.lvlibp

#############################
#   Apply dependenciesx64   #
#############################
.\Applyvipc.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath "$RelativePath" -VIPCPath "Tooling\deployment\Dependencies.vipc" -VIP_LVVersion 2021
#############################
#		Build 64 bit        #
#############################

.\RunUnitTests.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath "$RelativePath"

.\Build_lvlibp.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath "$RelativePath"

.\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "32"

.\Rename-File.ps1 -CurrentFilename $RelativePath\resource\plugins\lv_icon.lvlibp -NewFilename lv_icon_x64.lvlibp

#############################
# Build VI Package
#############################
.\build_vip.ps1 -SupportedBitness 64 -RelativePath "$RelativePath" -VIPBPath "$VIPBPath" -VIP_LVVersion 2021  -MinimumSupportedLVVersion "2021"

"@

Write-Output "Executing the following command:"
Write-Output $script

# Execute the command
Invoke-Expression $script


Write-Host " Build finished."

