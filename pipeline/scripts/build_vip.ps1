# Example usage:
# .\build_vip.ps1 -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"  -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -VIP_LVVersion "2024"

param (
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$VIPBPath,
    [string]$VIP_LVVersion
)

# Construct VIP_LVVersion_A
if ($VIP_LVVersion -eq "2021" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "21.0 (64-bit)"
} elseif ($VIP_LVVersion -eq "2021" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "21.0"
} elseif ($VIP_LVVersion -eq "2022" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "22.3 (64-bit)"
} elseif ($VIP_LVVersion -eq "2022" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "22.3"
} elseif ($VIP_LVVersion -eq "2023" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "23.3 (64-bit)"
} elseif ($VIP_LVVersion -eq "2023" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "23.3"
} elseif ($VIP_LVVersion -eq "2024" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "24.3 (64-bit)"
} elseif ($VIP_LVVersion -eq "2024" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "24.3"
} else {
    Write-Output "Unsupported VIP_LVVersion or SupportedBitness"
    exit 1
}
 Write-Output "Building VI Package for $VIP_LVVersion"
# Construct the script for execution
$script = @"

g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v "$RelativePath\Tooling\deployment\BuildVIP.vi" -- "$RelativePath\Tooling\deployment\NI Icon editor.vipb" "$VIP_LVVersion_A"
g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v QuitLabVIEW

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
