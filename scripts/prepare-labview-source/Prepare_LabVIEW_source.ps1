<#
.SYNOPSIS
    Prepares LabVIEW source code for building.

.DESCRIPTION
    Executes the PrepareIESource.vi via g-cli to unzip required components and
    update the LabVIEW configuration, ensuring the project is ready for
    subsequent build steps.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version used by g-cli.

.PARAMETER SupportedBitness
    Target bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root containing the project.

.PARAMETER LabVIEW_Project
    Name of the LabVIEW project (without extension).

.PARAMETER Build_Spec
    Name of the build specification to prepare.

.EXAMPLE
    .\Prepare_LabVIEW_source.ps1 -Package_LabVIEW_Version "2021" -SupportedBitness "64" -RepositoryPath "C:\labview icon editor" -LabVIEW_Project "lv_icon_editor" -Build_Spec "Editor Packed Library"
#>

param(
[Parameter(Mandatory = $true)]
[Alias('MinimumSupportedLVVersion')]
[string]$Package_LabVIEW_Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet("32", "64", IgnoreCase = $true)]
    [string]$SupportedBitness,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $true)]
    [string]$LabVIEW_Project,

    [Parameter(Mandatory = $true)]
    [string]$Build_Spec
)

$ErrorActionPreference = 'Stop'

$projectPath = if ([System.IO.Path]::IsPathRooted($LabVIEW_Project)) {
    $LabVIEW_Project
} else {
    Join-Path -Path $RepositoryPath -ChildPath "$LabVIEW_Project.lvproj"
}
if (-not (Test-Path -LiteralPath $projectPath)) {
    throw "LabVIEW project not found at $projectPath"
}

$prepareViPath = Join-Path -Path $RepositoryPath -ChildPath 'Tooling\PrepareIESource.vi'
if (-not (Test-Path -LiteralPath $prepareViPath)) {
    throw "PrepareIESource VI not found under Tooling (expected PrepareIESource.vi)"
}

$gcliArgs = @(
'--lv-ver', $Package_LabVIEW_Version,
    '--arch', $SupportedBitness,
    '-v', $prepareViPath,
    '--',
    'LabVIEW',
    'Localhost.LibraryPaths',
    $projectPath,
    $Build_Spec
)

Write-Information ("Executing g-cli: {0}" -f ($gcliArgs -join ' ')) -InformationAction Continue
& g-cli @gcliArgs

if ($LASTEXITCODE -eq 0) {
    Write-Information "Success: Process completed. Unzipped vi.lib/LabVIEW Icon API and updated INI." -InformationAction Continue
    exit 0
}

Write-Error "Command execution failed with exit code $LASTEXITCODE."
exit $LASTEXITCODE

