<#
.SYNOPSIS
    Gracefully closes a running LabVIEW instance.

.DESCRIPTION
    Utilizes g-cli's QuitLabVIEW command to shut down the specified LabVIEW
    version and bitness, ensuring the application exits cleanly.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version to close (e.g., "2021").

.PARAMETER SupportedBitness
    Bitness of the LabVIEW instance ("32" or "64").

.EXAMPLE
    .\Close_LabVIEW.ps1 -Package_LabVIEW_Version "2021" -SupportedBitness "64"
#>
param(
    [Parameter(Mandatory)]
    [Alias('MinimumSupportedLVVersion')]
    [string]$Package_LabVIEW_Version,
    [Parameter(Mandatory)]
    [ValidateSet("32","64")]
    [string]$SupportedBitness
)

$ErrorActionPreference = 'Stop'

function Invoke-SafeQuitLabVIEW {
    param(
        [string]$Version,
        [string]$Bitness
    )

    if (-not (Get-Command g-cli -ErrorAction SilentlyContinue)) {
        throw "g-cli.exe not found in PATH."
    }

    $gcliArgs = @(
        "--lv-ver", $Version,
        "--arch",   $Bitness,
        "QuitLabVIEW"
    )

    Write-Information ("Executing: g-cli {0}" -f ($gcliArgs -join ' ')) -InformationAction Continue
    $output   = & g-cli @gcliArgs 2>&1
    $exitCode = $LASTEXITCODE

    # echo all output for log visibility
    $output | ForEach-Object { Write-Information $_ -InformationAction Continue }

    if ($exitCode -eq 0) { return }

    $joined = ($output -join ' ')
    if ($joined -match 'not (currently )?running' -or $joined -match 'does not appear to be running') {
        Write-Information "LabVIEW $Version ($Bitness-bit) was not running; nothing to close." -InformationAction Continue
        return
    }

    throw "g-cli QuitLabVIEW failed with exit code $exitCode."
}

try {
    Invoke-SafeQuitLabVIEW -Version $Package_LabVIEW_Version -Bitness $SupportedBitness
    Write-Information "LabVIEW $Package_LabVIEW_Version ($SupportedBitness-bit) closed or not running." -InformationAction Continue
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
