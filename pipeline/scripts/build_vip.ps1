#Example: .\build_vip.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor" -LabVIEW_Project "lv_icon_editor" -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -VIP_LVVersion "2024"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$LabVIEW_Project,
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
# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$RelativePath\Tooling\Deployment\Switch_VIPM_Target.vi" -- "$VIP_LVVersion_A"

g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v QuitLabVIEW 

g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v vipb -- -b "$RelativePath\$VIPBPath" -av
"@

Write-Output "Executing the following command:"
Write-Output $script
            
# Execute the command
Invoke-Expression $script

Write-Host "Build finished."