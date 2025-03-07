#Example: .\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor" -LabVIEW_Project "lv_icon_editor" -Build_Spec "Editor Packed Library" 
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$LabVIEW_Project,
    [string]$Build_Spec
)

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$RelativePath\Tooling\RestoreSetupLVSource.vi" -- "$RelativePath\$LabVIEW_Project.lvproj" "$Build_Spec"
"@

Write-Output "Executing the following command:"
Write-Output $script

# Execute the command and check for errors
try {
    Invoke-Expression $script

    # Check the exit code of the executed command
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Unzip vi.lib/LabVIEW Icon API from LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) and remove localhost.library path from ini file"
    }
} catch {
    Write-Host ""
    exit 0
}