<#
.SYNOPSIS
    Builds the Editor Packed Library (.lvlibp) using g-cli.

.DESCRIPTION
    Invokes the LabVIEW build specification "Editor Packed Library" through
    g-cli, embedding the provided version information and commit identifier.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).
    Alias: MinimumSupportedLVVersion.

.PARAMETER SupportedBitness
    Bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepoRoot
    Path to the repository root where the project file resides.

.PARAMETER Major
    Major version component for the PPL.

.PARAMETER Minor
    Minor version component for the PPL.

.PARAMETER Patch
    Patch version component for the PPL.

.PARAMETER Build
    Build number component for the PPL.

.PARAMETER Commit
    Commit hash or identifier recorded in the build.

.EXAMPLE
    .\Build_lvlibp.ps1 -LabVIEWVersion "2021" -SupportedBitness "64" -RepoRoot "C:\labview-icon-editor" -Major 1 -Minor 0 -Patch 0 -Build 0 -Commit "Placeholder"
#>
param(
    [Alias('MinimumSupportedLVVersion')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '2021',
    [string]$SupportedBitness,
    [string]$RepoRoot,
    [string]$WorktreeRoot,
    [switch]$SkipWorktreeRootCheck,
    [Int32]$Major,
    [Int32]$Minor,
    [Int32]$Patch,
    [Int32]$Build,
    [string]$Commit,
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 0
)

Write-Output "PPL Version: $Major.$Minor.$Patch.$Build"
Write-Output "Commit: $Commit"

$resolvedRepoRoot = $RepoRoot
if ($resolvedRepoRoot) {
    $resolvedRepoRoot = (Resolve-Path -Path $resolvedRepoRoot -ErrorAction Stop).Path
    $RepoRoot = $resolvedRepoRoot
    $preflightScript = Join-Path -Path $resolvedRepoRoot -ChildPath 'Tooling\Invoke-Preflight.ps1'
    if (Test-Path -Path $preflightScript) {
        . $preflightScript
        $scriptArgs = Convert-BoundParametersToArgumentList -BoundParameters $PSBoundParameters
        $relativeScript = if ($PSCommandPath) { Get-RepoRelativePath -RepoRoot $resolvedRepoRoot -Path $PSCommandPath } else { $null }
        $preflight = Invoke-Preflight `
            -RepoRoot $resolvedRepoRoot `
            -WorktreeRoot $WorktreeRoot `
            -LabVIEWVersion $LabVIEWVersion `
            -LabVIEWBitness $SupportedBitness `
            -SkipWorktreeRootCheck:$SkipWorktreeRootCheck `
            -AutoWorktree:$false `
            -ScriptPath $relativeScript `
            -ScriptArguments $scriptArgs
        if ($preflight.Reinvoked) {
            return
        }
        $resolvedRepoRoot = $preflight.RepoRoot
        $RepoRoot = $resolvedRepoRoot
    }
}

$labviewYear = $LabVIEWVersion
if ($RepoRoot) {
    $versionHelper = Join-Path -Path $RepoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
    if (Test-Path -Path $versionHelper) {
        . $versionHelper
        $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $RepoRoot
        $labviewYear = $versionInfo.Year
    }
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    $labviewYear = '2021'
}

function Invoke-CloseLabVIEWSafely {
    param(
        [string]$Version,
        [string]$Bitness
    )

    $closeScript = Join-Path -Path $RepoRoot -ChildPath '.github\actions\close-labview\Close_LabVIEW.ps1'
    if (Test-Path -Path $closeScript) {
        try {
            & $closeScript -LabVIEWVersion $Version -SupportedBitness $Bitness | Out-Null
        } catch {
            Write-Warning ("Close_LabVIEW.ps1 failed: {0}" -f $_.Exception.Message)
        }
        return
    }

    try {
        & g-cli --lv-ver $Version --arch $Bitness QuitLabVIEW | Out-Null
    } catch {
        Write-Warning ("Failed to close LabVIEW: {0}" -f $_.Exception.Message)
    }
}

$gcliArgs = @(
    '--lv-ver', $labviewYear,
    '--arch', $SupportedBitness
)
if ($ConnectTimeoutMs -gt 0) {
    $gcliArgs += @('--connect-timeout', $ConnectTimeoutMs)
}
$gcliArgs += @(
    'lvbuildspec',
    '--',
    '-v', "$Major.$Minor.$Patch.$Build",
    '-p', "$RepoRoot\lv_icon_editor.lvproj",
    '-b', 'Editor Packed Library'
)

Write-Output "Executing the following command:"
Write-Output ("g-cli {0}" -f ($gcliArgs -join ' '))

& g-cli @gcliArgs

# Check the exit code
if ($LASTEXITCODE -ne 0) {
    Invoke-CloseLabVIEWSafely -Version $labviewYear -Bitness $SupportedBitness
    Write-Host "Build failed with exit code $LASTEXITCODE."
    exit 1
} else {
    Write-Host "Build succeeded."
    exit 0
}

