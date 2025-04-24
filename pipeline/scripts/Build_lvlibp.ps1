#Example: .\Build_lvlibp.ps1 - -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor" -Major 1 -Minor 0 -Patch 0 -Build 0 -Commit "Placeholder"
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [Int32]$Major,
    [Int32]$Minor,
    [Int32]$Patch,
    [Int32]$Build,
    [string]$Commit
)

Write-Output "PPL Version: $Major.$Minor.$Patch.$Build"
Write-Output "Commit: $Commit"

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness lvbuildspec -- -v "$Major.$Minor.$Patch.$Build" -p "$RelativePath\lv_icon_editor.lvproj" -b "Editor Packed Library"
"@
Write-Output "Executing the following command:"
Write-Output $script

# Execute the command
Invoke-Expression $script

# Check the exit code
if ($LASTEXITCODE -ne 0) {
    g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness QuitLabVIEW
    Write-Host "Build failed with exit code $LASTEXITCODE."
    exit 1
} else {
    Write-Host "Build succeeded."
    exit 0
}
