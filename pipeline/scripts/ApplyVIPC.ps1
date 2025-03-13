<#
.SYNOPSIS
    Applies a .vipc file to a given LabVIEW version/bitness.
    This version includes additional debug/verbose output.

.EXAMPLE
    .\applyvipc.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor-fork" -VIPCPath "Tooling\deployment\Dependencies.vipc" -VIP_LVVersion "2021" -Verbose
#>

[CmdletBinding()]  # Enables -Verbose and other common parameters
Param (
    [string]$MinimumSupportedLVVersion,
    [string]$VIP_LVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$VIPCPath
)

Write-Verbose "Script Name: $($MyInvocation.MyCommand.Definition)"
Write-Verbose "Parameters provided:"
Write-Verbose " - MinimumSupportedLVVersion: $MinimumSupportedLVVersion"
Write-Verbose " - VIP_LVVersion:             $VIP_LVVersion"
Write-Verbose " - SupportedBitness:          $SupportedBitness"
Write-Verbose " - RelativePath:              $RelativePath"
Write-Verbose " - VIPCPath:                  $VIPCPath"

# -------------------------
# 1) Resolve Paths & Validate
# -------------------------
try {
    Write-Verbose "Attempting to resolve the 'RelativePath'..."
    $ResolvedRelativePath = Resolve-Path -Path $RelativePath -ErrorAction Stop
    Write-Verbose "ResolvedRelativePath: $ResolvedRelativePath"

    Write-Verbose "Building full path for the .vipc file..."
    $ResolvedVIPCPath = Join-Path -Path $ResolvedRelativePath -ChildPath $VIPCPath -ErrorAction Stop
    Write-Verbose "ResolvedVIPCPath:     $ResolvedVIPCPath"

    # Verify that the .vipc file actually exists
    Write-Verbose "Checking if the .vipc file exists at the resolved path..."
    if (-not (Test-Path $ResolvedVIPCPath)) {
        Write-Error "The .vipc file does not exist at '$ResolvedVIPCPath'."
        exit 1
    }
    Write-Verbose "The .vipc file was found successfully."
}
catch {
    Write-Error "Error resolving paths. Ensure RelativePath and VIPCPath are valid. Details: $($_.Exception.Message)"
    exit 1
}

# -------------------------
# 2) Build LabVIEW Version Strings
# -------------------------
Write-Verbose "Determining LabVIEW version strings..."
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
Write-Verbose "VIP_LVVersion_A (for primary LVVersion): $VIP_LVVersion_A"
Write-Verbose "VIP_LVVersion_B (for minimum LVVersion): $VIP_LVVersion_B"

# -------------------------
# 3) Construct the Script to Execute
# -------------------------
Write-Verbose "Constructing the g-cli command script..."
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$($ResolvedRelativePath)\Tooling\Deployment\Applyvipc.vi" -- "$ResolvedVIPCPath" "$VIP_LVVersion_B"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$($ResolvedRelativePath)\Tooling\Deployment\Applyvipc.vi" -- "$ResolvedVIPCPath" "$VIP_LVVersion_B"
"@

if ($VIP_LVVersion -ne $MinimumSupportedLVVersion) {
    Write-Verbose "VIP_LVVersion and MinimumSupportedLVVersion differ; adding commands for $VIP_LVVersion..."
    $script += @"
g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v "$($ResolvedRelativePath)\Tooling\Deployment\Applyvipc.vi" -- "$ResolvedVIPCPath" "$VIP_LVVersion_A"
g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v "$($ResolvedRelativePath)\Tooling\Deployment\Applyvipc.vi" -- "$ResolvedVIPCPath" "$VIP_LVVersion_A"
"@
}

# -------------------------
# 4) Output the script for debugging
# -------------------------
Write-Output "Executing the following commands:"
Write-Output $script
Write-Verbose "Full script content (for debugging): `n$script"

# -------------------------
# 5) Execute the Script & Handle Errors (Try/Catch with Invoke-Expression)
# -------------------------
try {
    Write-Verbose "Starting Invoke-Expression to run g-cli commands..."
    Invoke-Expression $script
    Write-Host "Successfully applied dependencies to LabVIEW: $VIP_LVVersion_B" `
        " (and potentially $VIP_LVVersion_A if switched)."
}
catch {
    Write-Error "An error occurred while applying the .vipc dependencies. Details: $($_.Exception.Message)"
    exit 1
}
