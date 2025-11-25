<#
.SYNOPSIS
    Adds a custom library path token to the LabVIEW INI file.

.DESCRIPTION
    Uses g-cli to call Create_LV_INI_Token.vi, inserting the provided path into
    the LabVIEW INI file under the Localhost.LibraryPaths token. This enables
    LabVIEW to locate local project libraries during development or builds.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version used by g-cli (e.g., "2021").

.PARAMETER SupportedBitness
    Target bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root that should be added to the INI token.

.EXAMPLE
    .\AddTokenToLabVIEW.ps1 -Package_LabVIEW_Version "2021" -SupportedBitness "64" -RepositoryPath "C:\labview-icon-editor"
#>

param(
    [Parameter(Mandatory)][Alias('MinimumSupportedLVVersion')][string]$Package_LabVIEW_Version,
    [Parameter(Mandatory)][ValidateSet('32','64')][string]$SupportedBitness,
    [Parameter(Mandatory)][string]$RepositoryPath
)

$ErrorActionPreference = 'Stop'
$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$iniTokenVi = Join-Path -Path $RepositoryPath -ChildPath 'Tooling\deployment\Create_LV_INI_Token.vi'
if (-not (Test-Path -LiteralPath $iniTokenVi)) {
    throw "Missing VI required to add INI token: $iniTokenVi"
}

# Determine target folder for Localhost.LibraryPaths (folder that contains the project)
$project = Get-ChildItem -Path $RepositoryPath -Filter *.lvproj -File -Recurse | Select-Object -First 1
$tokenTarget = if ($project) {
    Split-Path -Parent $project.FullName
} else {
    $RepositoryPath
}

# Remove stale runner paths (e.g., double-rooted workspaces) before adding the current one.
$helperPath = Join-Path $PSScriptRoot 'LocalhostLibraryPaths.ps1'
if (-not (Test-Path $helperPath)) {
    throw "Missing helper script for cleaning LocalHost.LibraryPaths: $helperPath"
}
. $helperPath
Clear-StaleLibraryPaths -LvVersion $Package_LabVIEW_Version -Arch $SupportedBitness -RepositoryRoot $RepositoryPath

$_gcliArgs = @(
    '--lv-ver', $Package_LabVIEW_Version,
    '--arch', $SupportedBitness,
    '--',
    $iniTokenVi,
    '--',
    'LabVIEW',
    'Localhost.LibraryPaths',
    $SupportedBitness,
    $tokenTarget
)

Write-Information ("Invoking g-cli: {0}" -f ($_gcliArgs -join ' ')) -InformationAction Continue
Write-Information ("Localhost.LibraryPaths target: {0}" -f $tokenTarget) -InformationAction Continue

$gcli = Get-Command g-cli -ErrorAction SilentlyContinue
if (-not $gcli) {
    throw "g-cli is not available on PATH; cannot add INI token."
}

$output = & g-cli @_gcliArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    $joined = ($output -join '; ')
    throw ("g-cli failed with exit code {0}: {1} | cmd: {2}" -f $LASTEXITCODE, $joined, ($_gcliArgs -join ' '))
}

Write-Information "Created localhost.library path in ini file." -InformationAction Continue

# Ensure canonical INI also carries the token (g-cli may write to ProgramData/user INI)
try {
    Add-LibraryPathToken -LvVersion $Package_LabVIEW_Version -Arch $SupportedBitness -TokenPath $tokenTarget -RepositoryRoot $RepositoryPath
}
catch {
    Write-Warning ("Failed to mirror LocalHost.LibraryPaths into canonical INI: {0}" -f $_.Exception.Message)
}
