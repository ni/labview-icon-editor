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




.\Applyvipc.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath "$RelativePath" -VIPCPath "Tooling\deployment\Dependencies.vipc" -VIP_LVVersion "$VIP_LVVersion"
.\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "32" -RelativePath "$RelativePath"
.\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "32"
.\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "32" -RelativePath "$RelativePath" -LabVIEW_Project "$RelativePath" -Build_Spec "Editor Packed Library"
.\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "32"
"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}

$script = @"

.\RunUnitTests.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath "$RelativePath"

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}

$script = @"

.\Build_lvlibp.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath "$RelativePath"

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}

$script = @"
.\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "32" -RelativePath "$RelativePath" -LabVIEW_Project "$RelativePath" -Build_Spec "Editor Packed Library"
.\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "32"

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}

$script = @"

.\Rename-File.ps1 -CurrentFilename $RelativePath\resource\plugins\lv_icon.lvlibp -NewFilename lv_icon_x86.lvlibp

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}

$script = @"

.\Applyvipc.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath "$RelativePath" -VIPCPath "Tooling\deployment\Dependencies.vipc" -VIP_LVVersion "$VIP_LVVersion"
.\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "$RelativePath"
.\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64"
.\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "$RelativePath" -LabVIEW_Project "$RelativePath" -Build_Spec "Editor Packed Library"
.\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64"

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}

$script = @"

.\RunUnitTests.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath "$RelativePath"

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}


$script = @"

.\Build_lvlibp.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath "$RelativePath"

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}

$script = @"

.\Close_LabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64"

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}

$script = @"

.\Rename-File.ps1 -CurrentFilename $RelativePath\resource\plugins\lv_icon.lvlibp -NewFilename lv_icon_x64.lvlibp

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}

$script = @"
.\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "$RelativePath" -LabVIEW_Project "$RelativePath" -Build_Spec "Editor Packed Library"
.\build_vip.ps1 -SupportedBitness 64 -RelativePath "$RelativePath" -VIPBPath "$VIPBPath" -VIP_LVVersion 2021  -MinimumSupportedLVVersion "2021"

"@

try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}
