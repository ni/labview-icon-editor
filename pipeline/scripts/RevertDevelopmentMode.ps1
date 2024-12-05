# Example usage:
# .\RevertDevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"

param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
)

# Define LabVIEW project name
$LabVIEW_Project = 'lv_icon_editor'

# Determine the directory where this script is located
$ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Host "Script Directory: $ScriptDirectory"

# Helper function to execute scripts and stop on error
function Execute-Script {
    param(
        [string]$ScriptCommand
    )
    Write-Host "Executing: $ScriptCommand"
    try {
        # Execute the command
        Invoke-Expression $ScriptCommand -ErrorAction Stop

        # Check for errors in the script execution
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error occurred while executing: $ScriptCommand. Exit code: $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    } catch {
        Write-Error "Error occurred while executing: $ScriptCommand. Exiting."
        Write-Error $_.Exception.Message
        exit 1
    }
}

# Sequential script execution with error handling
try {
    # Build the script paths
    $RestoreScript = Join-Path -Path $ScriptDirectory -ChildPath 'RestoreSetupLVSource.ps1'
    $CloseScript = Join-Path -Path $ScriptDirectory -ChildPath 'Close_LabVIEW.ps1'

    # Restore setup for LabVIEW 2021 (32-bit)
    $Command1 = "& `"$RestoreScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -LabVIEW_Project `"$LabVIEW_Project`" -Build_Spec `'Editor Packed Library`'"

    Execute-Script $Command1

    # Close LabVIEW 2021 (32-bit)
    $Command2 = "& `"$CloseScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32"

    Execute-Script $Command2

    # Restore setup for LabVIEW 2021 (64-bit)
    $Command3 = "& `"$RestoreScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`" -LabVIEW_Project `"$LabVIEW_Project`" -Build_Spec `'Editor Packed Library`'"

    Execute-Script $Command3

    # Close LabVIEW 2021 (64-bit)
    $Command4 = "& `"$CloseScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 64"

    Execute-Script $Command4

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Host "All scripts executed successfully." -ForegroundColor Green
