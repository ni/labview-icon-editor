# Example usage:
# .\Apply_vipc.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor" -VIPCPath "Tooling\deployment\Dependencies.vipc" -VIP_LVVersion "2024"

param (
    [string]$MinimumSupportedLVVersion,
	[string]$VIP_LVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$LabVIEW_Project,
    [string]$VIPCPath
)

 Write-Output "Applying dependencies on LabVIEW "
# Construct the script for execution
$script = @"

g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$RelativePath\Tooling\Deployment\Switch_VIPM_Target.vi" -- "$MinimumSupportedLVVersion"

g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v vipc -- $RelativePath\$VIPCPath

"@

# Add conditional execution for the second g-cli call
if ($VIP_LVVersion -ne $MinimumSupportedLVVersion) {
    $script += @"

g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v QuitLabVIEW


g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v vipc -- $RelativePath\$VIPCPath


"@
}

# Always include the third g-cli call
$script += @"


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
