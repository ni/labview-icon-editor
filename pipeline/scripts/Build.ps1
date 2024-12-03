# Example usage:
# .\build.ps1 -RelativePath "C:\labview-icon-editor"

param(
    [string]$RelativePath
)

# Helper function to execute scripts and stop on error
function Execute-Script {
    param(
        [string]$ScriptCommand
    )
    Write-Host "Executing: $ScriptCommand"
    try {
        Invoke-Expression $ScriptCommand -ErrorAction Stop
    } catch {
        Write-Error "Error occurred while executing: $ScriptCommand. Exiting."
        exit 1
    }
}
# Sequential script execution with error handling
try {
	Execute-Script "Get-ChildItem -Path 'C:\labview-icon-editor\resource\plugins' -Filter '*.lvlibp' | Remove-Item -Force" 
    Execute-Script ".\Applyvipc.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath '$RelativePath' -VIPCPath 'Tooling\deployment\Dependencies.vipc' -VIP_LVVersion '2021'" 
    Execute-Script ".\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath '$RelativePath'"
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32" 
    Execute-Script ".\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath '$RelativePath' -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" 
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32" 
    Execute-Script ".\RunUnitTests.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath '$RelativePath'" 
    Execute-Script ".\Build_lvlibp.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath '$RelativePath'" 
    Execute-Script ".\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath '$RelativePath' -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" 
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32" 
    Execute-Script ".\Rename-File.ps1 -CurrentFilename '$RelativePath\resource\plugins\lv_icon.lvlibp' -NewFilename 'lv_icon_x86.lvlibp'" 

    Execute-Script ".\Applyvipc.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath '$RelativePath' -VIPCPath 'Tooling\deployment\Dependencies.vipc' -VIP_LVVersion '2021'" 
    Execute-Script ".\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath '$RelativePath'" 
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64" 
    Execute-Script ".\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath '$RelativePath' -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" 
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64" 
    Execute-Script ".\RunUnitTests.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath '$RelativePath'" 
    Execute-Script ".\Build_lvlibp.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath '$RelativePath'" 
    Execute-Script ".\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath '$RelativePath' -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" 
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64" 
    Execute-Script ".\Rename-File.ps1 -CurrentFilename '$RelativePath\resource\plugins\lv_icon.lvlibp' -NewFilename 'lv_icon_x64.lvlibp'" 
    Execute-Script ".\build_vip.ps1 -SupportedBitness 64 -RelativePath '$RelativePath' -VIPBPath 'Tooling\deployment\NI Icon editor.vipb' -VIP_LVVersion 2021 -MinimumSupportedLVVersion 2021" 

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "All scripts executed successfully." -ForegroundColor Green
