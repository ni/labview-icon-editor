<#
.SYNOPSIS
    Applies a .vipc file to a given LabVIEW version/bitness.

.EXAMPLE
    .\Applyvipc_new.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor" -VIPCPath "Tooling\deployment\Dependencies.vipc" -VIP_LVVersion "2021"
#>

Param (
    [string]$MinimumSupportedLVVersion,
    [string]$VIP_LVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$VIPCPath
)

# -------------------------
# 1) Resolve Paths & Validate
# -------------------------
try {
    $ResolvedRelativePath = Resolve-Path -Path $RelativePath -ErrorAction Stop
    # Join-Path ensures we combine paths consistently for the .vipc file
    $ResolvedVIPCPath = Join-Path -Path $ResolvedRelativePath -ChildPath $VIPCPath -ErrorAction Stop

    # Optionally, verify that the .vipc file actually exists (unlike in Script 1, 
    # we do NOT create it if it’s missing, because .vipc must typically exist)
    if (-not (Test-Path $ResolvedVIPCPath)) {
        Write-Error "The .vipc file does not exist at '$ResolvedVIPCPath'."
        exit 1
    }
}
catch {
    Write-Error "Error resolving paths. Ensure RelativePath and VIPCPath are valid."
    exit 1
}

# -------------------------
# 2) Build LabVIEW Version Strings (Switch-based)
#    For the primary VIP_LVVersion (A) and the minimum version (B)
# -------------------------
switch ("$VIP_LVVersion-$SupportedBitness") {
    "2021-64" { $VIP_LVVersion_A = "21.0 (64-bit)" }
    "2021-32" { $VIP_LVVersion_A = "21.0" }
    "2022-64" { $VIP_LVVersion_A = "22.3 (64-bit)" }
    "2022-32" { $VIP_LVVersion_A = "22.3" }
    "2023-64" { $VIP_LVVersion_A = "23.3 (64-bit)" }
    "2023-32" { $VIP_LVVersion_A = "23.3" }
    "2024-64" { $VIP_LVVersion_A = "24.3 (64-bit)" }
    "2024-32" { $VIP_LVVersion_A = "24.3" }
    default {
        Write-Error "Unsupported VIP_LVVersion or SupportedBitness for VIP_LVVersion_A."
        exit 1
    }
}

switch ("$MinimumSupportedLVVersion-$SupportedBitness") {
    "2021-64" { $VIP_LVVersion_B = "21.0 (64-bit)" }
    "2021-32" { $VIP_LVVersion_B = "21.0" }
    "2022-64" { $VIP_LVVersion_B = "22.3 (64-bit)" }
    "2022-32" { $VIP_LVVersion_B = "22.3" }
    "2023-64" { $VIP_LVVersion_B = "23.3 (64-bit)" }
    "2023-32" { $VIP_LVVersion_B = "23.3" }
    "2024-64" { $VIP_LVVersion_B = "24.3 (64-bit)" }
    "2024-32" { $VIP_LVVersion_B = "24.3" }
    default {
        Write-Error "Unsupported MinimumSupportedLVVersion or SupportedBitness for VIP_LVVersion_B."
        exit 1
    }
}

Write-Output "Applying dependencies for LabVIEW $VIP_LVVersion_B..."

# -------------------------
# 3) Construct the Script to Execute
# -------------------------
# We’ll build a multiline string that includes all necessary commands.
# We include conditional commands if $VIP_LVVersion -ne $MinimumSupportedLVVersion.

# First, always apply dependencies for the “minimum supported” version
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$($ResolvedRelativePath)\Tooling\Deployment\Applyvipc.vi" -- "$ResolvedVIPCPath" "$VIP_LVVersion_B"
"@

# If we need to switch to a different version, we’ll quit LabVIEW and re-apply
if ($VIP_LVVersion -ne $MinimumSupportedLVVersion) {
    $script += @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v QuitLabVIEW
g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v "$($ResolvedRelativePath)\Tooling\Deployment\Applyvipc.vi" -- "$ResolvedVIPCPath" "$VIP_LVVersion_A"
"@
}

# Finally, always quit LabVIEW from the “current” version
$script += @"
g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v QuitLabVIEW
"@

# -------------------------
# 4) Output the script for debugging
# -------------------------
Write-Output "Executing the following commands:"
Write-Output $script

# -------------------------
# 5) Execute the Script & Handle Errors (Try/Catch with Invoke-Expression)
# -------------------------
try {
    Invoke-Expression $script
    Write-Host "Successfully applied dependencies to LabVIEW: $VIP_LVVersion_B (and potentially $VIP_LVVersion_A if switched)."
}
catch {
    Write-Error "An error occurred while applying the .vipc dependencies."
    exit 1
}
