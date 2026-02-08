#Requires -Version 7.0
<#
.SYNOPSIS
    Enables LabVIEW Icon Editor development mode without launching LabVIEW.

.DESCRIPTION
    Performs file-system and INI edits to mirror the dev-mode state:
    - zips vi.lib\LabVIEW Icon API to LabVIEW Icon API.zip
    - renames resource\plugins\lv_icon.lvlibp to lv_icon.ship
    - adds RepoRoot to Localhost.LibraryPaths in LabVIEW.ini
    This is intended for local testing; revert should use the LabVIEW-based workflow.

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

function Set-IniLibraryPath {
    param(
        [string]$IniPath,
        [string]$RepoRoot
    )

    $lines = @()
    if (Test-Path -Path $IniPath) {
        $lines = Get-Content -Path $IniPath
    }

    $lineIndex = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '(?i)^\s*localhost\.librarypaths\s*=') {
            $lineIndex = $i
            break
        }
    }

    $paths = @()
    if ($null -ne $lineIndex) {
        $raw = $lines[$lineIndex] -replace '(?i)^\s*localhost\.librarypaths\s*=\s*', ''
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $paths = @($raw -split ';' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
    }

    $repoRootNormalized = Resolve-PathValue -PathValue $RepoRoot
    $existingNormalized = @{}
    foreach ($pathValue in $paths) {
        $normalized = Resolve-PathValue -PathValue $pathValue
        if ($normalized) {
            $existingNormalized[$normalized.ToLowerInvariant()] = $pathValue
        }
    }

    if ($repoRootNormalized) {
        $key = $repoRootNormalized.ToLowerInvariant()
        if (-not $existingNormalized.ContainsKey($key)) {
            $paths += $repoRootNormalized
        }
    }

    $formatted = $paths | ForEach-Object { Format-IniPath -PathValue $_ } | Where-Object { $_ }
    $newLine = if ($formatted.Count -gt 0) {
        "Localhost.LibraryPaths={0}" -f ($formatted -join ';')
    } else {
        "Localhost.LibraryPaths=$RepoRoot"
    }

    if ($null -ne $lineIndex) {
        $lines[$lineIndex] = $newLine
    } else {
        $lines += $newLine
    }

    $targetDir = Split-Path -Path $IniPath -Parent
    if (-not (Test-Path -Path $targetDir)) {
        throw "LabVIEW install root not found for INI path: $IniPath"
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

function Test-IEDevModeEnabled {
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

    return ($hasShip -and (-not $hasLvlibp) -and (-not $hasIconFolder) -and $hasIconZip)
}

function Enable-DevModeNoLabVIEW {
    param(
        [string]$Bitness,
        [string]$RepoRoot,
        [string]$LabVIEWYear
    )

    $entry = [ordered]@{
        key          = ("{0}-{1}" -f $LabVIEWYear, $Bitness)
        labviewYear  = $LabVIEWYear
        bitness      = $Bitness
        desiredState = 'enabled'
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

    Write-Host ("Enable dev mode (no LabVIEW): LV{0} {1}-bit" -f $LabVIEWYear, $Bitness)
    Write-Host ("Install root: {0}" -f $installRoot)

    try {
        $preEnabled = Test-IEDevModeEnabled -LabVIEWInstallRoot $installRoot
        $preHasRepo = Test-LibraryPathContainsRepoRoot -IniPath $iniPath -RepoRoot $RepoRoot
        if ($preEnabled -and $preHasRepo) {
            $entry.actualState = 'enabled'
            $entry.status = 'skipped'
            $entry.notes += 'Dev mode already enabled.'
            return $entry
        }

        if (-not (Test-Path -Path $iconApiDir) -and -not (Test-Path -Path $iconApiZip) -and $repoIconApiZip) {
            Write-Warning ("Icon API folder and zip missing; restoring zip from repo copy at {0}." -f $repoIconApiZip)
            Copy-Item -LiteralPath $repoIconApiZip -Destination $iconApiZip -Force
            $entry.changes += [ordered]@{ operation = 'restore-icon-api-zip'; status = 'changed'; source = $repoIconApiZip; destination = $iconApiZip }
        }

        if (Test-Path -Path $iconApiDir) {
            if (Resolve-IconApiFolderLayout -IconApiDir $iconApiDir) {
                $entry.changes += [ordered]@{ operation = 'flatten-icon-api-folder'; status = 'changed'; path = $iconApiDir }
            }
            Write-Host "Zipping LabVIEW Icon API folder."
            if (Test-Path -Path $iconApiZip) {
                Remove-Item -Path $iconApiZip -Force -ErrorAction SilentlyContinue
                $entry.changes += [ordered]@{ operation = 'remove-icon-api-zip'; status = 'changed'; path = $iconApiZip }
            }
            Compress-Archive -Path $iconApiDir -DestinationPath $iconApiZip -Force
            Remove-Item -Path $iconApiDir -Recurse -Force
            $entry.changes += [ordered]@{ operation = 'zip-icon-api'; status = 'changed'; source = $iconApiDir; destination = $iconApiZip }
        } elseif (-not (Test-Path -Path $iconApiZip)) {
            Write-Warning ("Icon API folder and zip not found under {0}." -f (Join-Path $installRoot 'vi.lib'))
            $entry.changes += [ordered]@{ operation = 'zip-icon-api'; status = 'missing'; path = $iconApiDir }
        } else {
            $entry.changes += [ordered]@{ operation = 'zip-icon-api'; status = 'skipped'; path = $iconApiZip }
        }

        if (Test-Path -Path $lvlibpPath) {
            Write-Host "Renaming lv_icon.lvlibp to lv_icon.ship."
            if (Test-Path -Path $shipPath) {
                Remove-Item -Path $shipPath -Force -ErrorAction SilentlyContinue
                $entry.changes += [ordered]@{ operation = 'remove-lv_icon.ship'; status = 'changed'; path = $shipPath }
            }
            Move-Item -Path $lvlibpPath -Destination $shipPath -Force
            $entry.changes += [ordered]@{ operation = 'rename-lvlibp'; status = 'changed'; source = $lvlibpPath; destination = $shipPath }
        } elseif (-not (Test-Path -Path $shipPath)) {
            Write-Warning ("lv_icon.lvlibp and lv_icon.ship not found under {0}." -f (Split-Path $lvlibpPath -Parent))
            $entry.changes += [ordered]@{ operation = 'rename-lvlibp'; status = 'missing'; path = $lvlibpPath }
        } else {
            $entry.changes += [ordered]@{ operation = 'rename-lvlibp'; status = 'skipped'; path = $shipPath }
        }

        Write-Host ("Updating Localhost.LibraryPaths in {0}" -f $iniPath)
        Set-IniLibraryPath -IniPath $iniPath -RepoRoot $RepoRoot
        $entry.changes += [ordered]@{ operation = 'set-library-paths'; status = 'changed'; path = $iniPath }

        $issues = @()
        $postEnabled = Test-IEDevModeEnabled -LabVIEWInstallRoot $installRoot
        $postHasRepo = Test-LibraryPathContainsRepoRoot -IniPath $iniPath -RepoRoot $RepoRoot
        if (-not $postEnabled) {
            $issues += 'Install files did not reflect dev-mode state.'
        }
        if (-not $postHasRepo) {
            $issues += 'Localhost.LibraryPaths does not include repo root.'
        }

        $entry.actualState = if ($postEnabled -and $postHasRepo) { 'enabled' } else { 'partial' }
        if ($issues.Count -gt 0) {
            $entry.status = 'failed'
            $entry.error = ("Dev mode enable (no LabVIEW) failed: {0}" -f ($issues -join ' '))
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
            $entry.actualState = if (Test-IEDevModeEnabled -LabVIEWInstallRoot $installRoot) { 'enabled' } else { 'disabled' }
        }
        $entry.endUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    return $entry
}

function Invoke-DevModeNoLabVIEWMain {
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
            $entry = Enable-DevModeNoLabVIEW -Bitness $bitness -RepoRoot $resolvedRepoRoot -LabVIEWYear $labviewYear
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
    Invoke-DevModeNoLabVIEWMain `
        -LabVIEWVersion $LabVIEWVersion `
        -SupportedBitness $SupportedBitness `
        -RepoRoot $RepoRoot `
        -ContractPath $ContractPath `
        -SkipProcessCheck:$SkipProcessCheck `
        -SkipRepoVersionCheck:$SkipRepoVersionCheck
}




