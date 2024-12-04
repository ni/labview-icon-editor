#Example: .\Build_lvlibp.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath
)

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness lvbuildspec -- -av -p "$RelativePath\lv_icon_editor.lvproj" -b "Editor Packed Library"
"@

Write-Output "Executing the following command:"
Write-Output $script
            
# Execute the command
Invoke-Expression $script

Write-Host "Build Editor Packed Library for LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit)"
