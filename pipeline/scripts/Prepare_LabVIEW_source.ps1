# Example usage:
# .\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview icon editor" -LabVIEW_Project "lv_icon_editor" -Build_Spec "Editor Packed Library"

param(
    [Parameter(Mandatory = $true)]
    [string]$MinimumSupportedLVVersion,

    [Parameter(Mandatory = $true)]
    [ValidateSet("32", "64", IgnoreCase = $true)]
    [string]$SupportedBitness,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$RelativePath,

    [Parameter(Mandatory = $true)]
    [string]$LabVIEW_Project,

    [Parameter(Mandatory = $true)]
    [string]$Build_Spec
)

# Ensure paths with spaces are enclosed in double quotes
$escapedRelativePath = "`"$RelativePath`""
$escapedLabVIEWProjectPath = "`"$RelativePath\$LabVIEW_Project.lvproj`""
$escapedBuildSpec = "`"$Build_Spec`""

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v `"$RelativePath\Tooling\PrepareIESource.vi`" -- LabVIEW Localhost.LibraryPaths `"$RelativePath\$LabVIEW_Project.lvproj`" $Build_Spec
"@

Write-Output "Executing the following command:"
Write-Output $script

try {
    # Execute the command and check for errors
    Invoke-Expression $script

    # Check the exit code
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Success: Process completed."
        Write-Host "Unzipping vi.lib/LabVIEW Icon API from LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit)."
        Write-Host "Removing localhost.library path from ini file."
    } else {
        throw "Error: Command execution failed with exit code $LASTEXITCODE."
    }
} catch {
    Write-Error "An error occurred during execution: $_"
    Write-Error "Please check the parameters and ensure the command is valid."
    exit 1
}
