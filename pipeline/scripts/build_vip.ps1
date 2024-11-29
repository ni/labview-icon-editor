# Example usage:
# .\build_vip.ps1 --lv-ver 2021 --arch 64 -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"  -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -MinimumSupportedLVVersion 2021

param (
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$VIPBPath,
    [string]$MinimumSupportedLVVersion
)

# Construct VIP_LVVersion_A
if ($MinimumSupportedLVVersion -eq "2021" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "21.0 (64-bit)"
} elseif ($MinimumSupportedLVVersion -eq "2021" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "21.0"
} elseif ($MinimumSupportedLVVersion -eq "2022" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "22.3 (64-bit)"
} elseif ($MinimumSupportedLVVersion -eq "2022" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "22.3"
} elseif ($MinimumSupportedLVVersion -eq "2023" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "23.3 (64-bit)"
} elseif ($MinimumSupportedLVVersion -eq "2023" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "23.3"
} elseif ($MinimumSupportedLVVersion -eq "2024" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "24.3 (64-bit)"
} elseif ($MinimumSupportedLVVersion -eq "2024" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "24.3"
} else {
    Write-Output "Unsupported VIP_LVVersion or SupportedBitness"
    exit 1
}
 Write-Output "Building VI Package for $MinimumSupportedLVVersion"
# Construct the script for execution
$script = @"

g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$RelativePath\Tooling\deployment\Modify_VIPB_LabVIEW_Version.vi" -- "$RelativePath\Tooling\deployment\NI Icon editor.vipb" "$VIP_LVVersion_A"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$RelativePath\Tooling\deployment\BuildVIP.vi" -- "$RelativePath\Tooling\deployment\NI Icon editor.vipb" "$VIP_LVVersion_A"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v QuitLabVIEW

"@

# Output the script for debugging
Write-Output "Executing the following command:"
Write-Output $script

# Execute the script
try {
    Invoke-Expression $script
    Write-Host "Build finished successfully."
} catch {
    Write-Error "An error occurred while executing the command."
    exit 1
}
