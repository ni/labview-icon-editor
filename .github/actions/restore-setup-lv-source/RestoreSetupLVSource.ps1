<#
.SYNOPSIS
    Restores the LabVIEW source setup from a packaged state.

.DESCRIPTION
    Calls RestoreSetupLVSource.vi via g-cli to unzip the LabVIEW Icon API and
    remove the Localhost.LibraryPaths token from the LabVIEW INI file.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version used to run g-cli.

.PARAMETER SupportedBitness
    Bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root.

.PARAMETER LabVIEW_Project
    Name of the LabVIEW project (without extension).

.PARAMETER Build_Spec
    Build specification name within the project.

.EXAMPLE
    .\RestoreSetupLVSource.ps1 -Package_LabVIEW_Version "2021" -SupportedBitness "64" -RepositoryPath "C:\labview-icon-editor" -LabVIEW_Project "lv_icon_editor" -Build_Spec "Editor Packed Library"
#>
param(
    [Alias('MinimumSupportedLVVersion')]
    [string]$Package_LabVIEW_Version,
    [ValidateSet('32','64')]
    [string]$SupportedBitness,
    [string]$RepositoryPath,
    [string]$LabVIEW_Project,
    [string]$Build_Spec
)

$ErrorActionPreference = 'Stop'

$gcliArgs = @(
    '--lv-ver', $Package_LabVIEW_Version,
    '--arch', $SupportedBitness,
    '-v', "$RepositoryPath\Tooling\RestoreSetupLVSource.vi",
    '--',
    "$RepositoryPath\$LabVIEW_Project.lvproj",
    "$Build_Spec"
)

Write-Information ("Executing g-cli: {0}" -f ($gcliArgs -join ' ')) -InformationAction Continue
& g-cli @gcliArgs

if ($LASTEXITCODE -eq 0) {
    Write-Information "Unzipped vi.lib/LabVIEW Icon API and removed localhost.library path from ini file." -InformationAction Continue
    exit 0
}

Write-Warning "g-cli exited with $LASTEXITCODE during restore."
exit $LASTEXITCODE
