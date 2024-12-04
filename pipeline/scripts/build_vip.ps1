# Example usage:
# .\build_vip.ps1 --lv-ver 2021 --arch 64 -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"  -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -MinimumSupportedLVVersion 2021
param (
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$VIPBPath,
    [string]$MinimumSupportedLVVersion
)

# Resolve paths for consistency
try {
    $ResolvedRelativePath = Resolve-Path -Path $RelativePath -ErrorAction Stop
    $ResolvedVIPBPath = Join-Path -Path $ResolvedRelativePath -ChildPath $VIPBPath -ErrorAction Stop
} catch {
    Write-Error "Error resolving paths. Ensure RelativePath and VIPBPath are valid."
    exit 1
}

# Construct VIP_LVVersion_A based on parameters
switch ("$MinimumSupportedLVVersion-$SupportedBitness") {
    "2021-64" { $VIP_LVVersion_A = "21.0 (64-bit)" }
    "2021-32" { $VIP_LVVersion_A = "21.0" }
    "2022-64" { $VIP_LVVersion_A = "22.3 (64-bit)" }
    "2022-32" { $VIP_LVVersion_A = "22.3" }
    "2023-64" { $VIP_LVVersion_A = "23.3 (64-bit)" }
    "2023-32" { $VIP_LVVersion_A = "23.3" }
    "2024-64" { $VIP_LVVersion_A = "24.3 (64-bit)" }
    "2024-32" { $VIP_LVVersion_A = "24.3" }
    default {
        Write-Error "Unsupported MinimumSupportedLVVersion or SupportedBitness."
        exit 1
    }
}

Write-Output "Building VI Package for LabVIEW $VIP_LVVersion_A..."

# Construct the script for execution
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness "$ResolvedRelativePath\Tooling\deployment\Modify_VIPB_LabVIEW_Version.vi" -- "$ResolvedVIPBPath" "$VIP_LVVersion_A"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness "$ResolvedRelativePath\Tooling\deployment\BuildVIP.vi" -- "$ResolvedVIPBPath" "$VIP_LVVersion_A"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness QuitLabVIEW
"@

# Output the script for debugging
Write-Output "Executing the following commands:"
Write-Output $script

# Execute the script and handle potential errors
try {
    Invoke-Expression $script
    Write-Host "Successfully built VI package: $ResolvedVIPBPath"
} catch {
    Write-Error "An error occurred while executing the build commands."
    exit 1
}
