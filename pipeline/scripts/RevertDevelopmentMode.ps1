# Example usage:
# .\RevertDevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"

param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
)

# Define LabVIEW project name
$LabVIEW_Project = 'lv_icon_editor'

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
    # Restore setup for LabVIEW 2021 (32-bit)
    Execute-Script ".\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -LabVIEW_Project `"$LabVIEW_Project`" -Build_Spec `"'Editor Packed Library'`""

    # Close LabVIEW 2021 (32-bit)
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 32"

    # Restore setup for LabVIEW 2021 (64-bit)
    Execute-Script ".\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`" -LabVIEW_Project `"$LabVIEW_Project`" -Build_Spec `"'Editor Packed Library'`""

    # Close LabVIEW 2021 (64-bit)
    Execute-Script ".\Close_LabVIEW.ps1 -MinimumSupportedLVVersion 2021 -SupportedBitness 64"

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Host "All scripts executed successfully." -ForegroundColor Green
