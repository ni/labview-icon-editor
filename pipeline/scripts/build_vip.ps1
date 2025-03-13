# Example usage:
# .\build_vip.ps1 --lv-ver 2021 --arch 64 -SupportedBitness "64" -RelativePath "C:\labview-icon-editor-fork"  -VIPBPath "Tooling\deployment\NI Icon editor.vipb" -MinimumSupportedLVVersion 2021 -LabVIEWMinorRevision 3 -Major 1 -Minor 0 -Patch 0 -Build 1 -Commit "Placeholder" -ReleaseNotesFile "C:\labview-icon-editor-fork\Tooling\deployment\release_notes.md" -LabVIEWMinorRevision 
param (
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$VIPBPath,

    # The "year" portion: e.g. 2021, 2022, 2023, etc.
    [int]$MinimumSupportedLVVersion,

    # New parameter for specifying .0 or .3
    [ValidateSet("0","3")]
    [string]$LabVIEWMinorRevision = "0",

    [Int32]$Major,
    [Int32]$Minor,
    [Int32]$Patch,
    [Int32]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile
)

# Resolve paths for consistency
try {
    $ResolvedRelativePath = Resolve-Path -Path $RelativePath -ErrorAction Stop
    $ResolvedVIPBPath = Join-Path -Path $ResolvedRelativePath -ChildPath $VIPBPath -ErrorAction Stop
} catch {
    Write-Error "Error resolving paths. Ensure RelativePath and VIPBPath are valid."
    exit 1
}

# If ReleaseNotesFile does not exist, create it
if (-not (Test-Path $ReleaseNotesFile)) {
    Write-Host "Release notes file '$ReleaseNotesFile' does not exist. Creating it..."
    New-Item -ItemType File -Path $ReleaseNotesFile -Force | Out-Null
}

#
# Calculate the LabVIEW Version String
# -----------------------------------
# Example:
#   -MinimumSupportedLVVersion 2021
#   -LabVIEWMinorRevision "0"
# => "21.0 (64-bit)"  or "21.0" (for 32-bit)
#

# Subtract 2000 to turn e.g. 2021 => 21, 2023 => 23
$lvNumericMajor = $MinimumSupportedLVVersion - 2000

# Construct the final string (e.g. 21.0 or 22.3)
$lvNumericVersion = "$($lvNumericMajor).$LabVIEWMinorRevision"

# Append (64-bit) if needed
if ($SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "$lvNumericVersion (64-bit)"
} else {
    $VIP_LVVersion_A = $lvNumericVersion
}

Write-Output "Building VI Package for LabVIEW $VIP_LVVersion_A..."

# 
# Construct the script for execution
# 
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness "$($ResolvedRelativePath)\Tooling\deployment\Modify_VIPB_LabVIEW_Version.vi" -- "$ResolvedVIPBPath" "$VIP_LVVersion_A"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness vipb -- --buildspec "$ResolvedVIPBPath" -v "$Major.$Minor.$Patch.$Build" --release-notes "$ReleaseNotesFile" --timeout 300
"@

Write-Output "Executing the following commands:"
Write-Output $script

# Execute
try {
    Invoke-Expression $script
    Write-Host "Successfully built VI package: $ResolvedVIPBPath"
} catch {
    Write-Error "An error occurred while executing the build commands."
    exit 1
}
