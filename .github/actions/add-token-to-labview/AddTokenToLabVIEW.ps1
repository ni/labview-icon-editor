<#
.SYNOPSIS
    Adds a custom library path token to the LabVIEW INI file.

.DESCRIPTION
    Uses g-cli to call Create_LV_INI_Token.vi, inserting the provided path into
    the LabVIEW INI file under the Localhost.LibraryPaths token. This enables
    LabVIEW to locate local project libraries during development or builds.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW 2021 (21.0) only.

.PARAMETER SupportedBitness
    Target bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepoRoot
    Path to the repository root that should be added to the INI token.

.EXAMPLE
    .\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RepoRoot "C:\labview-icon-editor"
#>

param(
    [ValidateSet('2021')]
    [string]$MinimumSupportedLVVersion = '2021',
    [string]$SupportedBitness,
    [string]$RepoRoot
)

# Construct the command
$script = @"
g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v "$RepoRoot\Tooling\deployment\Create_LV_INI_Token.vi" -- "LabVIEW" "Localhost.LibraryPaths" "$RepoRoot"
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
