<#
.SYNOPSIS
    Prepares LabVIEW source code for development mode.

.DESCRIPTION
    Executes PrepareIESource.vi via g-cli. The VI handles packaging the
    LabVIEW Icon API, renaming lv_icon.lvlibp to lv_icon.ship, and setting
    the LabVIEW token to the repository root. LabVIEW is closed after the
    VI executes so subsequent steps load the changes.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW 2021 (21.0) only.

.PARAMETER SupportedBitness
    Target bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepoRoot
    Optional path to the repository root. If omitted, resolved relative to
    this script's location.

.PARAMETER ConnectTimeoutMs
    g-cli connect timeout in milliseconds (0 disables the timeout).

.PARAMETER ProcessTimeoutMs
    Maximum time to wait for g-cli to finish in milliseconds (0 disables the timeout).

.EXAMPLE
    .\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64"
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('2021')]
    [string]$MinimumSupportedLVVersion,

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

$repoRoot = Resolve-RepoRoot -PathOverride $RepoRoot
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
$viPath = Join-Path -Path $repoRoot -ChildPath 'Tooling\PrepareIESource.vi'

if (-not (Test-Path -Path $viPath)) {
    throw "PrepareIESource.vi not found at $viPath"
}

if (-not (Get-LabVIEWInstallRoot -Version $MinimumSupportedLVVersion -Bitness $SupportedBitness)) {
    throw "LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit) install not found."
}

if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
    throw "g-cli.exe not found in PATH."
}

$gCliPath = (Get-Command g-cli -ErrorAction SilentlyContinue).Source

$gCliArgs = @(
    '--lv-ver', $MinimumSupportedLVVersion,
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
        throw "PrepareIESource.vi timed out after $ProcessTimeoutMs ms."
    }

    $allOutput = @($result.OutputLines + $result.ErrorLines)
    $combinedOutput = $allOutput -join "`n"
    if ($combinedOutput -match '-593450') {
        $missingPaths = @()
        if (Get-Command Get-DevModeMissingPathsFromOutput -ErrorAction SilentlyContinue) {
            $missingPaths = Get-DevModeMissingPathsFromOutput -Output $allOutput
        } elseif (-not $missingPathsLoaded) {
            Write-Warning "Dev-mode missing paths helper was not loaded."
        }

        if ($missingPaths -and $missingPaths.Count -gt 0) {
            $missingJoined = $missingPaths -join ', '
            throw "PrepareIESource.vi reported error -593450 (development mode could not be set). Missing paths: $missingJoined"
        }

        throw "PrepareIESource.vi reported error -593450 (development mode could not be set). No missing paths were reported."
    }

    if ($exitCode -ne 0) {
        throw "PrepareIESource.vi failed with exit code $exitCode."
    }
} catch {
    $failure = $_
} finally {
    if (-not (Test-Path -Path $closeScript)) {
        $closeFailure = "Close_LabVIEW.ps1 not found at $closeScript"
    } else {
        try {
            Write-Host "Closing LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit)..."
            & $closeScript -MinimumSupportedLVVersion $MinimumSupportedLVVersion -SupportedBitness $SupportedBitness
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
