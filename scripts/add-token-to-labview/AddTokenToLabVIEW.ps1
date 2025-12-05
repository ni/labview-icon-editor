<#
.SYNOPSIS
    Adds a custom library path token to the LabVIEW INI file.

.DESCRIPTION
    Inserts the provided path into LabVIEW INI LocalHost.LibraryPaths using
    direct ini edits (no Create_LV_INI_Token.vi). This enables LabVIEW to
    locate local project libraries during development or builds.

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

# Determine target folder for Localhost.LibraryPaths (folder that contains the project)
$project = Get-ChildItem -Path $RepositoryPath -Filter *.lvproj -File -Recurse | Select-Object -First 1
$tokenTarget = if ($project) {
    Split-Path -Parent $project.FullName
} else {
    $RepositoryPath
}

# Guard: warn for temp/ephemeral worktrees; allow override to proceed
$normTarget = ([System.IO.Path]::GetFullPath($tokenTarget)).ToLowerInvariant()
$disallowed = @(
    '\appdata\local\temp\lv-ie-worktree',
    '\appdata\local\temp\lv-ie-test-worktree',
    '\.tmp-devmode-worktrees'
)
$allowTemp = $env:ORCH_ALLOW_TEMP_TOKEN -eq '1' -or $env:ALLOW_TEMP_LV_TOKEN -eq '1'
foreach ($pattern in $disallowed) {
    if ($normTarget -like "*$pattern*") {
        $msg = "Writing LocalHost.LibraryPaths for temporary worktree path: $tokenTarget"
        if ($allowTemp) {
            Write-Warning "$msg (override allowed via ORCH_ALLOW_TEMP_TOKEN/ALLOW_TEMP_LV_TOKEN)"
        } else {
            Write-Warning "$msg (proceeding; previously blocked)"
        }
        break
    }
}

# Remove stale runner paths (e.g., double-rooted workspaces) before adding the current one.
$helperPath = Join-Path $PSScriptRoot 'LocalhostLibraryPaths.ps1'
if (-not (Test-Path $helperPath)) {
    throw "Missing helper script for cleaning LocalHost.LibraryPaths: $helperPath"
}
. $helperPath
Clear-StaleLibraryPaths -LvVersion $Package_LabVIEW_Version -Arch $SupportedBitness -RepositoryRoot $RepositoryPath -Force -TargetPath $tokenTarget

Write-Information ("Setting Localhost.LibraryPaths to: {0}" -f $tokenTarget) -InformationAction Continue
try {
    # Directly write LocalHost.LibraryPaths via helper (no Create_LV_INI_Token.vi)
    Add-LibraryPathToken -LvVersion $Package_LabVIEW_Version -Arch $SupportedBitness -TokenPath $tokenTarget -RepositoryRoot $RepositoryPath
    Write-Information "Updated LocalHost.LibraryPaths via INI helper." -InformationAction Continue
}
catch {
    throw ("Failed to set LocalHost.LibraryPaths: {0}" -f $_.Exception.Message)
}
