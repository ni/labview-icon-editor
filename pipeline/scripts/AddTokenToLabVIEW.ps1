# Example: .\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"

param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath
)

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$RelativePath\Tooling\deployment\Create_LV_INI_Token.vi" -- "LabVIEW" "Localhost.LibraryPaths" "$RelativePath"
"@

Write-Output "Executing the following command:"
Write-Output $script

# Execute the command and check for errors
try {
    Invoke-Expression $script

    # Check the exit code of the executed command
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Create localhost.library path from ini file"
    }
} catch {
    Write-Host ""
    exit 0
}