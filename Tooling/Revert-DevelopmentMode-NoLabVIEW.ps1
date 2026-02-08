#Requires -Version 7.0
<#
.SYNOPSIS
    Reverts LabVIEW Icon Editor development mode without launching LabVIEW.

.DESCRIPTION
    Performs file-system and INI edits to mirror the packaged state:
    - unzips vi.lib\LabVIEW Icon API.zip back to vi.lib\LabVIEW Icon API
    - renames resource\plugins\lv_icon.ship to lv_icon.lvlibp
    - removes RepoRoot from Localhost.LibraryPaths in LabVIEW.ini
    This is intended for local testing; official revert can use the LabVIEW-based workflow.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    One or more bitness values ("32", "64") to run (default: both).

.PARAMETER RepoRoot
    Optional path to the repository root.

.PARAMETER ContractPath
    Optional path to the dev-mode contract JSON file.

.PARAMETER SkipProcessCheck
    Skip checking for running LabVIEW or g-cli processes.

.PARAMETER SkipRepoVersionCheck
    When LabVIEWVersion is provided, skip strict .lvversion equality validation.
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
    [string]$ContractPath,

    [Parameter(Mandatory = $false)]
    [switch]$SkipProcessCheck,

    [Parameter(Mandatory = $false)]
    [switch]$SkipRepoVersionCheck
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

function Resolve-PathValue {
    param(
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    try {
        if (Test-Path -LiteralPath $PathValue -ErrorAction SilentlyContinue) {
            try {
                return (Resolve-Path -LiteralPath $PathValue).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            } catch {
                Write-Verbose ("Resolve-PathValue: resolve path failed. {0}" -f $_.Exception.Message)
            }
        }
    } catch {
        Write-Verbose ("Resolve-PathValue: access denied or IO failure. {0}" -f $_.Exception.Message)
    }

    try {
        return [System.IO.Path]::GetFullPath($PathValue).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    } catch {
        return $PathValue.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    }
}

function Get-RepoIconApiZipPath {
    param(
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return $null
    }

    $candidate = Join-Path $RepoRoot 'Tooling\assets\LabVIEW Icon API.zip'
    if (Test-Path -Path $candidate) {
        return $candidate
    }

    return $null
}

function Resolve-IconApiFolderLayout {
    param(
        [string]$IconApiDir
    )

    if (-not (Test-Path -Path $IconApiDir)) {
        return $false
    }

    $changed = $false
    $current = $IconApiDir
    while (Test-Path -Path $current) {
        $entries = @(Get-ChildItem -LiteralPath $current -Force)
        if ($entries.Count -eq 1 -and $entries[0].PSIsContainer -and $entries[0].Name -eq 'LabVIEW Icon API') {
            $inner = $entries[0].FullName
            $parent = Split-Path -Parent $current
            $temp = Join-Path $parent ("LabVIEW Icon API.__tmp_{0}" -f ([guid]::NewGuid().ToString('N')))
            Move-Item -LiteralPath $inner -Destination $temp -Force
            Remove-Item -LiteralPath $current -Recurse -Force
            Move-Item -LiteralPath $temp -Destination $current -Force
            $changed = $true
            continue
        }
        break
    }

    return $changed
}

function Resolve-IconApiExtractRoot {
    param(
        [string]$ExtractRoot
    )

    $current = $ExtractRoot
    while (Test-Path -Path $current) {
        $entries = @(Get-ChildItem -LiteralPath $current -Force)
        if ($entries.Count -eq 1 -and $entries[0].PSIsContainer -and $entries[0].Name -eq 'LabVIEW Icon API') {
            $current = $entries[0].FullName
            continue
        }
        break
    }

    return $current
}

function Restore-IconApiFolderFromZip {
    param(
        [string]$ZipPath,
        [string]$DestinationDir
    )

    if (-not (Test-Path -Path $ZipPath)) {
        throw "Icon API zip not found at $ZipPath"
    }

    $tempRoot = Join-Path $env:TEMP ("lvie-icon-api-extract-{0}" -f ([guid]::NewGuid().ToString('N')))
    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
    try {
        Expand-Archive -Path $ZipPath -DestinationPath $tempRoot -Force
        $resolvedRoot = Resolve-IconApiExtractRoot -ExtractRoot $tempRoot
        $destParent = Split-Path -Parent $DestinationDir
        if (-not (Test-Path -Path $destParent)) {
            New-Item -Path $destParent -ItemType Directory -Force | Out-Null
        }
        if (Test-Path -Path $DestinationDir) {
            Remove-Item -LiteralPath $DestinationDir -Recurse -Force
        }
        if ((Split-Path -Leaf $resolvedRoot) -eq 'LabVIEW Icon API') {
            Move-Item -LiteralPath $resolvedRoot -Destination $destParent -Force
        } else {
            New-Item -Path $DestinationDir -ItemType Directory -Force | Out-Null
            $items = @(Get-ChildItem -LiteralPath $resolvedRoot -Force)
            if ($items.Count -eq 0) {
                throw "Icon API zip extraction produced no entries at $resolvedRoot"
            }
            Copy-Item -LiteralPath $items.FullName -Destination $DestinationDir -Recurse -Force
        }
    } finally {
        if (Test-Path -Path $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Get-IniLibraryPathList {
    param(
        [string]$IniPath
    )

    if (-not (Test-Path -Path $IniPath)) {
        return @()
    }

    $line = Get-Content -Path $IniPath | Where-Object { $_ -match '(?i)^\s*localhost\.librarypaths\s*=' } | Select-Object -First 1
    if (-not $line) {
        return @()
    }

    $value = $line -replace '(?i)^\s*localhost\.librarypaths\s*=\s*', ''
    if ([string]::IsNullOrWhiteSpace($value)) {
        return @()
    }

    return ($value -split ';' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Format-IniPath {
    param(
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    if ($PathValue -match '\s') {
        return '"' + $PathValue + '"'
    }

    return $PathValue
}

function Remove-IniLibraryPath {
    param(
        [string]$IniPath,
        [string]$RepoRoot
    )

    if (-not (Test-Path -Path $IniPath)) {
        return
    }

    $lines = @((Get-Content -Path $IniPath))
    $lineIndex = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '(?i)^\s*localhost\.librarypaths\s*=') {
            $lineIndex = $i
            break
        }
    }

    if ($null -eq $lineIndex) {
        return
    }

    $raw = $lines[$lineIndex] -replace '(?i)^\s*localhost\.librarypaths\s*=\s*', ''
    $paths = @()
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $paths = @($raw -split ';' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $repoRootNormalized = Resolve-PathValue -PathValue $RepoRoot
    if (-not $repoRootNormalized) {
        return
    }

    $remaining = @()
    foreach ($pathValue in $paths) {
        $normalized = Resolve-PathValue -PathValue $pathValue
        if (-not $normalized) { continue }
        if ($normalized.ToLowerInvariant() -ne $repoRootNormalized.ToLowerInvariant()) {
            $remaining += $pathValue
        }
    }

    if ($remaining.Count -gt 0) {
        $formatted = $remaining | ForEach-Object { Format-IniPath -PathValue $_ } | Where-Object { $_ }
        $lines[$lineIndex] = "Localhost.LibraryPaths={0}" -f ($formatted -join ';')
    } else {
        if ($lineIndex -eq 0) {
            $lines = $lines | Select-Object -Skip 1
        } elseif ($lineIndex -eq ($lines.Count - 1)) {
            $lines = $lines | Select-Object -First ($lines.Count - 1)
        } else {
            $lines = $lines[0..($lineIndex - 1)] + $lines[($lineIndex + 1)..($lines.Count - 1)]
        }
    }

    Set-Content -Path $IniPath -Value $lines -Encoding ascii
}

function Test-LibraryPathContainsRepoRoot {
    param(
        [string]$IniPath,
        [string]$RepoRoot
    )

    $repoRootNormalized = Resolve-PathValue -PathValue $RepoRoot
    if (-not $repoRootNormalized) {
        return $false
    }
    $repoKey = $repoRootNormalized.ToLowerInvariant()

    foreach ($pathValue in (Get-IniLibraryPathList -IniPath $IniPath)) {
        $candidate = Resolve-PathValue -PathValue $pathValue
        if ($candidate -and $candidate.ToLowerInvariant() -eq $repoKey) {
            return $true
        }
    }

    return $false
}

function Test-IEDevModeDisabled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabVIEWInstallRoot
    )

    $installPaths = @{
        IconApiFolder = Join-Path $LabVIEWInstallRoot 'vi.lib\LabVIEW Icon API'
        IconApiZip    = Join-Path $LabVIEWInstallRoot 'vi.lib\LabVIEW Icon API.zip'
        Lvlibp        = Join-Path $LabVIEWInstallRoot 'resource\plugins\lv_icon.lvlibp'
        Ship          = Join-Path $LabVIEWInstallRoot 'resource\plugins\lv_icon.ship'
    }

    $hasLvlibp = Test-Path -Path $installPaths.Lvlibp
    $hasShip = Test-Path -Path $installPaths.Ship
    $hasIconFolder = Test-Path -Path $installPaths.IconApiFolder
    $hasIconZip = Test-Path -Path $installPaths.IconApiZip

    return ($hasLvlibp -and (-not $hasShip) -and $hasIconFolder -and (-not $hasIconZip))
}

function Disable-DevModeNoLabVIEW {
    param(
        [string]$Bitness,
        [string]$RepoRoot,
        [string]$LabVIEWYear
    )

    $entry = [ordered]@{
        key          = ("{0}-{1}" -f $LabVIEWYear, $Bitness)
        labviewYear  = $LabVIEWYear
        bitness      = $Bitness
        desiredState = 'disabled'
        actualState  = 'unknown'
        status       = 'unknown'
        repoRoot     = $RepoRoot
        startUtc     = (Get-Date).ToUniversalTime().ToString('o')
        endUtc       = $null
        changes      = @()
        notes        = @()
        error        = $null
    }

    $installRoot = Get-LabVIEWInstallRoot -Version $LabVIEWYear -Bitness $Bitness
    if (-not $installRoot) {
        $entry.status = 'failed'
        $entry.error = "LabVIEW $LabVIEWYear ($Bitness-bit) install not found."
        $entry.endUtc = (Get-Date).ToUniversalTime().ToString('o')
        return $entry
    }

    $iconApiDir = Join-Path $installRoot 'vi.lib\LabVIEW Icon API'
    $iconApiZip = Join-Path $installRoot 'vi.lib\LabVIEW Icon API.zip'
    $lvlibpPath = Join-Path $installRoot 'resource\plugins\lv_icon.lvlibp'
    $shipPath = Join-Path $installRoot 'resource\plugins\lv_icon.ship'
    $iniPath = Join-Path $installRoot 'LabVIEW.ini'
    $entry.installRoot = $installRoot
    $entry.iniPath = $iniPath
    $repoIconApiZip = Get-RepoIconApiZipPath -RepoRoot $RepoRoot

    Write-Host ("Revert dev mode (no LabVIEW): LV{0} {1}-bit" -f $LabVIEWYear, $Bitness)
    Write-Host ("Install root: {0}" -f $installRoot)

    try {
        $preDisabled = Test-IEDevModeDisabled -LabVIEWInstallRoot $installRoot
        $preHasRepo = Test-LibraryPathContainsRepoRoot -IniPath $iniPath -RepoRoot $RepoRoot
        if ($preDisabled -and -not $preHasRepo) {
            $entry.actualState = 'disabled'
            $entry.status = 'skipped'
            $entry.notes += 'Dev mode already disabled.'
            return $entry
        }

        $zipSource = $null
        $removeZipAfter = $false
        if (Test-Path -Path $iconApiZip) {
            $zipSource = $iconApiZip
            $removeZipAfter = $true
        } elseif (-not (Test-Path -Path $iconApiDir) -and $repoIconApiZip) {
            Write-Warning ("Icon API folder and zip missing; restoring from repo copy at {0}." -f $repoIconApiZip)
            $zipSource = $repoIconApiZip
        }

        if ($zipSource) {
            Restore-IconApiFolderFromZip -ZipPath $zipSource -DestinationDir $iconApiDir
            if ($removeZipAfter -and (Test-Path -Path $iconApiZip)) {
                Remove-Item -Path $iconApiZip -Force -ErrorAction SilentlyContinue
            }
            $entry.changes += [ordered]@{ operation = 'unzip-icon-api'; status = 'changed'; source = $zipSource; destination = $iconApiDir }
        } elseif (-not (Test-Path -Path $iconApiDir)) {
            Write-Warning ("Icon API folder and zip not found under {0}." -f (Join-Path $installRoot 'vi.lib'))
            $entry.changes += [ordered]@{ operation = 'unzip-icon-api'; status = 'missing'; path = $iconApiDir }
        } else {
            $entry.changes += [ordered]@{ operation = 'unzip-icon-api'; status = 'skipped'; path = $iconApiDir }
        }

        if (Test-Path -Path $iconApiDir) {
            if (Resolve-IconApiFolderLayout -IconApiDir $iconApiDir) {
                $entry.changes += [ordered]@{ operation = 'flatten-icon-api-folder'; status = 'changed'; path = $iconApiDir }
            }
        }

        if (Test-Path -Path $shipPath) {
            Write-Host "Renaming lv_icon.ship to lv_icon.lvlibp."
            if (Test-Path -Path $lvlibpPath) {
                Remove-Item -Path $lvlibpPath -Force -ErrorAction SilentlyContinue
                $entry.changes += [ordered]@{ operation = 'remove-lv_icon.lvlibp'; status = 'changed'; path = $lvlibpPath }
            }
            Move-Item -Path $shipPath -Destination $lvlibpPath -Force
            $entry.changes += [ordered]@{ operation = 'rename-lv_icon.ship'; status = 'changed'; source = $shipPath; destination = $lvlibpPath }
        } elseif (-not (Test-Path -Path $lvlibpPath)) {
            Write-Warning ("lv_icon.ship and lv_icon.lvlibp not found under {0}." -f (Split-Path $lvlibpPath -Parent))
            $entry.changes += [ordered]@{ operation = 'rename-lv_icon.ship'; status = 'missing'; path = $shipPath }
        } else {
            $entry.changes += [ordered]@{ operation = 'rename-lv_icon.ship'; status = 'skipped'; path = $lvlibpPath }
        }

        Write-Host ("Updating Localhost.LibraryPaths in {0}" -f $iniPath)
        Remove-IniLibraryPath -IniPath $iniPath -RepoRoot $RepoRoot
        $entry.changes += [ordered]@{ operation = 'remove-library-paths'; status = 'changed'; path = $iniPath }

        $issues = @()
        $postDisabled = Test-IEDevModeDisabled -LabVIEWInstallRoot $installRoot
        $postHasRepo = Test-LibraryPathContainsRepoRoot -IniPath $iniPath -RepoRoot $RepoRoot
        if (-not $postDisabled) {
            $issues += 'Install files did not reflect reverted state.'
        }
        if ($postHasRepo) {
            $issues += 'Localhost.LibraryPaths still includes repo root.'
        }

        $entry.actualState = if ($postDisabled -and -not $postHasRepo) { 'disabled' } else { 'partial' }
        if ($issues.Count -gt 0) {
            $entry.status = 'failed'
            $entry.error = ("Dev mode revert (no LabVIEW) failed: {0}" -f ($issues -join ' '))
        } else {
            $entry.status = 'success'
        }
    } catch {
        if (-not $entry.error) {
            $entry.error = $_.Exception.Message
        }
        $entry.status = 'failed'
    } finally {
        if (-not $entry.actualState -or $entry.actualState -eq 'unknown') {
            $entry.actualState = if (Test-IEDevModeDisabled -LabVIEWInstallRoot $installRoot) { 'disabled' } else { 'enabled' }
        }
        $entry.endUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    return $entry
}

function Invoke-RevertDevModeNoLabVIEWMain {
    param(
        [string]$LabVIEWVersion,
        [string[]]$SupportedBitness,
        [string]$RepoRoot,
        [string]$ContractPath,
        [switch]$SkipProcessCheck,
        [switch]$SkipRepoVersionCheck
    )

    $resolvedRepoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
    $versionHelper = Join-Path $resolvedRepoRoot 'Tooling\support\LabVIEWVersion.ps1'
    $contractHelper = Join-Path $resolvedRepoRoot 'Tooling\support\DevModeContract.ps1'
    $labviewYear = $LabVIEWVersion
    if (Test-Path -Path $versionHelper) {
        . $versionHelper
        $useBypass = $SkipRepoVersionCheck -and -not [string]::IsNullOrWhiteSpace($LabVIEWVersion)
        if ($useBypass) {
            $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion
        } else {
            $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot
        }
        $labviewYear = $versionInfo.Year
    }
    if (-not (Test-Path -Path $contractHelper)) {
        throw "Dev mode contract helper not found at $contractHelper"
    }
    . $contractHelper
    if ([string]::IsNullOrWhiteSpace($labviewYear)) {
        throw "LabVIEW version could not be resolved. Check .lvversion."
    }

    try {
        if (-not $SkipProcessCheck) {
            Assert-DevModeNoProcess
        }
        $contractPath = Resolve-DevModeContractPath -RepoRoot $resolvedRepoRoot -ContractPath $ContractPath
        $contract = Read-DevModeContract -ContractPath $contractPath -RepoRoot $resolvedRepoRoot
        $bitnesses = $SupportedBitness | Select-Object -Unique
        foreach ($bitness in $bitnesses) {
            $entry = Disable-DevModeNoLabVIEW -Bitness $bitness -RepoRoot $resolvedRepoRoot -LabVIEWYear $labviewYear
            $contract = Update-DevModeContractEntry -Contract $contract -Entry $entry
            Write-DevModeContract -Contract $contract -ContractPath $contractPath
            if ($entry.status -eq 'failed') {
                throw $entry.error
            }
        }
    }
    catch {
        Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
        exit 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-RevertDevModeNoLabVIEWMain `
        -LabVIEWVersion $LabVIEWVersion `
        -SupportedBitness $SupportedBitness `
        -RepoRoot $RepoRoot `
        -ContractPath $ContractPath `
        -SkipProcessCheck:$SkipProcessCheck `
        -SkipRepoVersionCheck:$SkipRepoVersionCheck
}




