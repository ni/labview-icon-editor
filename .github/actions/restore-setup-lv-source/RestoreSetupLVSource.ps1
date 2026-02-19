<#
.SYNOPSIS
    Restores the LabVIEW source setup from a packaged state.

.DESCRIPTION
    Executes RestoreSetupLVSource.vi via g-cli. The VI unzips the LabVIEW
    Icon API, restores lv_icon.ship to lv_icon.lvlibp, and removes the
    LabVIEW token. LabVIEW is closed after the VI executes so subsequent
    steps load the changes.

.PARAMETER LabVIEWVersion
    LabVIEW version year (e.g., 2021) or numeric version (e.g., 21.0).

.PARAMETER SupportedBitness
    Bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepoRoot
    Optional path to the repository root. If omitted, resolved relative to
    this script's location.

.PARAMETER ConnectTimeoutMs
    g-cli connect timeout in milliseconds (0 disables the timeout).

.PARAMETER ProcessTimeoutMs
    Maximum time to wait for g-cli to finish in milliseconds (0 disables the timeout).

.EXAMPLE
    .\RestoreSetupLVSource.ps1 -SupportedBitness "64"  # Uses .lvversion by default
#>

param(
    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $true)]
    [ValidateSet('32', '64', IgnoreCase = $true)]
    [string]$SupportedBitness,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600000)]
    [int]$ConnectTimeoutMs = 120000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1200000)]
    [int]$ProcessTimeoutMs = 300000
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param(
        [string]$PathOverride
    )

    if ($PathOverride) {
        if (-not (Test-Path -Path $PathOverride)) {
            throw "RepoRoot does not exist: $PathOverride"
        }
        return (Resolve-Path -Path $PathOverride).Path
    }

    return (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..\..')).Path
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

$connectTimeoutPattern = 'Timed out waiting for app to connect to g-cli'

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
$versionHelper = Join-Path -Path $repoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
$labviewYear = $LabVIEWVersion
if (Test-Path -Path $versionHelper) {
    . $versionHelper
    $versionInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $repoRoot
    $labviewYear = $versionInfo.Year
}
if ([string]::IsNullOrWhiteSpace($labviewYear)) {
    throw "LabVIEW version could not be resolved. Check .lvversion."
}
$gCliRunner = Join-Path -Path $repoRoot -ChildPath 'Tooling\support\GcliRunner.ps1'
if (-not (Test-Path -Path $gCliRunner)) {
    throw "g-cli helper not found at $gCliRunner"
}
. $gCliRunner
$missingPathsScript = Join-Path -Path $repoRoot -ChildPath 'Tooling\support\DevModeMissingPaths.ps1'
$missingPathsLoaded = $false
if (Test-Path -Path $missingPathsScript) {
    . $missingPathsScript
    $missingPathsLoaded = $true
} else {
    Write-Warning "Dev-mode missing paths helper not found at $missingPathsScript"
}
$viPath = Join-Path -Path $repoRoot -ChildPath 'Tooling\RestoreSetupLVSource.vi'

if (-not (Test-Path -Path $viPath)) {
    throw "RestoreSetupLVSource.vi not found at $viPath"
}

$installRoot = Get-LabVIEWInstallRoot -Version $labviewYear -Bitness $SupportedBitness
if (-not $installRoot) {
    throw "LabVIEW $labviewYear ($SupportedBitness-bit) install not found."
}

# Fast-path: avoid launching LabVIEW when the install already reflects the "reverted" state.
# This keeps local runs snappy and avoids long g-cli connect timeouts for no-op restores.
$installPaths = @{
    IconApiFolder = Join-Path $installRoot 'vi.lib\LabVIEW Icon API'
    IconApiZip    = Join-Path $installRoot 'vi.lib\LabVIEW Icon API.zip'
    Lvlibp        = Join-Path $installRoot 'resource\plugins\lv_icon.lvlibp'
    Ship          = Join-Path $installRoot 'resource\plugins\lv_icon.ship'
}

$hasLvlibp = Test-Path -Path $installPaths.Lvlibp
$hasShip = Test-Path -Path $installPaths.Ship
$hasIconFolder = Test-Path -Path $installPaths.IconApiFolder
$hasIconZip = Test-Path -Path $installPaths.IconApiZip
Write-Host ("Install state (LV{0} {1}-bit): lv_icon.lvlibp={2} lv_icon.ship={3} icon_api_folder={4} icon_api_zip={5}" -f `
        $labviewYear, $SupportedBitness, $hasLvlibp, $hasShip, $hasIconFolder, $hasIconZip)

if ($hasLvlibp -and -not $hasShip -and $hasIconFolder -and -not $hasIconZip) {
    Write-Host "RestoreSetupLVSource: already reverted; skipping g-cli call."
    $global:LASTEXITCODE = 0
    return
}

if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
    throw "g-cli.exe not found in PATH."
}

$gCliPath = (Get-Command g-cli -ErrorAction SilentlyContinue).Source

$gCliArgs = @(
    '--lv-ver', $labviewYear,
    '--arch', $SupportedBitness,
    '-v', $viPath
)

if ($ConnectTimeoutMs -gt 0) {
    $gCliArgs = @('--connect-timeout', $ConnectTimeoutMs) + $gCliArgs
}

Write-Host ("Executing: g-cli {0}" -f ($gCliArgs -join ' '))
$closeScript = Join-Path -Path $PSScriptRoot -ChildPath '..\close-labview\Close_LabVIEW.ps1'
$failure = $null
$closeFailure = $null
try {
    $result = Invoke-GCliCommand -ExecutablePath $gCliPath -Arguments $gCliArgs -TimeoutMs $ProcessTimeoutMs
    $exitCode = $result.ExitCode
    if ($result.TimedOut) {
        throw "RestoreSetupLVSource.vi timed out after $ProcessTimeoutMs ms."
    }

    $allOutput = @($result.OutputLines + $result.ErrorLines)
    $combinedOutput = $allOutput -join "`n"
    $ignoreExitCode = $false
    if ($combinedOutput -match $connectTimeoutPattern) {
        throw "GCLI_CONNECT_TIMEOUT: $connectTimeoutPattern"
    }

    if ($combinedOutput -match '-593451') {
        $missingPaths = @()
        if (Get-Command Get-DevModeMissingPathsFromOutput -ErrorAction SilentlyContinue) {
            $missingPaths = Get-DevModeMissingPathsFromOutput -Output $allOutput
        } elseif (-not $missingPathsLoaded) {
            Write-Warning "Dev-mode missing paths helper was not loaded."
        }

        $missingCount = @($missingPaths).Count
        if ($missingCount -eq 0) {
            Write-Warning "RestoreSetupLVSource.vi returned -593451 but no missing paths were reported. Development mode already appears reverted; treating as warning."
            $ignoreExitCode = $true
        } else {
            $missingJoined = $missingPaths -join ', '
            throw "RestoreSetupLVSource.vi reported error -593451 (development mode could not be reverted). Missing paths: $missingJoined"
        }
    }

    if (-not $ignoreExitCode -and $exitCode -ne 0) {
        throw "RestoreSetupLVSource.vi failed with exit code $exitCode."
    }
} catch {
    $failure = $_
} finally {
    if (-not (Test-Path -Path $closeScript)) {
        $closeFailure = "Close_LabVIEW.ps1 not found at $closeScript"
    } else {
        try {
            Write-Host "Closing LabVIEW $labviewYear ($SupportedBitness-bit)..."
            & $closeScript -LabVIEWVersion $labviewYear -SupportedBitness $SupportedBitness
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                $closeFailure = "Close_LabVIEW.ps1 failed with exit code $LASTEXITCODE."
            }
        } catch {
            $closeFailure = $_.Exception.Message
        }
    }
}

if ($failure) {
    if ($closeFailure) {
        Write-Warning $closeFailure
    }
    throw $failure
}

if ($closeFailure) {
    throw $closeFailure
}

