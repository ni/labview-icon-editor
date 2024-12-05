
# Example usage:
# .\Set_Development_Mode.ps1 -RelativePath "C:\labview-icon-editor"

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
	Execute-Script "Get-ChildItem -Path '$RelativePath\resource\plugins' -Filter '*.lvlibp' | Remove-Item -Force" 
    Execute-Script ".\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath '$RelativePath'"
    Execute-Script ".\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath '$RelativePath' -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" 
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32" 
	Execute-Script ".\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath '$RelativePath'" 
    Execute-Script ".\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath '$RelativePath' -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'" 
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64" 

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Host "All scripts executed successfully."
