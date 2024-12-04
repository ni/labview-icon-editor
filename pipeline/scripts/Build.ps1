param(
    [string]$RelativePath,
    [string]$RelativePathScripts = "."
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
    Execute-Script "Get-ChildItem -Path `"$RelativePath\resource\plugins`" -Filter '*.lvlibp' | Remove-Item -Force"

    Execute-Script "$RelativePathScripts\Applyvipc.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -VIPCPath `"$RelativePath\Tooling\deployment\Dependencies.vipc`" -VIP_LVVersion '2021'"
    Execute-Script "$RelativePathScripts\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`""
    Execute-Script "$RelativePathScripts\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32"
    Execute-Script "$RelativePathScripts\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'"
    Execute-Script "$RelativePathScripts\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32"
    Execute-Script "$RelativePathScripts\RunUnitTests.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`""
    Execute-Script "$RelativePathScripts\Build_lvlibp.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`""
    Execute-Script "$RelativePathScripts\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'"
    Execute-Script "$RelativePathScripts\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32"
    Execute-Script "$RelativePathScripts\Rename-File.ps1 -CurrentFilename `"$RelativePath\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x86.lvlibp'"

    Execute-Script "$RelativePathScripts\Applyvipc.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`" -VIPCPath `"$RelativePath\Tooling\deployment\Dependencies.vipc`" -VIP_LVVersion '2021'"
    Execute-Script "$RelativePathScripts\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`""
    Execute-Script "$RelativePathScripts\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64"
    Execute-Script "$RelativePathScripts\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'"
    Execute-Script "$RelativePathScripts\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64"
    Execute-Script "$RelativePathScripts\RunUnitTests.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`""
    Execute-Script "$RelativePathScripts\Build_lvlibp.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`""
    Execute-Script "$RelativePathScripts\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`" -LabVIEW_Project 'lv_icon_editor' -Build_Spec 'Editor Packed Library'"
    Execute-Script "$RelativePathScripts\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64"
    Execute-Script "$RelativePathScripts\Rename-File.ps1 -CurrentFilename `"$RelativePath\resource\plugins\lv_icon.lvlibp`" -NewFilename 'lv_icon_x64.lvlibp'"
    Execute-Script "$RelativePathScripts\build_vip.ps1 -SupportedBitness 64 -RelativePath `"$RelativePath`" -VIPBPath `"$RelativePath\Tooling\deployment\NI Icon editor.vipb`" -VIP_LVVersion 2021 -MinimumSupportedLVVersion 2021"

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
