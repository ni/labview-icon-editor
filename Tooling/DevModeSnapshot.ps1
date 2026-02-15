#Requires -Version 7.0
<#
.SYNOPSIS
    Captures a filesystem snapshot for dev-mode recovery.

.DESCRIPTION
    Copies LabVIEW.ini, LabVIEW Icon API (folder or zip), and lv_icon.*
    for each supported bitness so dev-mode changes can be restored.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    One or more bitness values ("32", "64") to snapshot (default: both).

.PARAMETER RepoRoot
    Optional path to the repository root.

.PARAMETER SnapshotRoot
    Optional path to use for the snapshot root.

.PARAMETER SnapshotName
    Optional snapshot folder name when SnapshotRoot is not provided.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64', IgnoreCase = $true)]
    [string[]]$SupportedBitness = @('32', '64'),

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotRoot,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotName
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($PathOverride)) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        try {
            $gitRoot = git -C $scriptRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path -Path $gitRoot.Trim()).Path
            }
        } catch {
            Write-Verbose ("git rev-parse failed: {0}" -f $_.Exception.Message)
        }
    }

    return (Resolve-Path -Path (Join-Path $scriptRoot '..')).Path
}

function Get-LabVIEWInstallRoot {
    param(
        [string]$Version,
        [string]$Bitness
    )

    $candidates = @()
    $regPaths = @()
    if ($Bitness -eq '32') {
        $candidates += "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $Version"
    } else {
        $candidates += "C:\Program Files\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\National Instruments\LabVIEW $Version"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate) {
            return $candidate
        }
    }

    foreach ($regPath in $regPaths) {
        try {
            $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
            foreach ($name in @('Path', 'InstallDir', 'InstallPath')) {
                $value = $props.$name
                if (-not [string]::IsNullOrWhiteSpace($value) -and (Test-Path -Path $value)) {
                    return $value
                }
            }
        } catch {
            continue
        }
    }

    return $null
}

function Resolve-SnapshotRoot {
    param(
        [string]$ResolvedRepoRoot,
        [string]$SnapshotRootOverride,
        [string]$SnapshotNameOverride
    )

    if (-not [string]::IsNullOrWhiteSpace($SnapshotRootOverride)) {
        $root = if ([System.IO.Path]::IsPathRooted($SnapshotRootOverride)) {
            $SnapshotRootOverride
        } else {
            Join-Path -Path $ResolvedRepoRoot -ChildPath $SnapshotRootOverride
        }
        return [System.IO.Path]::GetFullPath($root)
    }

    $baseRoot = $env:LVIE_ARTIFACT_ROOT
    if ([string]::IsNullOrWhiteSpace($baseRoot)) {
        $baseRoot = Join-Path -Path $ResolvedRepoRoot -ChildPath 'Tooling\logs'
    }
    $baseRoot = Join-Path -Path $baseRoot -ChildPath 'dev-mode-snapshots'
    $name = if ([string]::IsNullOrWhiteSpace($SnapshotNameOverride)) {
        Get-Date -Format 'yyyyMMdd-HHmmss'
    } else {
        $SnapshotNameOverride.Trim()
    }
    return (Join-Path -Path $baseRoot -ChildPath $name)
}

function New-DirectoryIfMissing {
    param(
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Copy-File {
    param(
        [string]$Source,
        [string]$Destination
    )

    $destDir = Split-Path -Parent -Path $Destination
    if (-not [string]::IsNullOrWhiteSpace($destDir)) {
        New-DirectoryIfMissing -Path $destDir
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Copy-Folder {
    param(
        [string]$Source,
        [string]$Destination
    )

    $destDir = Split-Path -Parent -Path $Destination
    if (-not [string]::IsNullOrWhiteSpace($destDir)) {
        New-DirectoryIfMissing -Path $destDir
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

$resolvedRepoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$versionHelper = Join-Path $resolvedRepoRoot 'Tooling\support\LabVIEWVersion.ps1'
$labviewYear = $LabVIEWVersion
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot
    $labviewYear = $versionInfo.Year
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}

$snapshotRootResolved = Resolve-SnapshotRoot -ResolvedRepoRoot $resolvedRepoRoot -SnapshotRootOverride $SnapshotRoot -SnapshotNameOverride $SnapshotName
if (Test-Path -Path $snapshotRootResolved) {
    throw "Snapshot root already exists: $snapshotRootResolved"
}
New-DirectoryIfMissing -Path $snapshotRootResolved

$manifest = [ordered]@{
    SnapshotVersion = 1
    CreatedUtc      = (Get-Date).ToUniversalTime().ToString('o')
    RepoRoot        = $resolvedRepoRoot
    LabVIEWYear     = $labviewYear
    SupportedBitness = $SupportedBitness
    SnapshotRoot    = $snapshotRootResolved
    Items           = @()
}

$bitnesses = $SupportedBitness | Select-Object -Unique
foreach ($bitness in $bitnesses) {
    $installRoot = Get-LabVIEWInstallRoot -Version $labviewYear -Bitness $bitness
    if (-not $installRoot) {
        throw "LabVIEW $labviewYear ($bitness-bit) install not found."
    }

    $bitnessRoot = Join-Path -Path $snapshotRootResolved -ChildPath ("bitness-{0}" -f $bitness)
    $iconApiDir = Join-Path -Path $installRoot -ChildPath 'vi.lib\LabVIEW Icon API'
    $iconApiZip = Join-Path -Path $installRoot -ChildPath 'vi.lib\LabVIEW Icon API.zip'
    $lvlibpPath = Join-Path -Path $installRoot -ChildPath 'resource\plugins\lv_icon.lvlibp'
    $shipPath = Join-Path -Path $installRoot -ChildPath 'resource\plugins\lv_icon.ship'
    $iniPath = Join-Path -Path $installRoot -ChildPath 'LabVIEW.ini'

    $iniPresent = Test-Path -Path $iniPath
    $iniSnapshot = $null
    if ($iniPresent) {
        $iniSnapshot = Join-Path -Path $bitnessRoot -ChildPath 'LabVIEW.ini'
        Copy-File -Source $iniPath -Destination $iniSnapshot
    }

    $iconApiFolderPresent = Test-Path -Path $iconApiDir
    $iconApiZipPresent = Test-Path -Path $iconApiZip
    $iconApiFolderSnapshot = $null
    $iconApiZipSnapshot = $null
    if ($iconApiFolderPresent) {
        $iconApiFolderSnapshot = Join-Path -Path $bitnessRoot -ChildPath 'vi.lib\LabVIEW Icon API'
        Copy-Folder -Source $iconApiDir -Destination $iconApiFolderSnapshot
    }
    if ($iconApiZipPresent) {
        $iconApiZipSnapshot = Join-Path -Path $bitnessRoot -ChildPath 'vi.lib\LabVIEW Icon API.zip'
        Copy-File -Source $iconApiZip -Destination $iconApiZipSnapshot
    }

    $lvlibpPresent = Test-Path -Path $lvlibpPath
    $shipPresent = Test-Path -Path $shipPath
    $lvlibpSnapshot = $null
    $shipSnapshot = $null
    if ($lvlibpPresent) {
        $lvlibpSnapshot = Join-Path -Path $bitnessRoot -ChildPath 'resource\plugins\lv_icon.lvlibp'
        Copy-File -Source $lvlibpPath -Destination $lvlibpSnapshot
    }
    if ($shipPresent) {
        $shipSnapshot = Join-Path -Path $bitnessRoot -ChildPath 'resource\plugins\lv_icon.ship'
        Copy-File -Source $shipPath -Destination $shipSnapshot
    }

    $manifest.Items += [ordered]@{
        Bitness                = $bitness
        InstallRoot            = $installRoot
        IniPath                = $iniPath
        IniPresent             = $iniPresent
        IniSnapshot            = $iniSnapshot
        IconApiFolder          = $iconApiDir
        IconApiFolderPresent   = $iconApiFolderPresent
        IconApiFolderSnapshot  = $iconApiFolderSnapshot
        IconApiZip             = $iconApiZip
        IconApiZipPresent      = $iconApiZipPresent
        IconApiZipSnapshot     = $iconApiZipSnapshot
        LvlibpPath             = $lvlibpPath
        LvlibpPresent          = $lvlibpPresent
        LvlibpSnapshot         = $lvlibpSnapshot
        ShipPath               = $shipPath
        ShipPresent            = $shipPresent
        ShipSnapshot           = $shipSnapshot
    }
}

$manifestPath = Join-Path -Path $snapshotRootResolved -ChildPath 'dev-mode-snapshot.json'
$manifest | ConvertTo-Json -Depth 7 | Set-Content -Path $manifestPath -Encoding utf8
Write-Host ("Dev mode snapshot saved at {0}" -f $snapshotRootResolved)
Write-Output $snapshotRootResolved


